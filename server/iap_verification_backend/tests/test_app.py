from __future__ import annotations

import io
import json
import os
import sqlite3
import sys
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from unittest import mock


BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

from app import (  # noqa: E402
    DEFAULT_ALLOWED_BUNDLE_ID,
    DEFAULT_ALLOWED_PRODUCTS,
    MAX_YEARLY_PRODUCT_ID,
    PRO_YEARLY_PRODUCT_ID,
    RESPONSE_FIELDS,
    VALID_ENTITLEMENT_TIERS,
    VALID_OUTCOMES,
    AppleServerApiVerifierPlaceholder,
    AppConfig,
    AppStoreServerAppleVerifier,
    EntitlementStore,
    IapVerificationApp,
    IapVerificationRequestHandler,
    RequestValidator,
)
from verifier import FakeAppleVerifier  # noqa: E402


PRO_TOKEN = "00000000-0000-4000-8000-000000000001"
MAX_TOKEN = "00000000-0000-4000-8000-000000000002"


class IapVerificationBackendTestCase(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.store = EntitlementStore(f"{self.temp_dir.name}/iap.sqlite3")
        self.app = IapVerificationApp(
            store=self.store,
            validator=RequestValidator(DEFAULT_ALLOWED_PRODUCTS, DEFAULT_ALLOWED_BUNDLE_ID),
            verifier=FakeAppleVerifier(),
            max_request_bytes=64 * 1024,
        )

    def tearDown(self):
        self.temp_dir.cleanup()

    def request(self, method, path, body=None, app=None):
        data = b""
        headers = {}
        if body is not None:
            data = json.dumps(body, separators=(",", ":")).encode("utf-8")
            headers["content-type"] = "application/json"
            headers["content-length"] = str(len(data))
        handler = _HandlerHarness(app or self.app, path, headers, data)
        IapVerificationRequestHandler._handle(handler, method)
        raw = handler.wfile.getvalue().decode("utf-8")
        return handler.status, json.loads(raw) if raw else {}

    def verify_purchase(self, fake_token, app_account_token=PRO_TOKEN, product_id=PRO_YEARLY_PRODUCT_ID):
        return self.request(
            "POST",
            "/iap/apple/verify-purchase",
            body=purchase_body(
                fake_token=fake_token,
                app_account_token=app_account_token,
                product_id=product_id,
            ),
        )

    def assert_contract_response(self, body, outcome, tier):
        self.assertLessEqual(set(body.keys()), RESPONSE_FIELDS)
        self.assertIn(body["outcome"], VALID_OUTCOMES)
        self.assertIn(body["entitlementTier"], VALID_ENTITLEMENT_TIERS)
        self.assertEqual(body["outcome"], outcome)
        self.assertEqual(body["entitlementTier"], tier)

    def assert_current_entitlement(self, app_account_token, outcome, tier):
        status, body = self.request(
            "GET",
            f"/iap/apple/current-entitlement?appAccountToken={app_account_token}",
        )
        self.assertEqual(status, 200)
        self.assert_contract_response(body, outcome, tier)
        return body

    def test_healthz_is_unauthenticated(self):
        status, body = self.request("GET", "/healthz")

        self.assertEqual(status, 200)
        self.assertEqual(body, {"ok": True})

    def test_pro_active_purchase_persists_current_entitlement(self):
        status, body = self.verify_purchase("fake:pro-active")

        self.assertEqual(status, 200)
        self.assert_contract_response(body, "verifiedActivePro", "pro")
        self.assertEqual(body["productId"], PRO_YEARLY_PRODUCT_ID)
        self.assertEqual(body["appAccountToken"], PRO_TOKEN)
        self.assertEqual(body["environment"], "Sandbox")
        self.assertIn("originalTransactionId", body)
        self.assertIn("expiresAt", body)
        current = self.assert_current_entitlement(PRO_TOKEN, "verifiedActivePro", "pro")
        self.assertEqual(current["originalTransactionId"], body["originalTransactionId"])

    def test_max_active_purchase_persists_current_entitlement(self):
        status, body = self.verify_purchase(
            "fake:max-active",
            app_account_token=MAX_TOKEN,
            product_id=MAX_YEARLY_PRODUCT_ID,
        )

        self.assertEqual(status, 200)
        self.assert_contract_response(body, "verifiedActiveMax", "max")
        self.assertEqual(body["productId"], MAX_YEARLY_PRODUCT_ID)
        self.assert_current_entitlement(MAX_TOKEN, "verifiedActiveMax", "max")

    def test_pro_grace_period_purchase_maps_to_pro(self):
        status, body = self.verify_purchase("fake:pro-grace")

        self.assertEqual(status, 200)
        self.assert_contract_response(body, "verifiedGracePeriodPro", "pro")
        self.assert_current_entitlement(PRO_TOKEN, "verifiedGracePeriodPro", "pro")

    def test_max_grace_period_purchase_maps_to_max(self):
        status, body = self.verify_purchase(
            "fake:max-grace",
            app_account_token=MAX_TOKEN,
            product_id=MAX_YEARLY_PRODUCT_ID,
        )

        self.assertEqual(status, 200)
        self.assert_contract_response(body, "verifiedGracePeriodMax", "max")
        self.assert_current_entitlement(MAX_TOKEN, "verifiedGracePeriodMax", "max")

    def test_billing_retry_does_not_unlock(self):
        status, body = self.verify_purchase("fake:billing-retry")

        self.assertEqual(status, 200)
        self.assert_contract_response(body, "billingRetry", "none")
        self.assert_current_entitlement(PRO_TOKEN, "billingRetry", "none")

    def test_expired_purchase_does_not_unlock(self):
        status, body = self.verify_purchase("fake:expired")

        self.assertEqual(status, 200)
        self.assert_contract_response(body, "expired", "none")
        self.assert_current_entitlement(PRO_TOKEN, "expired", "none")

    def test_revoked_purchase_does_not_unlock(self):
        status, body = self.verify_purchase("fake:revoked")

        self.assertEqual(status, 200)
        self.assert_contract_response(body, "revoked", "none")
        self.assertNotIn("revokedAt", body)
        self.assert_current_entitlement(PRO_TOKEN, "revoked", "none")

    def test_invalid_purchase_returns_verification_failed(self):
        status, body = self.verify_purchase("fake:invalid")

        self.assertEqual(status, 200)
        self.assert_contract_response(body, "verificationFailed", "none")
        self.assert_current_entitlement(PRO_TOKEN, "verificationFailed", "none")

    def test_missing_token_is_rejected_without_entitlement_body(self):
        status, body = self.request("GET", "/iap/apple/current-entitlement")

        self.assertEqual(status, 400)
        self.assertEqual(body["error"]["code"], "missing_app_account_token")
        self.assertNotIn("outcome", body)
        self.assertNotIn("entitlementTier", body)

    def test_unknown_token_returns_no_active_entitlement(self):
        unknown_token = "00000000-0000-4000-8000-000000000099"

        status, body = self.request(
            "GET",
            f"/iap/apple/current-entitlement?appAccountToken={unknown_token}",
        )

        self.assertEqual(status, 200)
        self.assert_contract_response(body, "noActiveEntitlement", "none")
        self.assertEqual(body["appAccountToken"], unknown_token)
        self.assertNotIn("productId", body)

    def test_apple_outage_returns_verification_unavailable_without_persisting(self):
        outage_token = "00000000-0000-4000-8000-000000000123"

        status, body = self.verify_purchase("fake:outage", app_account_token=outage_token)

        self.assertEqual(status, 200)
        self.assert_contract_response(body, "verificationUnavailable", "none")
        self.assertIsNone(self.store.get_entitlement(outage_token))
        self.assert_current_entitlement(outage_token, "noActiveEntitlement", "none")

    def test_from_env_without_apple_credentials_fail_closes_even_for_fake_active_token(self):
        app_account_token = "00000000-0000-4000-8000-000000000321"
        db_path = f"{self.temp_dir.name}/from-env.sqlite3"
        with _patched_env(FLEET_IAP_DB_PATH=db_path):
            production_app = IapVerificationApp.from_env()

        self.assertIsInstance(production_app.verifier, AppleServerApiVerifierPlaceholder)
        status, body = self.request(
            "POST",
            "/iap/apple/verify-purchase",
            body=purchase_body(
                fake_token="fake:pro-active",
                app_account_token=app_account_token,
            ),
            app=production_app,
        )

        self.assertEqual(status, 200)
        self.assert_contract_response(body, "verificationUnavailable", "none")
        self.assertEqual(body["appAccountToken"], app_account_token)
        self.assertIsNone(production_app.store.get_entitlement(app_account_token))

        status, current = self.request(
            "GET",
            f"/iap/apple/current-entitlement?appAccountToken={app_account_token}",
            app=production_app,
        )
        self.assertEqual(status, 200)
        self.assert_contract_response(current, "noActiveEntitlement", "none")

    def test_from_env_with_complete_apple_credentials_uses_real_verifier(self):
        key_path = f"{self.temp_dir.name}/AuthKey_TEST.p8"
        cert_path = f"{self.temp_dir.name}/AppleRootCA-G3.cer"
        with open(key_path, "wb") as key_file:
            key_file.write(b"fake-private-key-for-construction-only")
        with open(cert_path, "wb") as cert_file:
            cert_file.write(b"fake-root-cert-for-construction-only")

        with _patched_env(
            FLEET_IAP_DB_PATH=f"{self.temp_dir.name}/real-from-env.sqlite3",
            FLEET_IAP_APPLE_KEY_ID="TESTKEY123",
            FLEET_IAP_APPLE_ISSUER_ID="00000000-0000-0000-0000-000000000000",
            FLEET_IAP_APPLE_PRIVATE_KEY_PATH=key_path,
            FLEET_IAP_APPLE_BUNDLE_ID=DEFAULT_ALLOWED_BUNDLE_ID,
            FLEET_IAP_APPLE_ROOT_CERTIFICATE_PATHS=cert_path,
            FLEET_IAP_APPLE_APP_APPLE_ID="1234567890",
        ):
            production_app = IapVerificationApp.from_env()

        self.assertIsInstance(production_app.verifier, AppStoreServerAppleVerifier)

    def test_unknown_product_is_rejected(self):
        status, body = self.request(
            "POST",
            "/iap/apple/verify-purchase",
            body=purchase_body(
                fake_token="fake:pro-active",
                product_id="com.yuyuan.assetledger.legacy.monthly",
            ),
        )

        self.assertEqual(status, 400)
        self.assertEqual(body["error"]["code"], "unknown_product")

    def test_response_never_contains_fields_outside_contract(self):
        scenarios = [
            ("fake:pro-active", PRO_YEARLY_PRODUCT_ID, "verifiedActivePro", "pro"),
            ("fake:max-active", MAX_YEARLY_PRODUCT_ID, "verifiedActiveMax", "max"),
            ("fake:pro-grace", PRO_YEARLY_PRODUCT_ID, "verifiedGracePeriodPro", "pro"),
            ("fake:max-grace", MAX_YEARLY_PRODUCT_ID, "verifiedGracePeriodMax", "max"),
            ("fake:billing-retry", PRO_YEARLY_PRODUCT_ID, "billingRetry", "none"),
            ("fake:expired", PRO_YEARLY_PRODUCT_ID, "expired", "none"),
            ("fake:revoked", PRO_YEARLY_PRODUCT_ID, "revoked", "none"),
            ("fake:invalid", PRO_YEARLY_PRODUCT_ID, "verificationFailed", "none"),
            ("fake:outage", PRO_YEARLY_PRODUCT_ID, "verificationUnavailable", "none"),
        ]
        for index, (fake_token, product_id, outcome, tier) in enumerate(scenarios, start=1):
            app_account_token = f"00000000-0000-4000-8000-{index:012d}"
            with self.subTest(fake_token=fake_token):
                status, body = self.verify_purchase(fake_token, app_account_token, product_id)
                self.assertEqual(status, 200)
                self.assert_contract_response(body, outcome, tier)

        status, body = self.request(
            "GET",
            "/iap/apple/current-entitlement?appAccountToken=00000000-0000-4000-8000-000000000999",
        )
        self.assertEqual(status, 200)
        self.assert_contract_response(body, "noActiveEntitlement", "none")

    def test_storage_schema_contains_contract_fields(self):
        with closing(sqlite3.connect(self.store.db_path)) as conn:
            rows = conn.execute("PRAGMA table_info(iap_entitlements)").fetchall()

        columns = {row[1] for row in rows}
        self.assertEqual(
            columns,
            {
                "app_account_token",
                "entitlement_tier",
                "original_transaction_id",
                "latest_transaction_id",
                "product_id",
                "environment",
                "expires_at",
                "revoked_at",
                "outcome",
                "updated_at",
            },
        )

    def test_app_config_reads_env_without_secret_defaults(self):
        with _patched_env(
            FLEET_IAP_PORT="9011",
            FLEET_IAP_DB_PATH="/tmp/fleet-iap.sqlite3",
            FLEET_IAP_ALLOWED_BUNDLE_ID="com.example.test",
            FLEET_IAP_ALLOWED_PRODUCTS=f"{PRO_YEARLY_PRODUCT_ID},{MAX_YEARLY_PRODUCT_ID}",
            FLEET_IAP_MAX_REQUEST_BYTES="4096",
            FLEET_IAP_APPLE_REQUEST_TIMEOUT_SECONDS="7",
        ):
            config = AppConfig.from_env()

        self.assertEqual(config.port, 9011)
        self.assertEqual(config.database_path, "/tmp/fleet-iap.sqlite3")
        self.assertEqual(config.allowed_bundle_id, "com.example.test")
        self.assertEqual(config.allowed_products, (PRO_YEARLY_PRODUCT_ID, MAX_YEARLY_PRODUCT_ID))
        self.assertEqual(config.max_request_bytes, 4096)
        self.assertEqual(config.apple_request_timeout_seconds, 7)
        self.assertFalse(config.apple_credentials.is_complete)
        self.assertIsNone(config.apple_credentials.key_id)
        self.assertEqual(config.apple_credentials.root_certificate_paths, ())
        self.assertIsNone(config.apple_credentials.app_apple_id)

    def test_app_config_rejects_products_outside_contract_allowlist(self):
        with _patched_env(
            FLEET_IAP_ALLOWED_PRODUCTS=f"{PRO_YEARLY_PRODUCT_ID},com.yuyuan.assetledger.legacy.monthly",
        ):
            with self.assertRaises(ValueError):
                AppConfig.from_env()

    def test_main_configures_logging_before_serving(self):
        calls = []

        class FakeServer:
            server_address = ("127.0.0.1", 8010)

            def serve_forever(self):
                calls.append("serve")

        with (
            mock.patch("app.configure_logging", side_effect=lambda: calls.append("logging")),
            mock.patch("app.build_server_from_env", side_effect=lambda: calls.append("build") or FakeServer()),
            mock.patch("sys.stdout", new=io.StringIO()),
        ):
            from app import main

            main()

        self.assertEqual(calls, ["logging", "build", "serve"])


def purchase_body(
    fake_token,
    app_account_token=PRO_TOKEN,
    product_id=PRO_YEARLY_PRODUCT_ID,
):
    return {
        "platform": "ios",
        "productId": product_id,
        "purchaseId": "2000000000000000",
        "transactionDate": "1700000000000",
        "serverVerificationData": fake_token,
        "localVerificationData": "fake:local",
        "source": "app_store",
        "status": "purchased",
        "appAccountToken": app_account_token,
        "bundleId": DEFAULT_ALLOWED_BUNDLE_ID,
    }


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
        os.environ.clear()
        os.environ.update(self.updates)

    def __exit__(self, exc_type, exc, tb):
        os.environ.clear()
        os.environ.update(self.original)
        return False


if __name__ == "__main__":
    unittest.main()
