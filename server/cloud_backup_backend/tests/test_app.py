import hashlib
import hmac
import io
import json
import logging
import os
import sqlite3
import tempfile
import time
import unittest
import urllib.error
from unittest import mock

from app import (
    AccountIdentityResolver,
    AppConfig,
    AuthPlane,
    Authenticator,
    BackupApp,
    BackupMetadataStore,
    ConfigMigrationError,
    EXTERNAL_CLIENT_TOKEN_REQUIRED,
    EntitlementResolver,
    FileObjectStore,
    HttpError,
    HttpCloudBackupEntitlementVerifier,
    PaidEntitlementState,
    SecurityViolation,
    SlidingWindowRateLimiter,
    StaticMaxUserEntitlementVerifier,
    StorageError,
    base64url_encode,
    build_cloud_backup_entitlement_verifier_from_env,
    configure_logging,
    main,
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
            authenticator=Authenticator(
                dev_tokens={
                    "token-a": "user-a",
                    "token-b": "user-b",
                    "token-free": "user-free",
                    "token-pro": "user-pro",
                    "token-max": "user-max",
                    "token-expired": "user-expired",
                }
            ),
            rate_limiter=SlidingWindowRateLimiter(max_requests=1000),
            oss_prefix="test/backups",
            account_key_secret="x" * 48,
            entitlement_verifier=_MaxEntitlementVerifier(),
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

    def test_create_logs_structured_event_without_payload(self):
        secret_marker = "secret-backup-payload"
        envelope = make_envelope({"data": {"note": secret_marker}})
        user_id = self.app.authenticator.authenticate("Bearer token-a")

        with self.assertLogs("fleet_ledger.cloud_backup", level="INFO") as logs:
            backup_id = self.app.create_backup(user_id, envelope)

        output = "\n".join(logs.output)
        self.assertIn('"account_id":"user-a"', output)
        self.assertIn('"op":"create"', output)
        self.assertIn(f'"backup_id":"{backup_id}"', output)
        self.assertIn('"db_schema_version":36', output)
        self.assertIn('"payload_bytes":', output)
        self.assertIn('"duration_ms":', output)
        self.assertIn('"status":"ok"', output)
        self.assertNotIn(secret_marker, output)
        self.assertNotIn(envelope["payload_json"], output)
        self.assertNotIn(envelope["payload_sha256"], output)
        self.assertNotIn("token-a", output)

    def test_list_logs_structured_event(self):
        user_id = self.app.authenticator.authenticate("Bearer token-a")
        self.app.create_backup(user_id, make_envelope())

        with self.assertLogs("fleet_ledger.cloud_backup", level="INFO") as logs:
            self.app.list_backups("user-a")

        output = "\n".join(logs.output)
        self.assertIn('"account_id":"user-a"', output)
        self.assertIn('"op":"list"', output)
        self.assertIn('"count":1', output)
        self.assertIn('"duration_ms":', output)
        self.assertIn('"status":"ok"', output)

    def test_download_logs_structured_event_without_payload(self):
        secret_marker = "secret-download-payload"
        envelope = make_envelope({"data": {"note": secret_marker}})
        user_id = self.app.authenticator.authenticate("Bearer token-a")
        backup_id = self.app.create_backup(user_id, envelope)

        with self.assertLogs("fleet_ledger.cloud_backup", level="INFO") as logs:
            self.app.download_backup("user-a", backup_id)

        output = "\n".join(logs.output)
        self.assertIn('"account_id":"user-a"', output)
        self.assertIn('"op":"download"', output)
        self.assertIn(f'"backup_id":"{backup_id}"', output)
        self.assertIn('"duration_ms":', output)
        self.assertIn('"status":"ok"', output)
        self.assertNotIn(secret_marker, output)
        self.assertNotIn(envelope["payload_json"], output)

    def test_download_failure_logs_error_status(self):
        with self.assertLogs("fleet_ledger.cloud_backup", level="INFO") as logs:
            with self.assertRaises(HttpError):
                self.app.download_backup("user-a", "missing-backup-id")

        output = "\n".join(logs.output)
        self.assertIn('"op":"download"', output)
        self.assertIn('"status":"error"', output)

    def test_issue_account_backup_key_logs_event_without_secret(self):
        with self.assertLogs("fleet_ledger.cloud_backup", level="INFO") as logs:
            secret = self.app.issue_account_backup_key("user-a")

        output = "\n".join(logs.output)
        self.assertIn('"account_id":"user-a"', output)
        self.assertIn('"op":"issue_key"', output)
        self.assertIn('"duration_ms":', output)
        self.assertIn('"status":"ok"', output)
        self.assertNotIn(secret, output)

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

    def test_account_backup_key_is_stable_per_account_and_high_entropy(self):
        app = BackupApp(
            metadata_store=BackupMetadataStore(f"{self.temp_dir.name}/k.sqlite3"),
            object_store=FileObjectStore(f"{self.temp_dir.name}/k-objects"),
            authenticator=Authenticator(dev_tokens={"token-a": "user-a", "token-b": "user-b"}),
            account_key_secret="x" * 48,
        )
        a1 = app.issue_account_backup_key("user-a")
        a2 = app.issue_account_backup_key("user-a")
        b1 = app.issue_account_backup_key("user-b")
        self.assertEqual(a1, a2, "同账号必须稳定(换机/轮换可解密旧包)")
        self.assertNotEqual(a1, b1, "不同账号密钥不同")
        self.assertEqual(len(a1), 64, "HMAC-SHA256 hex = 256-bit 高熵")

    def test_account_backup_key_requires_configured_master_secret(self):
        app = BackupApp(
            metadata_store=BackupMetadataStore(f"{self.temp_dir.name}/k2.sqlite3"),
            object_store=FileObjectStore(f"{self.temp_dir.name}/k2-objects"),
            authenticator=Authenticator(dev_tokens={"token-a": "user-a"}),
            account_key_secret="",
        )
        with self.assertRaises(HttpError) as error:
            app.issue_account_backup_key("user-a")
        self.assertEqual(error.exception.status, 503)
        self.assertEqual(error.exception.code, "backup_key_unavailable")

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
        calls = []

        def introspector(token):
            calls.append(token)
            return f"user-for-{token}"

        authenticator = Authenticator(introspector=introspector)

        self.assertEqual(
            authenticator.authenticate("Bearer opaque-token"),
            "user-for-opaque-token",
        )
        self.assertEqual(
            authenticator.authenticate("Bearer opaque-token"),
            "user-for-opaque-token",
        )
        self.assertEqual(calls, ["opaque-token"])
        self.assertEqual(authenticator.auth_plane, AuthPlane.USER)

    def test_introspection_errors_fail_closed(self):
        calls = []

        def inactive(_token):
            calls.append(_token)
            raise HttpError(401, "invalid_token", "token is not accepted")

        authenticator = Authenticator(introspector=inactive)

        with self.assertRaises(HttpError) as error:
            authenticator.authenticate("Bearer opaque-token")
        self.assertEqual(error.exception.status, 401)
        with self.assertRaises(HttpError):
            authenticator.authenticate("Bearer opaque-token")
        self.assertEqual(calls, ["opaque-token", "opaque-token"])

    def test_account_identity_resolver_keeps_user_id_stable_across_token_refresh(self):
        authenticator = Authenticator(
            dev_tokens={
                "token-a-v1": "user-a",
                "token-a-v2": "user-a",
            }
        )

        self.assertEqual(authenticator.authenticate("Bearer token-a-v1"), "user-a")
        self.assertEqual(authenticator.authenticate("Bearer token-a-v2"), "user-a")

    def test_account_identity_resolver_exposes_stable_user_id_contract(self):
        resolver = AccountIdentityResolver(lambda token: f"user-{token}")

        self.assertEqual(resolver.getStableUserId("a"), "user-a")

    def test_client_plane_is_blocked_from_auth_operations(self):
        self.assertFalse(EXTERNAL_CLIENT_TOKEN_REQUIRED)
        with self.assertRaisesRegex(SecurityViolation, "CLIENT token plane"):
            AccountIdentityResolver(lambda token: f"user-{token}", auth_plane=AuthPlane.CLIENT)

        authenticator = Authenticator(dev_tokens={"client-token": "user-client"})
        authenticator.auth_plane = AuthPlane.CLIENT
        with self.assertRaisesRegex(SecurityViolation, "CLIENT token plane"):
            authenticator.authenticate("Bearer client-token")

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
            FLEET_BACKUP_ACCOUNT_KEY_SECRET="x" * 48,
        ):
            config = AppConfig.from_env()

        self.assertEqual(config.port, 9001)
        self.assertEqual(config.max_payload_bytes, 1024)
        self.assertEqual(config.max_request_bytes, 2048)
        self.assertEqual(config.account_key_secret, "x" * 48)

    def test_deprecated_env_keys_raise_migration_error(self):
        auth_key = "FLEET" + "_BACKUP_AUTH_HS256_SECRET"
        with _patched_env(clear=True, **{auth_key: "old-secret"}):
            with self.assertRaisesRegex(ConfigMigrationError, "USER_AUTH_HS256_SECRET"):
                AppConfig.from_env()

        service_key = "FLEET" + "_BACKUP_ENTITLEMENT_BEARER_TOKEN"
        with _patched_env(clear=True, **{service_key: "old-token"}):
            with self.assertRaisesRegex(ConfigMigrationError, "SERVICE_INTERNAL_TOKEN"):
                AppConfig.from_env()

    def test_app_config_rejects_request_limit_below_payload_limit(self):
        with _patched_env(
            FLEET_BACKUP_MAX_PAYLOAD_BYTES="2048",
            FLEET_BACKUP_MAX_REQUEST_BYTES="1024",
        ):
            with self.assertRaises(ValueError):
                AppConfig.from_env()

    def test_production_entitlement_config_requires_url(self):
        with _patched_env(clear=True, APP_ENV="production"):
            with self.assertRaisesRegex(ValueError, "CLOUD_BACKUP_ENTITLEMENT_URL"):
                build_cloud_backup_entitlement_verifier_from_env()

    def test_production_entitlement_config_requires_token(self):
        with _patched_env(
            clear=True,
            APP_ENV="production",
            CLOUD_BACKUP_ENTITLEMENT_URL="https://api.example.test/entitlement",
        ):
            with self.assertRaisesRegex(ValueError, "SERVICE_INTERNAL_TOKEN"):
                build_cloud_backup_entitlement_verifier_from_env()

    def test_unset_app_env_defaults_to_production_entitlement_config(self):
        with _patched_env(clear=True):
            with self.assertRaisesRegex(ValueError, "CLOUD_BACKUP_ENTITLEMENT_URL"):
                build_cloud_backup_entitlement_verifier_from_env()

    def test_production_rejects_static_entitlement_allowlist(self):
        with _patched_env(
            clear=True,
            APP_ENV="production",
            CLOUD_BACKUP_MAX_ENTITLED_USERS_JSON='["user-max"]',
        ):
            with self.assertRaisesRegex(ValueError, "not allowed"):
                build_cloud_backup_entitlement_verifier_from_env()

    def test_local_static_entitlement_allowlist_is_explicit_only(self):
        with _patched_env(
            clear=True,
            APP_ENV="local",
            CLOUD_BACKUP_MAX_ENTITLED_USERS_JSON='["user-max"]',
        ):
            verifier = build_cloud_backup_entitlement_verifier_from_env()

        self.assertIsInstance(verifier, StaticMaxUserEntitlementVerifier)
        verifier.require_max("user-max")
        with self.assertRaises(HttpError) as error:
            verifier.require_max("user-free")
        self.assertEqual(error.exception.status, 403)

    def test_production_url_and_token_build_http_entitlement_verifier(self):
        with _patched_env(
            clear=True,
            APP_ENV="production",
            CLOUD_BACKUP_ENTITLEMENT_URL="https://api.example.test/entitlement",
            SERVICE_INTERNAL_TOKEN="server-token",
            CLOUD_BACKUP_ENTITLEMENT_TIMEOUT_SECONDS="3",
            CLOUD_BACKUP_ENTITLEMENT_CACHE_TTL_SECONDS="7",
        ):
            verifier = build_cloud_backup_entitlement_verifier_from_env()

        self.assertIsInstance(verifier, HttpCloudBackupEntitlementVerifier)
        self.assertEqual(verifier.auth_plane, AuthPlane.SERVICE)
        self.assertEqual(verifier.timeout_seconds, 3)
        self.assertEqual(verifier.cache_ttl_seconds, 7)


