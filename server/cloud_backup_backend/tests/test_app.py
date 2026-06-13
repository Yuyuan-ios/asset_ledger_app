import hashlib
import hmac
import io
import json
import os
import sqlite3
import tempfile
import time
import unittest

from app import (
    AppConfig,
    Authenticator,
    BackupApp,
    BackupMetadataStore,
    FileObjectStore,
    HttpError,
    SlidingWindowRateLimiter,
    StorageError,
    base64url_encode,
    validate_envelope,
)


def make_envelope(payload=None):
    payload_json = json.dumps(payload or {"data": {"devices": []}}, separators=(",", ":"))
    return {
        "kind": "cloud_backup",
        "format_version": 1,
        "created_at": "2026-06-12T00:00:00.000Z",
        "db_schema_version": 36,
        "payload_sha256": hashlib.sha256(payload_json.encode("utf-8")).hexdigest(),
        "payload_bytes": len(payload_json.encode("utf-8")),
        "payload_encoding": "plaintext",
        "payload_json": payload_json,
    }


def make_encrypted_envelope(cipher_base64="AAECAwQF"):
    # 模拟 App 的加密信封:payload_json 为 base64 密文(非 JSON 对象),
    # 加密元数据随包透传,后端不解密。
    return {
        "kind": "cloud_backup",
        "format_version": 1,
        "created_at": "2026-06-12T00:00:00.000Z",
        "db_schema_version": 36,
        "payload_sha256": hashlib.sha256(cipher_base64.encode("utf-8")).hexdigest(),
        "payload_bytes": len(cipher_base64.encode("utf-8")),
        "payload_encoding": "aes-256-gcm",
        "encryption": {
            "algo": "AES-256-GCM",
            "kdf": "HKDF-SHA256",
            "salt": "c2FsdA==",
            "nonce": "bm9uY2U=",
            "key_id": "0123456789abcdef",
            "plaintext_sha256": "a" * 64,
            "plaintext_bytes": 42,
        },
        "payload_json": cipher_base64,
    }


