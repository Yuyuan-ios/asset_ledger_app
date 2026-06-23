import hashlib
import hmac
import io
import json
import logging
import os
import tempfile
import time
import unittest
from unittest import mock

from app import (
    AppConfig,
    Authenticator,
    HttpError,
    MAX_BATCH_CHANGES,
    SlidingWindowRateLimiter,
    SyncApp,
    SyncStore,
    base64url_encode,
    configure_logging,
    main,
)


def payload_body(mark):
    return json.dumps({"record": {"id": mark, "value": mark}}, separators=(",", ":"))


def payload_hash(body):
    return hashlib.sha256(body.encode("utf-8")).hexdigest()


def make_change(entity_id="timer-1", op="create", base_version=0, mark="a", payload=None):
    body = payload if payload is not None else payload_body(mark)
    return {
        "entity_type": "timing_record",
        "entity_id": entity_id,
        "op": op,
        "base_version": base_version,
        "payload_json": body,
        "payload_hash": payload_hash(body),
    }


class SyncBackendTestCase(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.store = SyncStore(f"{self.temp_dir.name}/sync.sqlite3")
        self.app = SyncApp(
            store=self.store,
            authenticator=Authenticator(dev_tokens={"token-a": "account-a", "token-b": "account-b"}),
            max_request_bytes=64 * 1024,
            default_pull_limit=2,
            max_pull_limit=3,
        )

    def tearDown(self):
        self.temp_dir.cleanup()

    def request(self, method, path, token=None, body=None, authorization=None, headers=None):
        data = b""
        headers = dict(headers or {})
        if body is not None:
            data = json.dumps(body, separators=(",", ":")).encode("utf-8")
            headers["content-type"] = "application/json"
            headers["content-length"] = str(len(data))
        if authorization is not None:
            headers["authorization"] = authorization
        elif token is not None:
            headers["authorization"] = f"Bearer {token}"
        handler = _HandlerHarness(self.app, path, headers, data)
        from app import SyncRequestHandler

        SyncRequestHandler._handle(handler, method)
        raw = handler.wfile.getvalue().decode("utf-8")
        return handler.status, json.loads(raw) if raw else {}

    def test_healthz_is_unauthenticated(self):
        status, body = self.request("GET", "/healthz")

        self.assertEqual(status, 200)
        self.assertEqual(body, {"ok": True})

    def test_healthz_bypasses_version_gate(self):
        with mock.patch("app.VERSION_UPGRADE_GATE.enforce", side_effect=AssertionError("gate should not run")):
            status, body = self.request("GET", "/healthz")

        self.assertEqual(status, 200)
        self.assertEqual(body, {"ok": True})

    def test_version_gate_returns_426_for_outdated_client_before_auth(self):
        policy_path = self.write_version_policy(min_version="2.0.0")

        with _patched_env(FLEET_SYNC_VERSION_POLICY_PATH=policy_path):
            status, body = self.request(
                "GET",
                "/sync/changes?since=0",
                headers={
                    "X-App-Version": "1.4.0+12",
                    "X-Platform": "android",
                },
            )

        self.assertEqual(status, 426)
        self.assertEqual(
            body,
            {
                "code": "upgrade_required",
                "updateUrl": "https://example.com/download",
                "title": "发现新版本",
                "content": "请更新后继续使用。",
            },
        )

    def test_version_gate_allows_current_or_newer_client_to_reach_auth(self):
        policy_path = self.write_version_policy(min_version="1.4.0")

        with _patched_env(FLEET_SYNC_VERSION_POLICY_PATH=policy_path):
            status, body = self.request(
                "GET",
                "/sync/changes?since=0",
                headers={
                    "X-App-Version": "1.4.0-alpha+12",
                    "X-Platform": "android",
                },
            )

        self.assertEqual(status, 401)
        self.assertEqual(body["error"]["code"], "unauthorized")

    def test_version_gate_fail_opens_when_required_headers_are_missing(self):
        policy_path = self.write_version_policy(min_version="2.0.0")

        with _patched_env(FLEET_SYNC_VERSION_POLICY_PATH=policy_path):
            missing_version_status, missing_version_body = self.request(
                "GET",
                "/sync/changes?since=0",
                headers={"X-Platform": "android"},
            )
            missing_platform_status, missing_platform_body = self.request(
                "GET",
                "/sync/changes?since=0",
                headers={"X-App-Version": "1.0.0"},
            )

        self.assertEqual(missing_version_status, 401)
        self.assertEqual(missing_version_body["error"]["code"], "unauthorized")
        self.assertEqual(missing_platform_status, 401)
        self.assertEqual(missing_platform_body["error"]["code"], "unauthorized")

    def test_version_gate_fail_opens_when_policy_is_unconfigured_or_missing(self):
        request_headers = {"X-App-Version": "1.0.0", "X-Platform": "android"}

        with mock.patch.dict(os.environ, {}, clear=True):
            status, body = self.request("GET", "/sync/changes?since=0", headers=request_headers)
        self.assertEqual(status, 401)
        self.assertEqual(body["error"]["code"], "unauthorized")

        with _patched_env(FLEET_SYNC_VERSION_POLICY_PATH=f"{self.temp_dir.name}/missing.json"):
            status, body = self.request("GET", "/sync/changes?since=0", headers=request_headers)

        self.assertEqual(status, 401)
        self.assertEqual(body["error"]["code"], "unauthorized")

    def test_version_gate_fail_opens_on_invalid_semver(self):
        valid_policy_path = self.write_version_policy(min_version="2.0.0")
        invalid_policy_path = self.write_version_policy(min_version="not-semver", filename="invalid-policy.json")

        with _patched_env(FLEET_SYNC_VERSION_POLICY_PATH=valid_policy_path):
            invalid_current_status, invalid_current_body = self.request(
                "GET",
                "/sync/changes?since=0",
                headers={
                    "X-App-Version": "1.0",
                    "X-Platform": "android",
                },
            )
        with _patched_env(FLEET_SYNC_VERSION_POLICY_PATH=invalid_policy_path):
            invalid_min_status, invalid_min_body = self.request(
                "GET",
                "/sync/changes?since=0",
                headers={
                    "X-App-Version": "1.0.0",
                    "X-Platform": "android",
                },
            )

        self.assertEqual(invalid_current_status, 401)
        self.assertEqual(invalid_current_body["error"]["code"], "unauthorized")
        self.assertEqual(invalid_min_status, 401)
        self.assertEqual(invalid_min_body["error"]["code"], "unauthorized")

    def write_version_policy(self, min_version="2.0.0", filename="version-policy.json"):
        path = f"{self.temp_dir.name}/{filename}"
        with open(path, "w", encoding="utf-8") as policy_file:
            json.dump(
                {
                    "android": {
                        "latestVersion": "2.1.0",
                        "minSupportedVersion": min_version,
                        "updateUrl": "https://example.com/download",
                        "title": "发现新版本",
                        "content": "请更新后继续使用。",
                    },
                    "ios": {
                        "latestVersion": "2.1.0",
                        "minSupportedVersion": "1.0.0",
                        "updateUrl": "itms-apps://apps.apple.com/app/idXXXXXXXX",
                        "title": "发现新版本",
                        "content": "请更新后继续使用。",
                    },
                },
                policy_file,
                separators=(",", ":"),
            )
        return path

    def test_configure_logging_emits_info_messages_to_journald(self):
        with mock.patch("logging.basicConfig") as basic_config:
            configure_logging()

        basic_config.assert_called_once_with(level=logging.INFO, format="%(message)s")

    def test_main_configures_logging_before_serving(self):
        calls = []

        class FakeServer:
            server_address = ("127.0.0.1", 8009)

            def serve_forever(self):
                calls.append("serve")

        with (
            mock.patch("app.configure_logging", side_effect=lambda: calls.append("logging")),
            mock.patch("app.build_server_from_env", side_effect=lambda: calls.append("build") or FakeServer()),
            mock.patch("sys.stdout", new=io.StringIO()),
        ):
            main()

        self.assertEqual(calls, ["logging", "build", "serve"])

    def test_rejects_missing_and_wrong_auth(self):
        status, body = self.request("GET", "/sync/changes?since=0")
        self.assertEqual(status, 401)
        self.assertEqual(body["error"]["code"], "unauthorized")

        status, body = self.request("GET", "/sync/changes?since=0", authorization="Basic token-a")
        self.assertEqual(status, 401)
        self.assertEqual(body["error"]["code"], "unauthorized")

        status, body = self.request("GET", "/sync/changes?since=0", token="unknown-token")
        self.assertEqual(status, 401)
        self.assertEqual(body["error"]["code"], "unauthorized")

    def test_rate_limiter_returns_429_after_authenticated_user_exceeds_limit(self):
        self.app = SyncApp(
            store=self.store,
            authenticator=Authenticator(dev_tokens={"token-a": "account-a"}),
            rate_limiter=SlidingWindowRateLimiter(max_requests=1),
        )

        status, body = self.request("GET", "/sync/changes?since=0", token="token-a")
        self.assertEqual(status, 200)
        self.assertEqual(body["changes"], [])

        status, body = self.request("GET", "/sync/changes?since=0", token="token-a")
        self.assertEqual(status, 429)
        self.assertEqual(body["error"]["code"], "rate_limited")

    def test_rate_limiter_isolates_different_authenticated_users(self):
        self.app = SyncApp(
            store=self.store,
            authenticator=Authenticator(
                dev_tokens={"token-a": "account-a", "token-b": "account-b"},
            ),
            rate_limiter=SlidingWindowRateLimiter(max_requests=1),
        )

        status, _ = self.request("GET", "/sync/changes?since=0", token="token-a")
        self.assertEqual(status, 200)
        status, _ = self.request("GET", "/sync/changes?since=0", token="token-b")
        self.assertEqual(status, 200)

        status, body = self.request("GET", "/sync/changes?since=0", token="token-a")
        self.assertEqual(status, 429)
        self.assertEqual(body["error"]["code"], "rate_limited")

    def test_rate_limiter_uses_anonymous_bucket_for_missing_account(self):
        limiter = SlidingWindowRateLimiter(max_requests=1)

        limiter.check(None)
        with self.assertRaises(HttpError) as error:
            limiter.check("")

        self.assertEqual(error.exception.status, 429)
        self.assertEqual(error.exception.code, "rate_limited")
        limiter.check("account-a")

    def test_batch_too_large_takes_priority_over_rate_limit(self):
        self.app = SyncApp(
            store=self.store,
            authenticator=Authenticator(dev_tokens={"token-a": "account-a"}),
            rate_limiter=SlidingWindowRateLimiter(max_requests=1),
        )
        status, _ = self.request("GET", "/sync/changes?since=0", token="token-a")
        self.assertEqual(status, 200)

        status, body = self.request(
            "POST",
            "/sync/changes",
            token="token-a",
            body={"changes": [{}] * (MAX_BATCH_CHANGES + 1)},
        )

        self.assertEqual(status, 413)
        self.assertEqual(body["error"]["code"], "batch_too_large")

    def test_push_accepts_and_assigns_account_monotonic_server_seq(self):
        first = make_change(entity_id="timer-1", mark="a")
        second = make_change(entity_id="timer-2", mark="b")

        status, body = self.request("POST", "/sync/changes", token="token-a", body={"changes": [first, second]})

        self.assertEqual(status, 200)
        self.assertEqual(body["conflicts"], [])
        self.assertEqual(
            [(item["server_seq"], item["new_version"]) for item in body["accepted"]],
            [(1, 1), (2, 1)],
        )

        update = make_change(entity_id="timer-1", op="update", base_version=1, mark="a2")
        status, body = self.request("POST", "/sync/changes", token="token-a", body={"changes": [update]})

        self.assertEqual(status, 200)
        self.assertEqual(body["accepted"][0]["server_seq"], 3)
        self.assertEqual(body["accepted"][0]["new_version"], 2)
        head = self.store.get_head("account-a", "timing_record", "timer-1")
        self.assertIsNotNone(head)
        self.assertEqual(head["version"], 2)

    def test_push_accepts_client_payload_object_field(self):
        payload = {"record": {"id": 7, "value": "from-client"}}
        payload_json = json.dumps(payload, separators=(",", ":"))
        change = {
            "entity_type": "timing_record",
            "entity_id": "7",
            "op": "create",
            "base_version": 0,
            "payload": payload,
            "payload_hash": payload_hash(payload_json),
        }

        status, body = self.request("POST", "/sync/changes", token="token-a", body={"changes": [change]})

        self.assertEqual(status, 200)
        self.assertEqual(body["conflicts"], [])
        self.assertEqual(body["accepted"][0]["new_version"], 1)

        status, pulled = self.request("GET", "/sync/changes?since=0", token="token-a")

        self.assertEqual(status, 200)
        self.assertEqual(json.loads(pulled["changes"][0]["payload_json"]), payload)

    def test_conflict_when_base_version_is_stale_does_not_overwrite(self):
        original = make_change(mark="original")
        status, body = self.request("POST", "/sync/changes", token="token-a", body={"changes": [original]})
        self.assertEqual(status, 200)
        self.assertEqual(body["accepted"][0]["new_version"], 1)

        stale = make_change(op="update", base_version=0, mark="stale")
        status, body = self.request("POST", "/sync/changes", token="token-a", body={"changes": [stale]})

        self.assertEqual(status, 200)
        self.assertEqual(body["accepted"], [])
        self.assertEqual(body["conflicts"][0]["server_version"], 1)
        self.assertEqual(self.store.count_changes("account-a"), 1)
        head = self.store.get_head("account-a", "timing_record", "timer-1")
        self.assertEqual(head["payload_hash"], original["payload_hash"])

    def test_push_is_idempotent_by_account_entity_payload_hash(self):
        change = make_change(mark="same")

        status, first = self.request("POST", "/sync/changes", token="token-a", body={"changes": [change]})
        self.assertEqual(status, 200)
        status, second = self.request("POST", "/sync/changes", token="token-a", body={"changes": [change]})

        self.assertEqual(status, 200)
        self.assertEqual(second["conflicts"], [])
        self.assertEqual(second["accepted"], first["accepted"])
        self.assertEqual(self.store.count_changes("account-a"), 1)

    def test_pull_uses_cursor_order_pagination_and_includes_tombstone(self):
        create_one = make_change(entity_id="timer-1", mark="one")
        create_two = make_change(entity_id="timer-2", mark="two")
        delete_one = make_change(entity_id="timer-1", op="delete", base_version=1, mark="one-deleted")

        status, body = self.request(
            "POST",
            "/sync/changes",
            token="token-a",
            body={"changes": [create_one, create_two, delete_one], "device_id": "device-a"},
        )
        self.assertEqual(status, 200)
        self.assertEqual([item["server_seq"] for item in body["accepted"]], [1, 2, 3])

        status, first_page = self.request("GET", "/sync/changes?since=0&limit=2", token="token-a")
        self.assertEqual(status, 200)
        self.assertEqual([item["server_seq"] for item in first_page["changes"]], [1, 2])
        self.assertEqual(first_page["next_cursor"], 2)
        self.assertFalse(first_page["changes"][0]["deleted"])
        self.assertEqual(first_page["changes"][0]["origin_device_id"], "device-a")

        status, second_page = self.request("GET", "/sync/changes?since=2&limit=2", token="token-a")
        self.assertEqual(status, 200)
        self.assertEqual([item["server_seq"] for item in second_page["changes"]], [3])
        self.assertEqual(second_page["next_cursor"], 3)
        self.assertTrue(second_page["changes"][0]["deleted"])
        self.assertEqual(second_page["changes"][0]["new_version"], 2)

    def test_cross_account_isolation_uses_token_account_not_request_body(self):
        change = make_change(entity_id="shared-id", mark="a")
        status, body = self.request(
            "POST",
            "/sync/changes",
            token="token-a",
            body={"account_id": "account-b", "changes": [change]},
        )
        self.assertEqual(status, 200)
        self.assertEqual(body["accepted"][0]["server_seq"], 1)

        status, account_b_pull = self.request("GET", "/sync/changes?since=0", token="token-b")
        self.assertEqual(status, 200)
        self.assertEqual(account_b_pull["changes"], [])

        b_change = make_change(entity_id="shared-id", mark="b")
        status, b_push = self.request("POST", "/sync/changes", token="token-b", body={"changes": [b_change]})
        self.assertEqual(status, 200)
        self.assertEqual(b_push["accepted"][0]["server_seq"], 1)
        self.assertEqual(b_push["accepted"][0]["new_version"], 1)

        status, account_a_pull = self.request("GET", "/sync/changes?since=0", token="token-a")
        self.assertEqual(status, 200)
        self.assertEqual([item["payload_hash"] for item in account_a_pull["changes"]], [change["payload_hash"]])

    def test_push_logs_counts_without_payload_or_token(self):
        payload = payload_body("secret-push-payload")
        change = make_change(mark="ignored", payload=payload)

        with self.assertLogs("fleet_ledger.cloud_sync", level="INFO") as logs:
            status, body = self.request("POST", "/sync/changes", token="token-a", body={"changes": [change]})

        self.assertEqual(status, 200)
        self.assertEqual(len(body["accepted"]), 1)
        output = "\n".join(logs.output)
        self.assertIn('"account_id":"account-a"', output)
        self.assertIn('"op":"push"', output)
        self.assertIn('"accepted":1', output)
        self.assertIn('"conflicts":0', output)
        self.assertIn('"duration_ms":', output)
        self.assertIn('"status":"ok"', output)
        self.assertNotIn("token-a", output)
        self.assertNotIn("payload_json", output)
        self.assertNotIn(payload, output)
        self.assertNotIn("secret-push-payload", output)

    def test_pull_logs_counts_without_payload_or_token(self):
        payload = payload_body("secret-pull-payload")
        change = make_change(mark="ignored", payload=payload)
        status, body = self.request("POST", "/sync/changes", token="token-a", body={"changes": [change]})
        self.assertEqual(status, 200)
        self.assertEqual(body["accepted"][0]["server_seq"], 1)

        with self.assertLogs("fleet_ledger.cloud_sync", level="INFO") as logs:
            status, body = self.request("GET", "/sync/changes?since=0", token="token-a")

        self.assertEqual(status, 200)
        self.assertEqual(len(body["changes"]), 1)
        output = "\n".join(logs.output)
        self.assertIn('"account_id":"account-a"', output)
        self.assertIn('"op":"pull"', output)
        self.assertIn('"applied":0', output)
        self.assertIn('"returned":1', output)
        self.assertIn('"since":0', output)
        self.assertIn('"next_cursor":1', output)
        self.assertIn('"duration_ms":', output)
        self.assertIn('"status":"ok"', output)
        self.assertNotIn("token-a", output)
        self.assertNotIn("payload_json", output)
        self.assertNotIn(payload, output)
        self.assertNotIn("secret-pull-payload", output)

    def test_device_registration_upserts_per_account(self):
        status, first = self.request(
            "POST",
            "/sync/devices",
            token="token-a",
            body={"device_id": "device-1", "name": "First name"},
        )
        self.assertEqual(status, 200)

        status, second = self.request(
            "POST",
            "/sync/devices",
            token="token-a",
            body={"device_id": "device-1", "name": "Second name"},
        )
        self.assertEqual(status, 200)
        self.assertEqual(second["device_id"], "device-1")
        self.assertNotEqual(first["last_seen"], "")

        account_a_device = self.store.get_device("account-a", "device-1")
        self.assertEqual(account_a_device["name"], "Second name")

        status, _ = self.request(
            "POST",
            "/sync/devices",
            token="token-b",
            body={"device_id": "device-1", "name": "Other account"},
        )
        self.assertEqual(status, 200)
        account_b_device = self.store.get_device("account-b", "device-1")
        self.assertEqual(account_b_device["name"], "Other account")
        self.assertEqual(self.store.get_device("account-a", "device-1")["name"], "Second name")

    def test_rejects_invalid_jwt(self):
        authenticator = Authenticator(hs256_secret="secret", leeway_seconds=0)
        expired = make_hs256_jwt("secret", {"sub": "account-a", "exp": int(time.time()) - 10})

        with self.assertRaises(HttpError) as error:
            authenticator.authenticate(f"Bearer {expired}")

        self.assertEqual(error.exception.status, 401)
        self.assertEqual(error.exception.code, "token_expired")

    def test_app_config_reads_env_limits(self):
        with _patched_env(
            FLEET_SYNC_PORT="9010",
            FLEET_SYNC_DB_PATH="/tmp/fleet-sync.sqlite3",
            FLEET_SYNC_MAX_REQUEST_BYTES="1024",
            FLEET_SYNC_DEFAULT_PULL_LIMIT="25",
            FLEET_SYNC_MAX_PULL_LIMIT="50",
            FLEET_SYNC_RATE_LIMIT_MAX_REQUESTS="75",
            FLEET_SYNC_RATE_LIMIT_WINDOW_SECONDS="30",
        ):
            config = AppConfig.from_env()

        self.assertEqual(config.port, 9010)
        self.assertEqual(config.database_path, "/tmp/fleet-sync.sqlite3")
        self.assertEqual(config.max_request_bytes, 1024)
        self.assertEqual(config.default_pull_limit, 25)
        self.assertEqual(config.max_pull_limit, 50)
        self.assertEqual(config.rate_limit_max_requests, 75)
        self.assertEqual(config.rate_limit_window_seconds, 30)


def make_hs256_jwt(secret, payload):
    header = {"alg": "HS256", "typ": "JWT"}
    header_segment = base64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    payload_segment = base64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{header_segment}.{payload_segment}".encode("ascii")
    signature = hmac.new(secret.encode("utf-8"), signing_input, hashlib.sha256).digest()
    return f"{header_segment}.{payload_segment}.{base64url_encode(signature)}"


class _HandlerHarness:
    def __init__(self, app, path, headers, body):
        self._app = app
        self.path = path
        self.headers = headers
        self.rfile = io.BytesIO(body)
        self.wfile = io.BytesIO()
        self.status = None
        self.response_headers = {}

    @property
    def app(self):
        return self._app

    def send_response(self, status):
        self.status = status

    def send_header(self, name, value):
        self.response_headers[name.lower()] = value

    def end_headers(self):
        return None


class _patched_env:
    def __init__(self, **updates):
        self.updates = updates
        self.original = None

    def __enter__(self):
        self.original = os.environ.copy()
        os.environ.update(self.updates)

    def __exit__(self, exc_type, exc, tb):
        os.environ.clear()
        os.environ.update(self.original)
        return False


if __name__ == "__main__":
    unittest.main()