class EntitlementVerifierTestCase(unittest.TestCase):
    def test_http_verifier_sends_server_token_and_allows_active_max(self):
        calls = []

        def urlopen(request, timeout):
            calls.append((request, timeout))
            return _HttpResponse({"entitlementTier": "max", "active": True})

        verifier = HttpCloudBackupEntitlementVerifier(
            "https://api.example.test/entitlement",
            service_internal_token="server-token",
            timeout_seconds=2,
        )

        with mock.patch("entitlements.urllib.request.urlopen", side_effect=urlopen):
            verifier.require_max("user-max")

        self.assertEqual(len(calls), 1)
        request, timeout = calls[0]
        self.assertEqual(timeout, 2)
        self.assertEqual(request.get_method(), "POST")
        self.assertEqual(request.get_header("Authorization"), "Bearer server-token")
        self.assertEqual(request.get_header("Content-type"), "application/json")
        body = json.loads(request.data.decode("utf-8"))
        self.assertEqual(body["user_id"], "user-max")
        self.assertEqual(body["required_capability"], "cloud_backup")
        self.assertEqual(body["required_plan"], "max")

    def test_http_verifier_rejects_free_pro_expired_and_missing_fields(self):
        cases = [
            ({"entitlementTier": "free", "active": True}, 403),
            ({"entitlementTier": "pro", "active": True}, 403),
            ({"entitlementTier": "max", "status": "expired"}, 403),
            ({"entitlementTier": "max"}, 403),
            ({"active": True}, 403),
        ]

        for response, status in cases:
            with self.subTest(response=response):
                verifier = HttpCloudBackupEntitlementVerifier(
                    "https://api.example.test/entitlement",
                    service_internal_token="server-token",
                )
                with mock.patch(
                    "entitlements.urllib.request.urlopen",
                    return_value=_HttpResponse(response),
                ):
                    with self.assertRaises(HttpError) as error:
                        verifier.require_max("user-a")
                self.assertEqual(error.exception.status, status)
                self.assertEqual(error.exception.code, "cloud_backup_requires_max")

    def test_http_verifier_treats_service_errors_as_unavailable(self):
        cases = [
            urllib.error.HTTPError(
                "https://api.example.test/entitlement",
                500,
                "server error",
                {},
                None,
            ),
            TimeoutError("timed out"),
            urllib.error.URLError("network down"),
        ]

        for side_effect in cases:
            with self.subTest(side_effect=type(side_effect).__name__):
                verifier = HttpCloudBackupEntitlementVerifier(
                    "https://api.example.test/entitlement",
                    service_internal_token="server-token",
                )
                with mock.patch(
                    "entitlements.urllib.request.urlopen",
                    side_effect=side_effect,
                ):
                    with self.assertRaises(HttpError) as error:
                        verifier.require_max("user-a")
                self.assertEqual(error.exception.status, 503)
                self.assertEqual(
                    error.exception.code,
                    "subscription_verification_unavailable",
                )

    def test_http_verifier_treats_auth_and_not_found_as_requires_max(self):
        cases = [401, 403, 404]

        for status_code in cases:
            with self.subTest(status_code=status_code):
                verifier = HttpCloudBackupEntitlementVerifier(
                    "https://api.example.test/entitlement",
                    service_internal_token="server-token",
                )
                with mock.patch(
                    "entitlements.urllib.request.urlopen",
                    side_effect=urllib.error.HTTPError(
                        "https://api.example.test/entitlement",
                        status_code,
                        "denied",
                        {},
                        None,
                    ),
                ):
                    with self.assertRaises(HttpError) as error:
                        verifier.require_max("user-a")
                self.assertEqual(error.exception.status, 403)
                self.assertEqual(error.exception.code, "cloud_backup_requires_max")

    def test_http_verifier_malformed_json_fails_closed_as_unavailable(self):
        verifier = HttpCloudBackupEntitlementVerifier(
            "https://api.example.test/entitlement",
            service_internal_token="server-token",
        )

        with mock.patch(
            "entitlements.urllib.request.urlopen",
            return_value=_RawHttpResponse(b"{not-json"),
        ):
            with self.assertRaises(HttpError) as error:
                verifier.require_max("user-a")

        self.assertEqual(error.exception.status, 503)
        self.assertEqual(error.exception.code, "subscription_verification_unavailable")