class BackendTestCase(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.app = BackupApp(
            metadata_store=BackupMetadataStore(f"{self.temp_dir.name}/backups.sqlite3"),
            object_store=FileObjectStore(f"{self.temp_dir.name}/objects"),
            authenticator=Authenticator(dev_tokens={"token-a": "user-a", "token-b": "user-b"}),
            rate_limiter=SlidingWindowRateLimiter(max_requests=1000),
            oss_prefix="test/backups",
        )

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_upload_list_download_round_trip_is_user_scoped(self):
        envelope = make_envelope({"data": {"devices": [{"id": 1}]}})

        user_id = self.app.authenticator.authenticate("Bearer token-a")
        backup_id = self.app.create_backup(user_id, envelope)

        listed = self.app.list_backups("user-a")
        self.assertEqual([backup["backup_id"] for backup in listed], [backup_id])
        self.assertEqual(listed[0]["db_schema_version"], 36)

        downloaded = self.app.download_backup("user-a", backup_id)
        self.assertEqual(downloaded, envelope)

        with self.assertRaises(HttpError) as error:
            self.app.download_backup("user-b", backup_id)
        self.assertEqual(error.exception.status, 404)

    def test_encrypted_envelope_round_trips_and_is_not_decrypted(self):
        envelope = make_encrypted_envelope()
        user_id = self.app.authenticator.authenticate("Bearer token-a")
        backup_id = self.app.create_backup(user_id, envelope)

        downloaded = self.app.download_backup("user-a", backup_id)
        # 后端透传加密元数据,且 payload_json(base64 密文)未被当作 JSON 拒收。
        self.assertEqual(downloaded["payload_encoding"], "aes-256-gcm")
        self.assertEqual(downloaded["encryption"]["key_id"], "0123456789abcdef")
        self.assertEqual(downloaded["payload_json"], envelope["payload_json"])

    def test_encrypted_envelope_missing_metadata_is_rejected(self):
        envelope = make_encrypted_envelope()
        del envelope["encryption"]
        user_id = self.app.authenticator.authenticate("Bearer token-a")
        with self.assertRaises(HttpError) as error:
            self.app.create_backup(user_id, envelope)
        self.assertEqual(error.exception.status, 400)
        self.assertEqual(error.exception.code, "invalid_envelope")

    def test_request_body_user_id_is_ignored(self):
        envelope = make_envelope()
        envelope["user_id"] = "user-b"

        backup_id = self.app.create_backup("user-a", envelope)

        self.assertEqual(len(self.app.list_backups("user-a")), 1)
        self.assertEqual(self.app.list_backups("user-b"), [])
        with self.assertRaises(HttpError) as error:
            self.app.download_backup("user-b", backup_id)
        self.assertEqual(error.exception.status, 404)

    def test_rejects_missing_auth(self):
        with self.assertRaises(HttpError) as error:
            self.app.authenticator.authenticate(None)
        self.assertEqual(error.exception.status, 401)

    def test_rejects_malformed_auth(self):
        with self.assertRaises(HttpError) as error:
            self.app.authenticator.authenticate("Basic token-a")
        self.assertEqual(error.exception.status, 401)

    def test_rejects_invalid_expired_and_subjectless_jwt(self):
        secret = "test-secret"
        authenticator = Authenticator(hs256_secret=secret, leeway_seconds=0)

        with self.assertRaises(HttpError) as invalid_error:
            authenticator.authenticate("Bearer not-a-jwt")
        self.assertEqual(invalid_error.exception.status, 401)

        expired = make_hs256_jwt(secret, {"sub": "user-a", "exp": int(time.time()) - 10})
        with self.assertRaises(HttpError) as expired_error:
            authenticator.authenticate(f"Bearer {expired}")
        self.assertEqual(expired_error.exception.status, 401)
        self.assertEqual(expired_error.exception.code, "token_expired")

        subjectless = make_hs256_jwt(secret, {"exp": int(time.time()) + 3600})
        with self.assertRaises(HttpError) as subjectless_error:
            authenticator.authenticate(f"Bearer {subjectless}")
        self.assertEqual(subjectless_error.exception.status, 401)

    def test_validates_jwt_issuer_and_audience_when_configured(self):
        secret = "test-secret"
        authenticator = Authenticator(
            hs256_secret=secret,
            jwt_issuer="issuer-a",
            jwt_audience="fleet-ledger",
        )

        accepted = make_hs256_jwt(
            secret,
            {"sub": "user-a", "iss": "issuer-a", "aud": ["fleet-ledger"]},
        )
        self.assertEqual(authenticator.authenticate(f"Bearer {accepted}"), "user-a")

        wrong_audience = make_hs256_jwt(
            secret,
            {"sub": "user-a", "iss": "issuer-a", "aud": "other"},
        )
        with self.assertRaises(HttpError) as error:
            authenticator.authenticate(f"Bearer {wrong_audience}")
        self.assertEqual(error.exception.status, 401)

    def test_accepts_injected_token_introspection(self):
        authenticator = Authenticator(introspector=lambda token: f"user-for-{token}")

        self.assertEqual(
            authenticator.authenticate("Bearer opaque-token"),
            "user-for-opaque-token",
        )

    def test_introspection_errors_fail_closed(self):
        def inactive(_token):
            raise HttpError(401, "invalid_token", "token is not accepted")

        authenticator = Authenticator(introspector=inactive)

        with self.assertRaises(HttpError) as error:
            authenticator.authenticate("Bearer opaque-token")
        self.assertEqual(error.exception.status, 401)

    def test_rejects_payload_hash_mismatch(self):
        envelope = make_envelope()
        envelope["payload_json"] = envelope["payload_json"] + " "

        with self.assertRaises(HttpError) as error:
            self.app.create_backup("user-a", envelope)
        self.assertEqual(error.exception.status, 400)
        self.assertEqual(error.exception.code, "payload_size_mismatch")

    def test_rejects_malformed_payload_envelopes(self):
        cases = []

        missing_payload = make_envelope()
        missing_payload.pop("payload_json")
        cases.append((missing_payload, 400, "invalid_envelope"))

        missing_hash = make_envelope()
        missing_hash.pop("payload_sha256")
        cases.append((missing_hash, 400, "invalid_envelope"))

        unsupported_version = make_envelope()
        unsupported_version["format_version"] = 99
        cases.append((unsupported_version, 400, "unsupported_format_version"))

        malformed_payload_json = make_envelope()
        malformed_payload_json["payload_json"] = "{bad"
        malformed_payload_json["payload_bytes"] = len(
            malformed_payload_json["payload_json"].encode("utf-8")
        )
        malformed_payload_json["payload_sha256"] = hashlib.sha256(
            malformed_payload_json["payload_json"].encode("utf-8")
        ).hexdigest()
        cases.append((malformed_payload_json, 400, "invalid_payload_json"))

        bool_schema = make_envelope()
        bool_schema["db_schema_version"] = True
        cases.append((bool_schema, 400, "invalid_envelope"))

        for envelope, status, code in cases:
            with self.subTest(code=code):
                with self.assertRaises(HttpError) as error:
                    validate_envelope(envelope, 64 * 1024 * 1024)
                self.assertEqual(error.exception.status, status)
                self.assertEqual(error.exception.code, code)

    def test_rejects_oversized_payload(self):
        envelope = make_envelope({"data": {"blob": "x" * 128}})

        with self.assertRaises(HttpError) as error:
            validate_envelope(envelope, 16)

        self.assertEqual(error.exception.status, 413)
        self.assertEqual(error.exception.code, "payload_too_large")

    def test_storage_upload_failure_does_not_write_success_metadata(self):
        app = BackupApp(
            metadata_store=BackupMetadataStore(f"{self.temp_dir.name}/failing-put.sqlite3"),
            object_store=_FailingPutObjectStore(),
            authenticator=Authenticator(dev_tokens={"token-a": "user-a"}),
            rate_limiter=SlidingWindowRateLimiter(max_requests=1000),
        )

        with self.assertRaises(HttpError) as error:
            app.create_backup("user-a", make_envelope())

        self.assertEqual(error.exception.status, 502)
        self.assertEqual(app.list_backups("user-a"), [])

    def test_metadata_write_failure_cleans_uploaded_object(self):
        object_store = _RecordingObjectStore(f"{self.temp_dir.name}/recording-objects")
        app = BackupApp(
            metadata_store=_FailingMetadataStore(f"{self.temp_dir.name}/failing-db.sqlite3"),
            object_store=object_store,
            authenticator=Authenticator(dev_tokens={"token-a": "user-a"}),
            rate_limiter=SlidingWindowRateLimiter(max_requests=1000),
        )

        with self.assertRaises(HttpError) as error:
            app.create_backup("user-a", make_envelope())

        self.assertEqual(error.exception.status, 500)
        self.assertEqual(error.exception.code, "metadata_write_failed")
        self.assertEqual(object_store.deleted_keys, object_store.put_keys)

    def test_metadata_table_has_required_indexes(self):
        with self.app.metadata_store._connect() as conn:
            rows = conn.execute("PRAGMA index_list(backups)").fetchall()
        index_names = {row["name"] for row in rows}

        self.assertIn("idx_backups_user_created", index_names)
        self.assertIn("idx_backups_user_id", index_names)
        self.assertIn("idx_backups_created_at", index_names)

    def test_app_config_reads_deployment_limits_from_env(self):
        with _patched_env(
            FLEET_BACKUP_PORT="9001",
            FLEET_BACKUP_MAX_PAYLOAD_BYTES="1024",
            FLEET_BACKUP_MAX_REQUEST_BYTES="2048",
        ):
            config = AppConfig.from_env()

        self.assertEqual(config.port, 9001)
        self.assertEqual(config.max_payload_bytes, 1024)
        self.assertEqual(config.max_request_bytes, 2048)

    def test_app_config_rejects_request_limit_below_payload_limit(self):
        with _patched_env(
            FLEET_BACKUP_MAX_PAYLOAD_BYTES="2048",
            FLEET_BACKUP_MAX_REQUEST_BYTES="1024",
        ):
            with self.assertRaises(ValueError):
                AppConfig.from_env()


class BackendHttpTestCase(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.app = BackupApp(
            metadata_store=BackupMetadataStore(f"{self.temp_dir.name}/backups.sqlite3"),
            object_store=FileObjectStore(f"{self.temp_dir.name}/objects"),
            authenticator=Authenticator(dev_tokens={"token-a": "user-a", "token-b": "user-b"}),
            rate_limiter=SlidingWindowRateLimiter(max_requests=1000),
            oss_prefix="test/backups",
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
        from app import BackupRequestHandler

        BackupRequestHandler._handle(handler, method)
        return handler.status, json.loads(handler.wfile.getvalue().decode("utf-8"))

    def test_http_endpoints_require_bearer_token(self):
        status, body = self.request("GET", "/v1/backups")
        self.assertEqual(status, 401)
        self.assertEqual(body["error"]["code"], "unauthorized")

        status, body = self.request("GET", "/v1/backups", authorization="Token token-a")
        self.assertEqual(status, 401)
        self.assertEqual(body["error"]["code"], "unauthorized")

        status, body = self.request("POST", "/v1/backups", body=make_envelope())
        self.assertEqual(status, 401)
        self.assertEqual(body["error"]["code"], "unauthorized")

    def test_http_upload_list_download_is_user_scoped(self):
        status, body = self.request("POST", "/v1/backups", token="token-a", body=make_envelope())
        self.assertEqual(status, 200)
        backup_id = body["backup_id"]

        status, body = self.request("GET", "/v1/backups", token="token-b")
        self.assertEqual(status, 200)
        self.assertEqual(body["backups"], [])

        status, body = self.request("GET", f"/v1/backups/{backup_id}", token="token-b")
        self.assertEqual(status, 404)
        self.assertEqual(body["error"]["code"], "not_found")


def make_hs256_jwt(secret, payload):
    header = {"alg": "HS256", "typ": "JWT"}
    header_segment = base64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    payload_segment = base64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{header_segment}.{payload_segment}".encode("ascii")
    signature = hmac.new(secret.encode("utf-8"), signing_input, hashlib.sha256).digest()
    return f"{header_segment}.{payload_segment}.{base64url_encode(signature)}"


class _FailingPutObjectStore:
    def put_text(self, key, body, content_type="application/json"):
        raise StorageError("simulated object storage failure")

    def get_text(self, key):
        raise StorageError("simulated object storage failure")


class _RecordingObjectStore(FileObjectStore):
    def __init__(self, root_dir):
        super().__init__(root_dir)
        self.put_keys = []
        self.deleted_keys = []

    def put_text(self, key, body, content_type="application/json"):
        self.put_keys.append(key)
        super().put_text(key, body, content_type)

    def delete_text(self, key):
        self.deleted_keys.append(key)
        super().delete_text(key)


class _FailingMetadataStore(BackupMetadataStore):
    def insert(self, metadata):
        raise sqlite3.OperationalError("simulated metadata failure")


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
