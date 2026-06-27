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
    AccountIdentityResolver,
    AuthPlane,
    ConfigMigrationError,
    DEFAULT_ALLOWED_BUNDLE_ID,
    DEFAULT_ALLOWED_PRODUCTS,
    ENTITLEMENT_CHANGE_LOG,
    ENTITLEMENT_BINDING_POLICIES,
    EXTERNAL_CLIENT_TOKEN_REQUIRED,
    GOOGLE_PLAY_CHANNEL,
    HUAWEI_CHANNEL,
    MAX_YEARLY_PRODUCT_ID,
    OPPO_CHANNEL,
    PRO_YEARLY_PRODUCT_ID,
    PROCESSED_EVENT_LOG,
    ProviderSubscriptionState,
    RESPONSE_FIELDS,
    RAW_EVENT_LOG,
    STATE_ACTIVE,
    STATE_EXPIRED,
    STATE_GRACE,
    VIVO_CHANNEL,
    VALID_ENTITLEMENT_TIERS,
    VALID_OUTCOMES,
    XIAOMI_CHANNEL,
    AppleServerApiVerifierPlaceholder,
    AppConfig,
    AppStoreServerAppleVerifier,
    Authenticator,
    EntitlementEngine,
    EntitlementStore,
    EntitlementRecord,
    EntitlementBindingPolicy,
    HttpError,
    IapVerificationApp,
    PurchaseEvent,
    IapVerificationRequestHandler,
    RequestValidator,
    SecurityViolation,
    SubscriptionReconciliationWorker,
    signature_for_payload,
)
from handlers import redact_app_account_token_values  # noqa: E402
from verifier import AppleVerificationFailed, FakeAppleVerifier  # noqa: E402


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

    def request(self, method, path, body=None, app=None, headers=None):
        data = b""
        headers = dict(headers or {})
        if body is not None:
            data = json.dumps(body, separators=(",", ":")).encode("utf-8")
            headers["content-type"] = "application/json"
            headers["content-length"] = str(len(data))
        handler = _HandlerHarness(app or self.app, path, headers, data)
        IapVerificationRequestHandler._handle(handler, method)
        raw = handler.wfile.getvalue().decode("utf-8")
        return handler.status, json.loads(raw) if raw else {}

    def verify_purchase(
        self,
        fake_token,
        app_account_token=PRO_TOKEN,
        product_id=PRO_YEARLY_PRODUCT_ID,
        app=None,
        authorization=None,
    ):
        headers = {}
        if authorization is not None:
            headers["Authorization"] = authorization
        return self.request(
            "POST",
            "/iap/apple/verify-purchase",
            body=purchase_body(
                fake_token=fake_token,
                app_account_token=app_account_token,
                product_id=product_id,
            ),
            app=app,
            headers=headers,
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

    def _app_with_authenticator(self, **kwargs):
        return IapVerificationApp(
            store=kwargs.get("store", self.store),
            validator=RequestValidator(DEFAULT_ALLOWED_PRODUCTS, DEFAULT_ALLOWED_BUNDLE_ID),
            verifier=kwargs.get("verifier", FakeAppleVerifier()),
            max_request_bytes=64 * 1024,
            authenticator=Authenticator(
                dev_tokens={
                    "login-token-a": "user-a",
                    "login-token-b": "user-b",
                    "login-token-pro": "user-pro",
                    "login-token-max": "user-max",
                    "login-token-expired": "user-expired",
                }
            ),
            internal_entitlement_token=kwargs.get("internal_entitlement_token"),
        )

    def _app_with_gateway(self, **kwargs):
        return IapVerificationApp(
            store=kwargs.get("store", self.store),
            validator=RequestValidator(DEFAULT_ALLOWED_PRODUCTS, DEFAULT_ALLOWED_BUNDLE_ID),
            verifier=kwargs.get("verifier", FakeAppleVerifier()),
            max_request_bytes=64 * 1024,
            authenticator=Authenticator(
                dev_tokens={
                    "login-token-a": "user-a",
                    "login-token-max": "user-max",
                }
            ),
            internal_entitlement_token=kwargs.get("internal_entitlement_token"),
            channel_signature_secrets=kwargs.get(
                "channel_signature_secrets",
                gateway_secrets(),
            ),
        )

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

    def test_verify_purchase_without_authorization_keeps_user_id_null(self):
        status, _ = self.verify_purchase("fake:max-active", MAX_TOKEN, MAX_YEARLY_PRODUCT_ID)

        self.assertEqual(status, 200)
        record = self.store.get_entitlement(MAX_TOKEN)
        self.assertIsNotNone(record)
        self.assertIsNone(record.user_id)

    def test_verify_purchase_with_valid_authorization_binds_user_id(self):
        app = self._app_with_authenticator()

        status, body = self.verify_purchase(
            "fake:max-active",
            MAX_TOKEN,
            MAX_YEARLY_PRODUCT_ID,
            app=app,
            authorization="Bearer login-token-a",
        )

        self.assertEqual(status, 200)
        self.assert_contract_response(body, "verifiedActiveMax", "max")
        record = app.store.get_entitlement(MAX_TOKEN)
        self.assertEqual(record.user_id, "user-a")

    def test_account_identity_resolver_keeps_user_id_stable_across_calls_and_refresh(self):
        authenticator = Authenticator(
            dev_tokens={
                "login-token-a-v1": "user-a",
                "login-token-a-v2": "user-a",
            }
        )

        self.assertEqual(authenticator.authenticate("Bearer login-token-a-v1"), "user-a")
        self.assertEqual(authenticator.authenticate("Bearer login-token-a-v1"), "user-a")
        self.assertEqual(authenticator.authenticate("Bearer login-token-a-v2"), "user-a")
        self.assertEqual(authenticator.auth_plane, AuthPlane.USER)

    def test_account_identity_resolver_does_not_cache_invalid_tokens(self):
        calls = []

        def inactive(token):
            calls.append(token)
            raise HttpError(401, "invalid_token", "token is not accepted")

        authenticator = Authenticator(introspector=inactive)

        with self.assertRaises(HttpError):
            authenticator.authenticate("Bearer invalid-token")
        with self.assertRaises(HttpError):
            authenticator.authenticate("Bearer invalid-token")
        self.assertEqual(calls, ["invalid-token", "invalid-token"])

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

    def test_verify_purchase_with_invalid_authorization_returns_401_without_binding(self):
        app = self._app_with_authenticator()

        status, body = self.verify_purchase(
            "fake:max-active",
            MAX_TOKEN,
            MAX_YEARLY_PRODUCT_ID,
            app=app,
            authorization="Bearer unknown-token",
        )

        self.assertEqual(status, 401)
        self.assertEqual(body["error"]["code"], "unauthorized")
        self.assertIsNone(app.store.get_entitlement(MAX_TOKEN))

    def test_verification_failed_purchase_does_not_bind_user_id(self):
        app = self._app_with_authenticator()
        token = "00000000-0000-4000-8000-000000000100"

        status, body = self.verify_purchase(
            "fake:invalid",
            token,
            PRO_YEARLY_PRODUCT_ID,
            app=app,
            authorization="Bearer login-token-pro",
        )

        self.assertEqual(status, 200)
        self.assert_contract_response(body, "verificationFailed", "none")
        record = app.store.get_entitlement(token)
        self.assertIsNotNone(record)
        self.assertIsNone(record.user_id)

    def test_original_transaction_claim_can_refresh_same_user(self):
        app = self._app_with_authenticator(verifier=FixedOriginalVerifier())

        first_status, first_body = self.verify_purchase(
            "fixed:max-active",
            MAX_TOKEN,
            MAX_YEARLY_PRODUCT_ID,
            app=app,
            authorization="Bearer login-token-a",
        )
        second_status, second_body = self.verify_purchase(
            "fixed:max-grace",
            MAX_TOKEN,
            MAX_YEARLY_PRODUCT_ID,
            app=app,
            authorization="Bearer login-token-a",
        )

        self.assertEqual(first_status, 200)
        self.assertEqual(second_status, 200)
        self.assertEqual(first_body["originalTransactionId"], second_body["originalTransactionId"])
        self.assertEqual(app.store.get_entitlement(MAX_TOKEN).user_id, "user-a")

    def test_original_transaction_claim_rejects_other_user(self):
        app = self._app_with_authenticator(verifier=FixedOriginalVerifier())
        first_status, _ = self.verify_purchase(
            "fixed:max-active",
            MAX_TOKEN,
            MAX_YEARLY_PRODUCT_ID,
            app=app,
            authorization="Bearer login-token-a",
        )

        second_status, body = self.verify_purchase(
            "fixed:max-grace",
            MAX_TOKEN,
            MAX_YEARLY_PRODUCT_ID,
            app=app,
            authorization="Bearer login-token-b",
        )

        self.assertEqual(first_status, 200)
        self.assertEqual(second_status, 409)
        self.assertEqual(body["error"]["code"], "subscription_bound_to_other_user")
        self.assertEqual(app.store.get_entitlement(MAX_TOKEN).user_id, "user-a")

    def test_existing_app_account_token_binding_rejects_other_user(self):
        app = self._app_with_authenticator(verifier=FixedOriginalVerifier())
        first_status, _ = self.verify_purchase(
            "fixed:max-active",
            MAX_TOKEN,
            MAX_YEARLY_PRODUCT_ID,
            app=app,
            authorization="Bearer login-token-a",
        )

        second_status, body = self.verify_purchase(
            "fixed:max-grace",
            MAX_TOKEN,
            MAX_YEARLY_PRODUCT_ID,
            app=app,
            authorization="Bearer login-token-b",
        )

        self.assertEqual(first_status, 200)
        self.assertEqual(second_status, 409)
        self.assertEqual(body["error"]["code"], "subscription_bound_to_other_user")
        self.assertEqual(app.store.get_entitlement(MAX_TOKEN).user_id, "user-a")

    def test_fallback_transaction_user_id_cannot_overwrite_existing_binding(self):
        app = self._app_with_authenticator(verifier=FallbackUserVerifier("user-b"))
        first_status, _ = self.verify_purchase(
            "fake:max-active",
            MAX_TOKEN,
            MAX_YEARLY_PRODUCT_ID,
            app=app,
            authorization="Bearer login-token-a",
        )
        second_status, body = self.verify_purchase(
            "fake:max-active",
            MAX_TOKEN,
            MAX_YEARLY_PRODUCT_ID,
            app=app,
        )

        self.assertEqual(first_status, 200)
        self.assertEqual(second_status, 200)
        self.assert_contract_response(body, "verifiedActiveMax", "max")
        self.assertEqual(app.store.get_entitlement(MAX_TOKEN).user_id, "user-a")

    def test_apple_mismatch_fallback_user_id_must_not_bind(self):
        app = IapVerificationApp(
            store=self.store,
            validator=RequestValidator(DEFAULT_ALLOWED_PRODUCTS, DEFAULT_ALLOWED_BUNDLE_ID),
            verifier=FallbackUserVerifier("user-from-transaction-token"),
            max_request_bytes=64 * 1024,
        )

        status, body = self.verify_purchase(
            "fake:max-active",
            MAX_TOKEN,
            MAX_YEARLY_PRODUCT_ID,
            app=app,
        )

        self.assertEqual(status, 200)
        self.assert_contract_response(body, "verifiedActiveMax", "max")
        self.assertIsNone(app.store.get_entitlement(MAX_TOKEN).user_id)

    def test_failed_purchase_log_is_redacted_and_includes_reason(self):
        with self.assertLogs("fleet_ledger.iap_verification", level="INFO") as logs:
            status, body = self.verify_purchase("fake:invalid")

        self.assertEqual(status, 200)
        self.assert_contract_response(body, "verificationFailed", "none")
        log_output = "\n".join(logs.output)
        self.assertIn('"reason":"fake invalid purchase"', log_output)
        self.assertIn('"has_app_account_token":true', log_output)
        self.assertIn('"server_verification_data_format":"non_jws"', log_output)
        self.assertNotIn(PRO_TOKEN, log_output)

    def test_failed_purchase_log_includes_redacted_apple_verification_diagnostics(self):
        app = IapVerificationApp(
            store=self.store,
            validator=RequestValidator(DEFAULT_ALLOWED_PRODUCTS, DEFAULT_ALLOWED_BUNDLE_ID),
            verifier=DiagnosticFailureVerifier(),
            max_request_bytes=64 * 1024,
        )

        with self.assertLogs("fleet_ledger.iap_verification", level="INFO") as logs:
            status, body = self.request(
                "POST",
                "/iap/apple/verify-purchase",
                body=purchase_body(
                    fake_token="header.payload.signature",
                    app_account_token=PRO_TOKEN,
                ),
                app=app,
            )

        self.assertEqual(status, 200)
        self.assert_contract_response(body, "verificationFailed", "none")
        log_output = "\n".join(logs.output)
        self.assertIn('"server_verification_data_format":"jws"', log_output)
        self.assertIn('"apple_verification_status":"INVALID_CHAIN"', log_output)
        self.assertIn('"apple_verification_statuses":"Sandbox:INVALID_CHAIN,Production:INVALID_ENVIRONMENT"', log_output)
        self.assertNotIn(PRO_TOKEN, log_output)

    def test_access_log_redacts_app_account_token_query_value(self):
        message = redact_app_account_token_values(
            f'"GET /iap/apple/current-entitlement?appAccountToken={PRO_TOKEN} HTTP/1.1" 200 -'
        )

        self.assertIn("appAccountToken=<redacted>", message)
        self.assertNotIn(PRO_TOKEN, message)

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

    def test_internal_entitlement_endpoint_requires_server_token(self):
        app = self._app_with_authenticator(internal_entitlement_token="internal-token")
        body = internal_entitlement_body("user-a")

        missing_status, missing_body = self.request(
            "POST",
            "/internal/v1/entitlements/verify",
            body=body,
            app=app,
        )
        wrong_status, wrong_body = self.request(
            "POST",
            "/internal/v1/entitlements/verify",
            body=body,
            app=app,
            headers={"Authorization": "Bearer wrong-token"},
        )

        self.assertEqual(missing_status, 401)
        self.assertEqual(missing_body["error"]["code"], "unauthorized")
        self.assertEqual(wrong_status, 401)
        self.assertEqual(wrong_body["error"]["code"], "unauthorized")
        self.assertEqual(app.internal_entitlement_auth_plane, AuthPlane.SERVICE)

    def test_user_auth_token_cannot_access_internal_entitlement_endpoint(self):
        app = self._app_with_authenticator(internal_entitlement_token="service-token")

        status, body = self.request(
            "POST",
            "/internal/v1/entitlements/verify",
            body=internal_entitlement_body("user-a"),
            app=app,
            headers={"Authorization": "Bearer login-token-a"},
        )

        self.assertEqual(status, 401)
        self.assertEqual(body["error"]["code"], "unauthorized")

    def test_service_internal_token_cannot_bind_purchase_as_user_auth(self):
        app = self._app_with_authenticator(internal_entitlement_token="service-token")

        status, body = self.verify_purchase(
            "fake:max-active",
            MAX_TOKEN,
            MAX_YEARLY_PRODUCT_ID,
            app=app,
            authorization="Bearer service-token",
        )

        self.assertEqual(status, 401)
        self.assertEqual(body["error"]["code"], "unauthorized")
        self.assertIsNone(app.store.get_entitlement(MAX_TOKEN))

    def test_external_client_token_cannot_bind_or_override_entitlement(self):
        app = self._app_with_authenticator(verifier=FixedOriginalVerifier())
        first_status, _ = self.verify_purchase(
            "fixed:max-active",
            MAX_TOKEN,
            MAX_YEARLY_PRODUCT_ID,
            app=app,
            authorization="Bearer login-token-a",
        )

        second_status, body = self.verify_purchase(
            "fixed:max-grace",
            MAX_TOKEN,
            MAX_YEARLY_PRODUCT_ID,
            app=app,
            authorization="Bearer external-client-token",
        )

        self.assertEqual(first_status, 200)
        self.assertEqual(second_status, 401)
        self.assertEqual(body["error"]["code"], "unauthorized")
        self.assertEqual(app.store.get_entitlement(MAX_TOKEN).user_id, "user-a")

    def test_internal_entitlement_endpoint_validates_body(self):
        app = self._app_with_authenticator(internal_entitlement_token="internal-token")
        headers = {"Authorization": "Bearer internal-token"}

        malformed_status, malformed_body = self.request(
            "POST",
            "/internal/v1/entitlements/verify",
            body=["not-an-object"],
            app=app,
            headers=headers,
        )
        missing_status, missing_body = self.request(
            "POST",
            "/internal/v1/entitlements/verify",
            body={
                "required_capability": "cloud_backup",
                "required_plan": "max",
            },
            app=app,
            headers=headers,
        )
        bad_capability_status, bad_capability_body = self.request(
            "POST",
            "/internal/v1/entitlements/verify",
            body=internal_entitlement_body("user-a", required_capability="sync"),
            app=app,
            headers=headers,
        )
        bad_plan_status, bad_plan_body = self.request(
            "POST",
            "/internal/v1/entitlements/verify",
            body=internal_entitlement_body("user-a", required_plan="pro"),
            app=app,
            headers=headers,
        )

        self.assertEqual(malformed_status, 400)
        self.assertEqual(malformed_body["error"]["code"], "invalid_json")
        self.assertEqual(missing_status, 400)
        self.assertEqual(missing_body["error"]["code"], "invalid_request")
        self.assertEqual(bad_capability_status, 400)
        self.assertEqual(bad_capability_body["error"]["code"], "invalid_required_capability")
        self.assertEqual(bad_plan_status, 400)
        self.assertEqual(bad_plan_body["error"]["code"], "invalid_required_plan")

    def test_internal_entitlement_allows_active_and_grace_max_by_user_id(self):
        app = self._app_with_authenticator(internal_entitlement_token="internal-token")
        max_active_token = "00000000-0000-4000-8000-000000000201"
        max_grace_token = "00000000-0000-4000-8000-000000000202"
        self.verify_purchase(
            "fake:max-active",
            max_active_token,
            MAX_YEARLY_PRODUCT_ID,
            app=app,
            authorization="Bearer login-token-max",
        )
        self.verify_purchase(
            "fake:max-grace",
            max_grace_token,
            MAX_YEARLY_PRODUCT_ID,
            app=app,
            authorization="Bearer login-token-a",
        )

        active_status, active_body = self.request(
            "POST",
            "/internal/v1/entitlements/verify",
            body=internal_entitlement_body("user-max"),
            app=app,
            headers={"Authorization": "Bearer internal-token"},
        )
        grace_status, grace_body = self.request(
            "POST",
            "/internal/v1/entitlements/verify",
            body=internal_entitlement_body("user-a"),
            app=app,
            headers={"Authorization": "Bearer internal-token"},
        )

        self.assertEqual(active_status, 200)
        self.assertEqual(active_body["allowed"], True)
        self.assertEqual(active_body["entitlementTier"], "max")
        self.assertEqual(active_body["entitlementActive"], True)
        self.assertEqual(grace_status, 200)
        self.assertEqual(grace_body["allowed"], True)
        self.assertEqual(grace_body["entitlementTier"], "max")
        self.assertEqual(grace_body["entitlementActive"], True)

    def test_internal_entitlement_prefers_user_max_over_newer_non_max_records(self):
        app = self._app_with_authenticator(internal_entitlement_token="internal-token")
        max_active_token = "00000000-0000-4000-8000-000000000211"
        pro_active_token = "00000000-0000-4000-8000-000000000212"
        failed_max_token = "00000000-0000-4000-8000-000000000213"
        self.verify_purchase(
            "fake:max-active",
            max_active_token,
            MAX_YEARLY_PRODUCT_ID,
            app=app,
            authorization="Bearer login-token-max",
        )
        self.verify_purchase(
            "fake:pro-active",
            pro_active_token,
            PRO_YEARLY_PRODUCT_ID,
            app=app,
            authorization="Bearer login-token-max",
        )
        self.verify_purchase(
            "fake:invalid",
            failed_max_token,
            MAX_YEARLY_PRODUCT_ID,
            app=app,
            authorization="Bearer login-token-max",
        )

        status, body = self.request(
            "POST",
            "/internal/v1/entitlements/verify",
            body=internal_entitlement_body("user-max"),
            app=app,
            headers={"Authorization": "Bearer internal-token"},
        )

        self.assertEqual(status, 200)
        self.assertEqual(body["allowed"], True)
        self.assertEqual(body["entitlementTier"], "max")
        self.assertEqual(body["entitlementActive"], True)

    def test_internal_entitlement_rejects_pro_expired_unbound_and_spoofed_tier(self):
        app = self._app_with_authenticator(internal_entitlement_token="internal-token")
        pro_token = "00000000-0000-4000-8000-000000000301"
        expired_max_token = "00000000-0000-4000-8000-000000000302"
        unbound_max_token = "00000000-0000-4000-8000-000000000303"
        self.verify_purchase(
            "fake:pro-active",
            pro_token,
            PRO_YEARLY_PRODUCT_ID,
            app=app,
            authorization="Bearer login-token-pro",
        )
        app.store.upsert_entitlement(
            EntitlementRecord(
                outcome="expired",
                entitlement_tier="none",
                product_id=MAX_YEARLY_PRODUCT_ID,
                app_account_token=expired_max_token,
                original_transaction_id="max-expired-original-1",
                latest_transaction_id="max-expired-latest-1",
                environment="Sandbox",
                expires_at="2020-01-01T00:00:00.000Z",
            ),
            user_id="user-expired",
        )
        self.verify_purchase(
            "fake:max-active",
            unbound_max_token,
            MAX_YEARLY_PRODUCT_ID,
            app=app,
        )

        cases = [
            ("user-pro", "pro", "active"),
            ("user-expired", "max", "expired"),
            ("unknown-user", "none", "none"),
        ]
        for user_id, tier, status in cases:
            with self.subTest(user_id=user_id):
                response_status, response_body = self.request(
                    "POST",
                    "/internal/v1/entitlements/verify",
                    body={
                        **internal_entitlement_body(user_id),
                        "plan": "max",
                    },
                    app=app,
                    headers={
                        "Authorization": "Bearer internal-token",
                        "X-Subscription-Tier": "max",
                    },
                )

                self.assertEqual(response_status, 200)
                self.assertEqual(response_body["allowed"], False)
                self.assertEqual(response_body["entitlementTier"], tier)
                self.assertEqual(response_body["entitlementActive"], False)
                self.assertEqual(response_body["status"], status)
                self.assertEqual(response_body["reason"], "requires_max")

    def test_gateway_apple_max_success_reuses_existing_ios_verifier(self):
        app = self._app_with_gateway()

        status, body = self.request(
            "POST",
            "/iap/gateway/apple/purchase",
            body=purchase_body(
                fake_token="fake:max-active",
                app_account_token=MAX_TOKEN,
                product_id=MAX_YEARLY_PRODUCT_ID,
            ),
            app=app,
            headers={"Authorization": "Bearer login-token-max"},
        )

        self.assertEqual(status, 200)
        self.assertEqual(body["gatewayStatus"], "applied")
        self.assertEqual(body["entitlement"]["outcome"], "verifiedActiveMax")
        self.assertEqual(body["entitlement"]["entitlementTier"], "max")
        self.assertEqual(body["event"]["userId"], "user-max")
        self.assertEqual(app.store.get_entitlement(MAX_TOKEN).user_id, "user-max")

    def test_gateway_google_pro_success(self):
        app = self._app_with_gateway()

        status, body = self.request(
            "POST",
            "/iap/webhooks/google_play",
            body=gateway_body(
                GOOGLE_PLAY_CHANNEL,
                user_id="user-google",
                product_id=PRO_YEARLY_PRODUCT_ID,
                transaction_id="google-tx-1",
            ),
            app=app,
        )

        self.assertEqual(status, 200)
        self.assertEqual(body["gatewayStatus"], "applied")
        self.assertEqual(body["entitlement"]["entitlementTier"], "pro")
        self.assertEqual(body["entitlement"]["outcome"], "verifiedActivePro")

    def test_gateway_oppo_max_webhook_success(self):
        app = self._app_with_gateway()

        status, body = self.request(
            "POST",
            "/iap/webhooks/oppo",
            body=gateway_body(
                OPPO_CHANNEL,
                user_id="user-oppo",
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="oppo-tx-1",
            ),
            app=app,
        )

        self.assertEqual(status, 200)
        self.assertEqual(body["gatewayStatus"], "applied")
        self.assertEqual(body["entitlement"]["entitlementTier"], "max")
        self.assertEqual(body["entitlement"]["outcome"], "verifiedActiveMax")

    def test_gateway_xiaomi_pro_webhook_success(self):
        app = self._app_with_gateway()

        status, body = self.request(
            "POST",
            "/iap/webhooks/xiaomi",
            body=gateway_body(
                XIAOMI_CHANNEL,
                user_id="user-xiaomi",
                product_id=PRO_YEARLY_PRODUCT_ID,
                transaction_id="xiaomi-tx-1",
            ),
            app=app,
        )

        self.assertEqual(status, 200)
        self.assertEqual(body["gatewayStatus"], "applied")
        self.assertEqual(body["entitlement"]["entitlementTier"], "pro")
        self.assertEqual(body["entitlement"]["outcome"], "verifiedActivePro")

    def test_gateway_huawei_expired_webhook_is_rejected_without_unlock(self):
        app = self._app_with_gateway(internal_entitlement_token="internal-token")

        status, body = self.request(
            "POST",
            "/iap/webhooks/huawei",
            body=gateway_body(
                HUAWEI_CHANNEL,
                user_id="user-huawei",
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="huawei-tx-1",
                status="expired",
                expires_at="2020-01-01T00:00:00.000Z",
            ),
            app=app,
        )
        entitlement_status, entitlement_body = self.request(
            "POST",
            "/internal/v1/entitlements/verify",
            body=internal_entitlement_body("user-huawei"),
            app=app,
            headers={"Authorization": "Bearer internal-token"},
        )

        self.assertEqual(status, 200)
        self.assertEqual(body["gatewayStatus"], "rejected")
        self.assertEqual(body["entitlement"]["outcome"], "expired")
        self.assertEqual(body["entitlement"]["entitlementTier"], "none")
        self.assertEqual(entitlement_status, 200)
        self.assertEqual(entitlement_body["allowed"], False)
        self.assertEqual(entitlement_body["status"], "expired")

    def test_gateway_vivo_replay_attack_is_rejected(self):
        app = self._app_with_gateway()
        first_body = gateway_body(
            VIVO_CHANNEL,
            user_id="user-vivo",
            product_id=PRO_YEARLY_PRODUCT_ID,
            transaction_id="vivo-tx-1",
        )
        replay_body = gateway_body(
            VIVO_CHANNEL,
            user_id="user-vivo",
            product_id=MAX_YEARLY_PRODUCT_ID,
            transaction_id="vivo-tx-1",
        )

        first_status, first_response = self.request(
            "POST",
            "/iap/webhooks/vivo",
            body=first_body,
            app=app,
        )
        replay_status, replay_response = self.request(
            "POST",
            "/iap/webhooks/vivo",
            body=replay_body,
            app=app,
        )

        self.assertEqual(first_status, 200)
        self.assertEqual(first_response["entitlement"]["entitlementTier"], "pro")
        self.assertEqual(replay_status, 409)
        self.assertEqual(replay_response["error"]["code"], "replay_attack")
        self.assertEqual(
            app.store.get_latest_entitlement_for_user("user-vivo").entitlement_tier,
            "pro",
        )

    def test_gateway_duplicate_transaction_id_is_ignored(self):
        app = self._app_with_gateway()
        body = gateway_body(
            GOOGLE_PLAY_CHANNEL,
            user_id="user-duplicate",
            product_id=PRO_YEARLY_PRODUCT_ID,
            transaction_id="duplicate-tx-1",
        )

        first_status, first_response = self.request(
            "POST",
            "/iap/webhooks/google_play",
            body=body,
            app=app,
        )
        second_status, second_response = self.request(
            "POST",
            "/iap/webhooks/google_play",
            body=body,
            app=app,
        )

        self.assertEqual(first_status, 200)
        self.assertEqual(first_response["gatewayStatus"], "applied")
        self.assertEqual(second_status, 200)
        self.assertEqual(second_response["gatewayStatus"], "ignored")
        self.assertEqual(second_response["entitlement"]["entitlementTier"], "pro")

    def test_gateway_invalid_signature_is_rejected(self):
        app = self._app_with_gateway()
        body = gateway_body(
            OPPO_CHANNEL,
            user_id="user-invalid-signature",
            product_id=MAX_YEARLY_PRODUCT_ID,
            transaction_id="invalid-signature-tx-1",
        )
        body["signature"] = "sha256=invalid"

        status, response = self.request(
            "POST",
            "/iap/webhooks/oppo",
            body=body,
            app=app,
        )

        self.assertEqual(status, 401)
        self.assertEqual(response["error"]["code"], "invalid_signature")
        self.assertIsNone(app.store.get_latest_entitlement_for_user("user-invalid-signature"))

    def test_gateway_client_fake_plan_max_is_ignored(self):
        app = self._app_with_gateway()

        status, body = self.request(
            "POST",
            "/iap/webhooks/google_play",
            body=gateway_body(
                GOOGLE_PLAY_CHANNEL,
                user_id="user-fake-plan",
                product_id=PRO_YEARLY_PRODUCT_ID,
                transaction_id="fake-plan-tx-1",
                plan="max",
            ),
            app=app,
        )

        self.assertEqual(status, 200)
        self.assertEqual(body["gatewayStatus"], "applied")
        self.assertEqual(body["entitlement"]["productId"], PRO_YEARLY_PRODUCT_ID)
        self.assertEqual(body["entitlement"]["entitlementTier"], "pro")

    def test_entitlement_engine_maps_product_ids_consistently_across_channels(self):
        engine = EntitlementEngine(self.store, DEFAULT_ALLOWED_PRODUCTS)
        channels = (
            "apple",
            GOOGLE_PLAY_CHANNEL,
            OPPO_CHANNEL,
            XIAOMI_CHANNEL,
            HUAWEI_CHANNEL,
            VIVO_CHANNEL,
        )

        for index, channel in enumerate(channels, start=1):
            with self.subTest(channel=channel):
                record = engine.apply(
                    PurchaseEvent(
                        user_id=f"user-engine-{index}",
                        channel=channel,
                        product_id=MAX_YEARLY_PRODUCT_ID,
                        transaction_id=f"engine-tx-{index}",
                        signature="verified",
                        raw_payload={"normalizedStatus": "active"},
                    )
                )

                self.assertEqual(record.entitlement_tier, "max")
                self.assertEqual(record.outcome, "verifiedActiveMax")

    def test_scp_reordered_webhook_cannot_overwrite_newer_state(self):
        app = self._app_with_gateway()
        user_id = "user-scp-reorder"

        newer_status, newer_body = self.request(
            "POST",
            "/iap/webhooks/oppo",
            body=gateway_body(
                OPPO_CHANNEL,
                user_id=user_id,
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="scp-reorder-newer",
                eventTime="2026-06-26T12:00:00Z",
            ),
            app=app,
        )
        older_status, older_body = self.request(
            "POST",
            "/iap/webhooks/oppo",
            body=gateway_body(
                OPPO_CHANNEL,
                user_id=user_id,
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="scp-reorder-older",
                status="expired",
                eventTime="2026-06-25T12:00:00Z",
            ),
            app=app,
        )

        self.assertEqual(newer_status, 200)
        self.assertEqual(newer_body["gatewayStatus"], "applied")
        self.assertEqual(older_status, 200)
        self.assertEqual(older_body["gatewayStatus"], "ignored")
        entitlement = app.store.get_latest_entitlement_for_user(user_id)
        state = app.store.get_subscription_state(user_id, MAX_YEARLY_PRODUCT_ID)
        processed = app.store.list_subscription_audit_log(PROCESSED_EVENT_LOG)
        self.assertEqual(entitlement.entitlement_tier, "max")
        self.assertEqual(entitlement.outcome, "verifiedActiveMax")
        self.assertEqual(state.state, STATE_ACTIVE)
        self.assertIn("stale_event_ignored", {entry["reason"] for entry in processed})

    def test_scp_lower_authority_verify_cannot_override_webhook_state(self):
        app = self._app_with_gateway()
        user_id = "user-scp-authority"

        high_status, _ = self.request(
            "POST",
            "/iap/webhooks/xiaomi",
            body=gateway_body(
                XIAOMI_CHANNEL,
                user_id=user_id,
                product_id=PRO_YEARLY_PRODUCT_ID,
                transaction_id="scp-authority-high",
                source="webhook",
                eventTime="2026-06-26T12:00:00Z",
            ),
            app=app,
        )
        low_status, low_body = self.request(
            "POST",
            "/iap/webhooks/xiaomi",
            body=gateway_body(
                XIAOMI_CHANNEL,
                user_id=user_id,
                product_id=PRO_YEARLY_PRODUCT_ID,
                transaction_id="scp-authority-low",
                status="expired",
                source="verify",
                eventTime="2026-06-27T12:00:00Z",
            ),
            app=app,
        )

        self.assertEqual(high_status, 200)
        self.assertEqual(low_status, 200)
        self.assertEqual(low_body["gatewayStatus"], "ignored")
        entitlement = app.store.get_latest_entitlement_for_user(user_id)
        state = app.store.get_subscription_state(user_id, PRO_YEARLY_PRODUCT_ID)
        processed = app.store.list_subscription_audit_log(PROCESSED_EVENT_LOG)
        self.assertEqual(entitlement.outcome, "verifiedActivePro")
        self.assertEqual(state.authority_score, 90)
        self.assertIn("lower_authority_event_ignored", {entry["reason"] for entry in processed})

    def test_scp_replay_with_different_payload_cannot_override_state(self):
        app = self._app_with_gateway()
        user_id = "user-scp-replay"
        first = gateway_body(
            VIVO_CHANNEL,
            user_id=user_id,
            product_id=PRO_YEARLY_PRODUCT_ID,
            transaction_id="scp-replay-tx",
            eventTime="2026-06-26T12:00:00Z",
        )
        replay = gateway_body(
            VIVO_CHANNEL,
            user_id=user_id,
            product_id=PRO_YEARLY_PRODUCT_ID,
            transaction_id="scp-replay-tx",
            status="expired",
            eventTime="2026-06-27T12:00:00Z",
        )

        first_status, _ = self.request("POST", "/iap/webhooks/vivo", body=first, app=app)
        replay_status, replay_body = self.request("POST", "/iap/webhooks/vivo", body=replay, app=app)

        self.assertEqual(first_status, 200)
        self.assertEqual(replay_status, 409)
        self.assertEqual(replay_body["error"]["code"], "replay_attack")
        entitlement = app.store.get_latest_entitlement_for_user(user_id)
        state = app.store.get_subscription_state(user_id, PRO_YEARLY_PRODUCT_ID)
        self.assertEqual(entitlement.outcome, "verifiedActivePro")
        self.assertEqual(state.state, STATE_ACTIVE)

    def test_scp_reconciliation_repairs_active_provider_drift(self):
        app = self._app_with_gateway()
        user_id = "user-scp-reconcile"
        self.request(
            "POST",
            "/iap/webhooks/oppo",
            body=gateway_body(
                OPPO_CHANNEL,
                user_id=user_id,
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="scp-reconcile-initial",
            ),
            app=app,
        )
        app.store.upsert_subscription_state(
            user_id=user_id,
            product_id=MAX_YEARLY_PRODUCT_ID,
            state=STATE_EXPIRED,
            authority_score=90,
            event_time=None,
            event_version=1,
            channel=OPPO_CHANNEL,
            transaction_id="scp-reconcile-drift",
        )
        worker = SubscriptionReconciliationWorker(
            store=app.store,
            provider_verifiers={
                OPPO_CHANNEL: FixedProviderVerifier(
                    ProviderSubscriptionState(
                        state=STATE_ACTIVE,
                        channel=OPPO_CHANNEL,
                        transaction_id="scp-reconcile-provider",
                        event_time="2026-06-27T12:00:00Z",
                    )
                )
            },
            entitlement_engine=EntitlementEngine(app.store, DEFAULT_ALLOWED_PRODUCTS),
        )

        result = worker.reconcile_active_entitlements()

        state = app.store.get_subscription_state(user_id, MAX_YEARLY_PRODUCT_ID)
        entitlement = app.store.get_latest_entitlement_for_user(user_id)
        changes = app.store.list_subscription_audit_log(ENTITLEMENT_CHANGE_LOG)
        self.assertEqual(result["repaired"], 1)
        self.assertEqual(state.state, STATE_ACTIVE)
        self.assertEqual(entitlement.outcome, "verifiedActiveMax")
        self.assertIn("reconciliation_upgrade", {entry["reason"] for entry in changes})

    def test_scp_reconciliation_downgrade_enters_grace(self):
        app = self._app_with_gateway()
        user_id = "user-scp-downgrade"
        self.request(
            "POST",
            "/iap/webhooks/oppo",
            body=gateway_body(
                OPPO_CHANNEL,
                user_id=user_id,
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="scp-downgrade-initial",
            ),
            app=app,
        )
        worker = SubscriptionReconciliationWorker(
            store=app.store,
            provider_verifiers={
                OPPO_CHANNEL: FixedProviderVerifier(
                    ProviderSubscriptionState(
                        state=STATE_EXPIRED,
                        channel=OPPO_CHANNEL,
                        transaction_id="scp-downgrade-provider",
                        event_time="2026-06-27T12:00:00Z",
                    )
                )
            },
            entitlement_engine=EntitlementEngine(app.store, DEFAULT_ALLOWED_PRODUCTS),
        )

        result = worker.reconcile_active_entitlements()

        state = app.store.get_subscription_state(user_id, MAX_YEARLY_PRODUCT_ID)
        entitlement = app.store.get_latest_entitlement_for_user(user_id)
        changes = app.store.list_subscription_audit_log(ENTITLEMENT_CHANGE_LOG)
        self.assertEqual(result["repaired"], 1)
        self.assertEqual(state.state, STATE_GRACE)
        self.assertEqual(entitlement.outcome, "verifiedGracePeriodMax")
        self.assertIn("reconciliation_downgrade_to_grace", {entry["reason"] for entry in changes})

    def test_scp_audit_log_is_append_only(self):
        app = self._app_with_gateway()
        self.request(
            "POST",
            "/iap/webhooks/oppo",
            body=gateway_body(
                OPPO_CHANNEL,
                user_id="user-scp-audit",
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="scp-audit-tx",
            ),
            app=app,
        )
        logs = app.store.list_subscription_audit_log()

        self.assertGreaterEqual(len(logs), 3)
        self.assertEqual(logs[0]["log_type"], RAW_EVENT_LOG)
        with closing(sqlite3.connect(app.store.db_path)) as conn:
            with self.assertRaises(sqlite3.DatabaseError):
                conn.execute(
                    "UPDATE iap_subscription_audit_log SET reason = ? WHERE id = ?",
                    ("mutated", logs[0]["id"]),
                )
            conn.rollback()
            with self.assertRaises(sqlite3.DatabaseError):
                conn.execute(
                    "DELETE FROM iap_subscription_audit_log WHERE id = ?",
                    (logs[0]["id"],),
                )

    def test_internal_entitlement_db_error_fails_closed_as_503(self):
        app = IapVerificationApp(
            store=DbErrorEntitlementStore(),
            validator=RequestValidator(DEFAULT_ALLOWED_PRODUCTS, DEFAULT_ALLOWED_BUNDLE_ID),
            verifier=FakeAppleVerifier(),
            max_request_bytes=64 * 1024,
            internal_entitlement_token="internal-token",
        )

        status, body = self.request(
            "POST",
            "/internal/v1/entitlements/verify",
            body=internal_entitlement_body("user-a"),
            app=app,
            headers={"Authorization": "Bearer internal-token"},
        )

        self.assertEqual(status, 503)
        self.assertEqual(body["error"]["code"], "subscription_verification_unavailable")

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
                product_id="com.yuyuan.assetledger.retired.monthly",
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
                "user_id",
            },
        )

    def test_storage_migrates_old_schema_without_losing_rows(self):
        db_path = f"{self.temp_dir.name}/old-schema.sqlite3"
        with closing(sqlite3.connect(db_path)) as conn:
            with conn:
                conn.execute(
                    """
                    CREATE TABLE iap_entitlements (
                      app_account_token TEXT PRIMARY KEY,
                      entitlement_tier TEXT NOT NULL,
                      original_transaction_id TEXT,
                      latest_transaction_id TEXT,
                      product_id TEXT,
                      environment TEXT,
                      expires_at TEXT,
                      revoked_at TEXT,
                      outcome TEXT NOT NULL,
                      updated_at TEXT NOT NULL
                    )
                    """
                )
                conn.execute(
                    """
                    INSERT INTO iap_entitlements (
                      app_account_token, entitlement_tier, original_transaction_id,
                      latest_transaction_id, product_id, environment, expires_at,
                      revoked_at, outcome, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        PRO_TOKEN,
                        "pro",
                        "historical-original-1",
                        "historical-latest-1",
                        PRO_YEARLY_PRODUCT_ID,
                        "Sandbox",
                        "2099-01-01T00:00:00.000Z",
                        None,
                        "verifiedActivePro",
                        "2026-06-26T00:00:00.000Z",
                    ),
                )

        migrated = EntitlementStore(db_path)
        record = migrated.get_entitlement(PRO_TOKEN)

        self.assertIsNotNone(record)
        self.assertEqual(record.original_transaction_id, "historical-original-1")
        self.assertIsNone(record.user_id)
        with closing(sqlite3.connect(db_path)) as conn:
            columns = {row[1] for row in conn.execute("PRAGMA table_info(iap_entitlements)").fetchall()}
        self.assertIn("user_id", columns)

    def test_app_config_reads_env_without_secret_defaults(self):
        with _patched_env(
            FLEET_IAP_PORT="9011",
            FLEET_IAP_DB_PATH="/tmp/fleet-iap.sqlite3",
            FLEET_IAP_ALLOWED_BUNDLE_ID="com.example.test",
            FLEET_IAP_ALLOWED_PRODUCTS=f"{PRO_YEARLY_PRODUCT_ID},{MAX_YEARLY_PRODUCT_ID}",
            FLEET_IAP_MAX_REQUEST_BYTES="4096",
            FLEET_IAP_APPLE_REQUEST_TIMEOUT_SECONDS="7",
            SERVICE_INTERNAL_TOKEN="internal-token",
        ):
            config = AppConfig.from_env()

        self.assertEqual(config.port, 9011)
        self.assertEqual(config.database_path, "/tmp/fleet-iap.sqlite3")
        self.assertEqual(config.allowed_bundle_id, "com.example.test")
        self.assertEqual(config.allowed_products, (PRO_YEARLY_PRODUCT_ID, MAX_YEARLY_PRODUCT_ID))
        self.assertEqual(config.max_request_bytes, 4096)
        self.assertEqual(config.apple_request_timeout_seconds, 7)
        self.assertEqual(config.internal_entitlement_token, "internal-token")
        self.assertFalse(config.apple_credentials.is_complete)
        self.assertIsNone(config.apple_credentials.key_id)
        self.assertEqual(config.apple_credentials.root_certificate_paths, ())
        self.assertIsNone(config.apple_credentials.app_apple_id)

    def test_deprecated_env_keys_raise_migration_error(self):
        auth_key = "FLEET" + "_IAP_AUTH_HS256_SECRET"
        with _patched_env(**{auth_key: "old-secret"}):
            with self.assertRaisesRegex(ConfigMigrationError, "USER_AUTH_HS256_SECRET"):
                AppConfig.from_env()

        service_key = "IAP" + "_INTERNAL_ENTITLEMENT_TOKEN"
        with _patched_env(**{service_key: "old-token"}):
            with self.assertRaisesRegex(ConfigMigrationError, "SERVICE_INTERNAL_TOKEN"):
                AppConfig.from_env()

    def test_app_config_rejects_products_outside_contract_allowlist(self):
        with _patched_env(
            FLEET_IAP_ALLOWED_PRODUCTS=f"{PRO_YEARLY_PRODUCT_ID},com.yuyuan.assetledger.retired.monthly",
        ):
            with self.assertRaises(ValueError):
                AppConfig.from_env()

    def test_entitlement_binding_policy_constants_are_explicit(self):
        self.assertEqual(
            ENTITLEMENT_BINDING_POLICIES,
            (
                EntitlementBindingPolicy.BIND_ONLY_IF_UNBOUND,
                EntitlementBindingPolicy.NEVER_OVERWRITE_DIFFERENT_USER,
                EntitlementBindingPolicy.TRANSACTION_IS_VERIFICATION_ONLY,
            ),
        )

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


def gateway_secrets():
    return {
        GOOGLE_PLAY_CHANNEL: "google-secret",
        OPPO_CHANNEL: "oppo-secret",
        XIAOMI_CHANNEL: "xiaomi-secret",
        HUAWEI_CHANNEL: "huawei-secret",
        VIVO_CHANNEL: "vivo-secret",
    }


def gateway_body(
    channel,
    *,
    user_id,
    product_id,
    transaction_id,
    status="active",
    expires_at=None,
    **extra,
):
    body = {
        "channel": channel,
        "user_id": user_id,
        "product_id": product_id,
        "transaction_id": transaction_id,
        "status": status,
        **extra,
    }
    if expires_at is not None:
        body["expiresAt"] = expires_at
    body["signature"] = signature_for_payload(body, gateway_secrets()[channel])
    return body


def internal_entitlement_body(
    user_id,
    required_capability="cloud_backup",
    required_plan="max",
):
    return {
        "user_id": user_id,
        "required_capability": required_capability,
        "required_plan": required_plan,
    }


class FixedProviderVerifier:
    def __init__(self, provider_state):
        self.provider_state = provider_state

    def verify(self, *, user_id, product_id, current_entitlement):
        return self.provider_state


class DiagnosticFailureVerifier:
    def verify_purchase(self, request):
        raise AppleVerificationFailed(
            "apple signed payload verification failed",
            apple_verification_status="INVALID_CHAIN",
            apple_verification_statuses="Sandbox:INVALID_CHAIN,Production:INVALID_ENVIRONMENT",
        )

    def refresh_current_entitlement(self, record):
        return record


class FixedOriginalVerifier:
    def verify_purchase(self, request):
        if request.server_verification_data == "fixed:max-active":
            outcome = "verifiedActiveMax"
        elif request.server_verification_data == "fixed:max-grace":
            outcome = "verifiedGracePeriodMax"
        else:
            raise AppleVerificationFailed("unknown fixed verification token")
        return EntitlementRecord(
            outcome=outcome,
            entitlement_tier="max",
            product_id=request.product_id,
            app_account_token=request.app_account_token,
            original_transaction_id="fixed-original-1",
            latest_transaction_id=request.purchase_id,
            environment="Sandbox",
            expires_at="2099-01-01T00:00:00.000Z",
        )

    def refresh_current_entitlement(self, record):
        return record


class FallbackUserVerifier:
    def __init__(self, fallback_user_id):
        self.fallback_user_id = fallback_user_id

    def verify_purchase(self, request):
        return EntitlementRecord(
            outcome="verifiedActiveMax",
            entitlement_tier="max",
            product_id=request.product_id,
            app_account_token=request.app_account_token,
            original_transaction_id="fallback-original-1",
            latest_transaction_id=request.purchase_id,
            environment="Sandbox",
            expires_at="2099-01-01T00:00:00.000Z",
            user_id=self.fallback_user_id,
        )

    def refresh_current_entitlement(self, record):
        return record


class DbErrorEntitlementStore:
    def get_latest_max_entitlement_for_user(self, user_id):
        raise sqlite3.OperationalError("simulated db error")

    def get_latest_entitlement_for_user(self, user_id):
        raise sqlite3.OperationalError("simulated db error")


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
