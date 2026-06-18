import hashlib
import hmac
import io
import json
import os
import tempfile
import time
import unittest

from app import (
    AppConfig,
    Authenticator,
    HttpError,
    SyncApp,
    SyncStore,
    base64url_encode,
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

    def request(self, method, path, token=None, body=None, authorization=None):
        data = b""
        headers = {}
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
        ):
            config = AppConfig.from_env()

        self.assertEqual(config.port, 9010)
        self.assertEqual(config.database_path, "/tmp/fleet-sync.sqlite3")
        self.assertEqual(config.max_request_bytes, 1024)
        self.assertEqual(config.default_pull_limit, 25)
        self.assertEqual(config.max_pull_limit, 50)


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