class BackendHttpTestCase(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.app = BackupApp(
            metadata_store=BackupMetadataStore(f"{self.temp_dir.name}/backups.sqlite3"),
            object_store=FileObjectStore(f"{self.temp_dir.name}/objects"),
            authenticator=Authenticator(
                dev_tokens={
                    "token-a": "user-a",
                    "token-b": "user-b",
                    "token-free": "user-free",
                    "token-pro": "user-pro",
                    "token-max": "user-max",
                    "token-expired": "user-expired",
                }
            ),
            rate_limiter=SlidingWindowRateLimiter(max_requests=1000),
            oss_prefix="test/backups",
            account_key_secret="x" * 48,
            entitlement_verifier=_MaxEntitlementVerifier(),
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
        from app import BackupRequestHandler

        BackupRequestHandler._handle(handler, method)
        return handler.status, json.loads(handler.wfile.getvalue().decode("utf-8"))

    def test_healthz_is_unauthenticated_and_bypasses_version_gate(self):
        with (
            _patched_env(clear=True),
            mock.patch(
                "app.VERSION_UPGRADE_GATE.enforce",
                side_effect=AssertionError("gate should not run"),
            ),
        ):
            status, body = self.request("GET", "/healthz")

        self.assertEqual(status, 200)
        self.assertEqual(
            body,
            {
                "ok": True,
                "app_env": "production",
                "cloud_backup_entitlement_required": True,
                "entitlement_verifier": "configured",
            },
        )

    def test_version_gate_returns_426_for_outdated_client_before_auth(self):
        policy_path = self.write_version_policy(min_version="2.0.0")

        with _patched_env(FLEET_BACKUP_VERSION_POLICY_PATH=policy_path):
            status, body = self.request(
                "GET",
                "/v1/backups",
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

        with _patched_env(FLEET_BACKUP_VERSION_POLICY_PATH=policy_path):
            status, body = self.request(
                "GET",
                "/v1/backups",
                headers={
                    "X-App-Version": "1.4.0-alpha+12",
                    "X-Platform": "android",
                },
            )

        self.assertEqual(status, 401)
        self.assertEqual(body["error"]["code"], "unauthorized")

    def test_version_gate_fail_opens_when_required_headers_are_missing(self):
        policy_path = self.write_version_policy(min_version="2.0.0")

        with _patched_env(FLEET_BACKUP_VERSION_POLICY_PATH=policy_path):
            missing_version_status, missing_version_body = self.request(
                "GET",
                "/v1/backups",
                headers={"X-Platform": "android"},
            )
            missing_platform_status, missing_platform_body = self.request(
                "GET",
                "/v1/backups",
                headers={"X-App-Version": "1.0.0"},
            )

        self.assertEqual(missing_version_status, 401)
        self.assertEqual(missing_version_body["error"]["code"], "unauthorized")
        self.assertEqual(missing_platform_status, 401)
        self.assertEqual(missing_platform_body["error"]["code"], "unauthorized")

    def test_version_gate_fail_opens_when_policy_is_unconfigured_or_missing(self):
        request_headers = {"X-App-Version": "1.0.0", "X-Platform": "android"}

        with mock.patch.dict(os.environ, {}, clear=True):
            status, body = self.request("GET", "/v1/backups", headers=request_headers)
        self.assertEqual(status, 401)
        self.assertEqual(body["error"]["code"], "unauthorized")

        with _patched_env(FLEET_BACKUP_VERSION_POLICY_PATH=f"{self.temp_dir.name}/missing.json"):
            status, body = self.request("GET", "/v1/backups", headers=request_headers)

        self.assertEqual(status, 401)
        self.assertEqual(body["error"]["code"], "unauthorized")

    def test_version_gate_fail_opens_on_invalid_semver(self):
        valid_policy_path = self.write_version_policy(min_version="2.0.0")
        invalid_policy_path = self.write_version_policy(min_version="not-semver", filename="invalid-policy.json")

        with _patched_env(FLEET_BACKUP_VERSION_POLICY_PATH=valid_policy_path):
            invalid_current_status, invalid_current_body = self.request(
                "GET",
                "/v1/backups",
                headers={
                    "X-App-Version": "1.0",
                    "X-Platform": "android",
                },
            )
        with _patched_env(FLEET_BACKUP_VERSION_POLICY_PATH=invalid_policy_path):
            invalid_min_status, invalid_min_body = self.request(
                "GET",
                "/v1/backups",
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
            server_address = ("127.0.0.1", 8008)

            def serve_forever(self):
                calls.append("serve")

        with (
            mock.patch("app.configure_logging", side_effect=lambda: calls.append("logging")),
            mock.patch("app.build_server_from_env", side_effect=lambda: calls.append("build") or FakeServer()),
            mock.patch("sys.stdout", new=io.StringIO()),
        ):
            main()

        self.assertEqual(calls, ["logging", "build", "serve"])

    def test_internal_error_logs_request_id_without_sensitive_fields(self):
        secret_payload = "secret-backup-payload"
        envelope = make_envelope({"data": {"secret": secret_payload}})
        self.app.create_backup = mock.Mock(side_effect=RuntimeError("simulated failure"))

        with self.assertLogs("fleet_ledger.cloud_backup", level="ERROR") as logs:
            status, body = self.request(
                "POST",
                "/v1/backups",
                token="token-a",
                body=envelope,
                headers={"X-Request-Id": "rid-123"},
            )

        self.assertEqual(status, 500)
        self.assertEqual(body["error"]["code"], "internal_error")
        output = "\n".join(logs.output)
        self.assertIn("backup_request_error", output)
        self.assertIn('"event":"internal_error"', output)
        self.assertIn('"request_id":"rid-123"', output)
        self.assertIn('"method":"POST"', output)
        self.assertIn('"path":"/v1/backups"', output)
        self.assertNotIn("token-a", output)
        self.assertNotIn("authorization", output.lower())
        self.assertNotIn("payload_json", output)
        self.assertNotIn(secret_payload, output)

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

    def test_http_endpoints_fail_closed_when_max_entitlement_is_unconfigured(self):
        app = BackupApp(
            metadata_store=BackupMetadataStore(f"{self.temp_dir.name}/fail-closed.sqlite3"),
            object_store=FileObjectStore(f"{self.temp_dir.name}/fail-closed-objects"),
            authenticator=Authenticator(dev_tokens={"token-a": "user-a"}),
            rate_limiter=SlidingWindowRateLimiter(max_requests=1000),
            account_key_secret="x" * 48,
        )
        handler = _HandlerHarness(
            app,
            "/v1/backups",
            {"authorization": "Bearer token-a"},
            b"",
        )
        from app import BackupRequestHandler

        BackupRequestHandler._handle(handler, "GET")
        body = json.loads(handler.wfile.getvalue().decode("utf-8"))
        self.assertEqual(handler.status, 403)
        self.assertEqual(body["error"]["code"], "cloud_backup_requires_max")

    def test_http_cloud_backup_endpoints_reject_free_and_pro_entitlements(self):
        self.app.entitlement_verifier = _TierEntitlementVerifier(
            {
                "user-free": "free",
                "user-pro": "pro",
                "user-max": "max",
                "user-expired": "expired",
            }
        )

        cases = [
            ("GET", "/v1/account/backup-key", None),
            ("POST", "/v1/backups", make_envelope()),
            ("GET", "/v1/backups", None),
            ("GET", "/v1/backups/missing-backup-id", None),
        ]

        for token in ("token-free", "token-pro", "token-expired"):
            for method, path, body in cases:
                with self.subTest(token=token, method=method, path=path):
                    status, response = self.request(method, path, token=token, body=body)
                    self.assertEqual(status, 403)
                    self.assertEqual(response["error"]["code"], "cloud_backup_requires_max")
                    self.assertEqual(
                        response["error"]["message"],
                        "Cloud backup requires Max subscription.",
                    )

    def test_http_cloud_backup_does_not_trust_client_subscription_tier_header(self):
        self.app.entitlement_verifier = _TierEntitlementVerifier({"user-free": "free"})

        status, response = self.request(
            "GET",
            "/v1/backups",
            token="token-free",
            headers={"X-Subscription-Tier": "max"},
        )

        self.assertEqual(status, 403)
        self.assertEqual(response["error"]["code"], "cloud_backup_requires_max")

    def test_http_cloud_backup_does_not_trust_external_client_token(self):
        status, response = self.request(
            "GET",
            "/v1/backups",
            authorization="Bearer external-client-token",
            headers={"X-Subscription-Tier": "max"},
        )

        self.assertEqual(status, 401)
        self.assertEqual(response["error"]["code"], "unauthorized")

    def test_all_current_cloud_backup_routes_hit_max_guard(self):
        cases = [
            ("GET", "/v1/account/backup-key", None),
            ("POST", "/v1/backups", make_envelope()),
            ("GET", "/v1/backups", None),
            ("GET", "/v1/backups/missing-backup-id", None),
        ]

        for method, path, body in cases:
            with self.subTest(method=method, path=path):
                verifier = _RecordingEntitlementVerifier()
                self.app.entitlement_verifier = verifier
                self.request(method, path, token="token-a", body=body)
                self.assertEqual(verifier.user_ids, ["user-a"])

    def test_http_cloud_backup_endpoints_allow_max_entitlement(self):
        self.app.entitlement_verifier = _TierEntitlementVerifier(
            {
                "user-free": "free",
                "user-pro": "pro",
                "user-max": "max",
            }
        )

        status, key = self.request("GET", "/v1/account/backup-key", token="token-max")
        self.assertEqual(status, 200)
        self.assertEqual(len(key["backup_secret"]), 64)

        status, uploaded = self.request("POST", "/v1/backups", token="token-max", body=make_envelope())
        self.assertEqual(status, 200)
        backup_id = uploaded["backup_id"]

        status, listed = self.request("GET", "/v1/backups", token="token-max")
        self.assertEqual(status, 200)
        self.assertEqual([item["backup_id"] for item in listed["backups"]], [backup_id])

        status, downloaded = self.request("GET", f"/v1/backups/{backup_id}", token="token-max")
        self.assertEqual(status, 200)
        self.assertEqual(downloaded["kind"], "cloud_backup")

    def test_paid_active_allows_cloud_backup_routes_through_resolver(self):
        self.app.entitlement_verifier = _DecisionEntitlementVerifier(
            PaidEntitlementState.ACTIVE,
        )

        status, key = self.request("GET", "/v1/account/backup-key", token="token-a")
        self.assertEqual(status, 200)
        self.assertEqual(len(key["backup_secret"]), 64)

        status, uploaded = self.request("POST", "/v1/backups", token="token-a", body=make_envelope())
        self.assertEqual(status, 200)
        backup_id = uploaded["backup_id"]

        status, listed = self.request("GET", "/v1/backups", token="token-a")
        self.assertEqual(status, 200)
        self.assertEqual([item["backup_id"] for item in listed["backups"]], [backup_id])

    def test_paid_none_denies_cloud_backup_routes_through_resolver(self):
        self.app.entitlement_verifier = _DecisionEntitlementVerifier(
            PaidEntitlementState.NONE,
        )

        cases = [
            ("GET", "/v1/account/backup-key", None),
            ("POST", "/v1/backups", make_envelope()),
            ("GET", "/v1/backups", None),
            ("GET", "/v1/backups/missing-backup-id", None),
        ]
        for method, path, body in cases:
            with self.subTest(method=method, path=path):
                status, response = self.request(method, path, token="token-a", body=body)
                self.assertEqual(status, 403)
                self.assertEqual(response["error"]["code"], "cloud_backup_requires_max")

    def test_paid_grace_cloud_backup_is_read_only(self):
        backup_id = self.app.create_backup("user-a", make_envelope())
        self.app.entitlement_verifier = _DecisionEntitlementVerifier(
            PaidEntitlementState.GRACE,
        )

        key_status, key = self.request("GET", "/v1/account/backup-key", token="token-a")
        list_status, listed = self.request("GET", "/v1/backups", token="token-a")
        download_status, downloaded = self.request("GET", f"/v1/backups/{backup_id}", token="token-a")
        upload_status, upload_body = self.request(
            "POST",
            "/v1/backups",
            token="token-a",
            body=make_envelope(),
        )

        self.assertEqual(key_status, 200)
        self.assertEqual(len(key["backup_secret"]), 64)
        self.assertEqual(list_status, 200)
        self.assertEqual([item["backup_id"] for item in listed["backups"]], [backup_id])
        self.assertEqual(download_status, 200)
        self.assertEqual(downloaded["kind"], "cloud_backup")
        self.assertEqual(upload_status, 403)
        self.assertEqual(upload_body["error"]["code"], "entitlement_read_only")

    def test_http_entitlement_verifier_exception_is_unavailable(self):
        self.app.entitlement_verifier = _ExplodingEntitlementVerifier()

        status, body = self.request("GET", "/v1/backups", token="token-a")

        self.assertEqual(status, 503)
        self.assertEqual(body["error"]["code"], "subscription_verification_unavailable")

    def test_http_entitlement_unavailable_returns_503_without_leaking_account(self):
        self.app.entitlement_verifier = _UnavailableEntitlementVerifier()

        status, body = self.request("GET", "/v1/backups", token="token-a")

        self.assertEqual(status, 503)
        self.assertEqual(body["error"]["code"], "subscription_verification_unavailable")
        self.assertNotIn("user-a", json.dumps(body))

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

    def test_http_account_backup_key_is_authenticated_stable_and_scoped(self):
        status, body = self.request("GET", "/v1/account/backup-key")
        self.assertEqual(status, 401)
        self.assertEqual(body["error"]["code"], "unauthorized")

        status, first = self.request("GET", "/v1/account/backup-key", token="token-a")
        self.assertEqual(status, 200)
        secret = first["backup_secret"]
        self.assertIsInstance(secret, str)
        self.assertEqual(len(secret), 64)

        status, second = self.request("GET", "/v1/account/backup-key", token="token-a")
        self.assertEqual(status, 200)
        self.assertEqual(second["backup_secret"], secret)

        status, other = self.request("GET", "/v1/account/backup-key", token="token-b")
        self.assertEqual(status, 200)
        self.assertNotEqual(other["backup_secret"], secret)

    def test_http_account_backup_key_reports_unavailable_without_master_secret(self):
        app = BackupApp(
            metadata_store=BackupMetadataStore(f"{self.temp_dir.name}/no-key.sqlite3"),
            object_store=FileObjectStore(f"{self.temp_dir.name}/no-key-objects"),
            authenticator=Authenticator(dev_tokens={"token-a": "user-a"}),
            rate_limiter=SlidingWindowRateLimiter(max_requests=1000),
            account_key_secret="",
            entitlement_verifier=_MaxEntitlementVerifier(),
        )
        handler = _HandlerHarness(
            app,
            "/v1/account/backup-key",
            {"authorization": "Bearer token-a"},
            b"",
        )
        from app import BackupRequestHandler

        BackupRequestHandler._handle(handler, "GET")
        body = json.loads(handler.wfile.getvalue().decode("utf-8"))
        self.assertEqual(handler.status, 503)
        self.assertEqual(body["error"]["code"], "backup_key_unavailable")


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


class _MaxEntitlementVerifier:
    def require_max(self, user_id):
        return None


class _TierEntitlementVerifier:
    def __init__(self, tiers_by_user):
        self.tiers_by_user = dict(tiers_by_user)

    def require_max(self, user_id):
        if self.tiers_by_user.get(user_id) == "max":
            return None
        raise HttpError(
            403,
            "cloud_backup_requires_max",
            "Cloud backup requires Max subscription.",
        )


class _RecordingEntitlementVerifier:
    def __init__(self):
        self.user_ids = []

    def require_max(self, user_id):
        self.user_ids.append(user_id)


class _ExplodingEntitlementVerifier:
    def require_max(self, user_id):
        raise RuntimeError("simulated entitlement verifier failure")


class _UnavailableEntitlementVerifier:
    def require_max(self, user_id):
        raise HttpError(
            503,
            "subscription_verification_unavailable",
            "Subscription verification is currently unavailable.",
        )


class _DecisionEntitlementVerifier:
    def __init__(self, paid_state):
        self.paid_state = paid_state
        self.calls = []

    def require_max(self, user_id):
        if self.paid_state == PaidEntitlementState.ACTIVE:
            return None
        raise HttpError(
            403,
            "cloud_backup_requires_max",
            "Cloud backup requires Max subscription.",
        )

    def resolve_decision(self, user_id, *, request_type, operation, env):
        self.calls.append((user_id, request_type, operation, env))
        return EntitlementResolver(default_paid_state=self.paid_state).resolve(
            {"operation": operation},
            request_type=request_type,
            user_id=user_id,
            env=env,
        )


class _RawHttpResponse:
    def __init__(self, raw):
        self.raw = raw

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def read(self):
        return self.raw


class _HttpResponse(_RawHttpResponse):
    def __init__(self, body):
        super().__init__(json.dumps(body, separators=(",", ":")).encode("utf-8"))


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
    def __init__(self, clear=False, **updates):
        self.clear = clear
        self.updates = updates
        self.original = None

    def __enter__(self):
        self.original = os.environ.copy()
        if self.clear:
            os.environ.clear()
        os.environ.update(self.updates)

    def __exit__(self, exc_type, exc, tb):
        os.environ.clear()
        os.environ.update(self.original)
        return False


if __name__ == "__main__":
    unittest.main()
