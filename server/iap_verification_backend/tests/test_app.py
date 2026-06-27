from __future__ import annotations

import io
import hashlib
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
    FINAL_VERDICT_COMPROMISED,
    FINAL_VERDICT_VERIFIED,
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
    RBL_VIOLATION_LOG,
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
    IntegrityVerifier,
    PurchaseEvent,
    IapVerificationRequestHandler,
    RequestValidator,
    RblViolation,
    RuntimeWriteContext,
    RuntimeWriteFirewall,
    SecurityViolation,
    EventHashChain,
    SubscriptionEvent,
    SubscriptionLedgerIntegrityError,
    SubscriptionReconciliationWorker,
    PROJECTION_CACHE_ONLY_NOTICE,
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
            write_context=app.store.internal_admin_write_context(
                operation="test_fixture_expired_entitlement",
                user_id="user-expired",
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="max-expired-latest-1",
            ),
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
            write_context=app.store.internal_admin_write_context(
                operation="test_fixture_subscription_state_drift",
                user_id=user_id,
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="scp-reconcile-drift",
            ),
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

        result = worker.reconcile_active_entitlements(system_job=True)

        state = app.store.get_subscription_state(user_id, MAX_YEARLY_PRODUCT_ID)
        entitlement = app.store.get_latest_entitlement_for_user(user_id)
        changes = app.store.list_subscription_audit_log(ENTITLEMENT_CHANGE_LOG)
        self.assertEqual(result["repaired"], 0)
        self.assertEqual(result["skipped"], 1)
        self.assertEqual(state.state, STATE_ACTIVE)
        self.assertEqual(entitlement.outcome, "verifiedActiveMax")
        self.assertNotIn("reconciliation_upgrade", {entry["reason"] for entry in changes})

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

        result = worker.reconcile_active_entitlements(system_job=True)

        state = app.store.get_subscription_state(user_id, MAX_YEARLY_PRODUCT_ID)
        entitlement = app.store.get_latest_entitlement_for_user(user_id)
        changes = app.store.list_subscription_audit_log(ENTITLEMENT_CHANGE_LOG)
        self.assertEqual(result["repaired"], 1)
        self.assertEqual(state.state, STATE_GRACE)
        self.assertEqual(entitlement.outcome, "verifiedGracePeriodMax")
        self.assertIn("reconciliation_downgrade_to_grace", {entry["reason"] for entry in changes})

    def test_scp_v2_replay_is_deterministic_when_events_are_shuffled(self):
        app = self._app_with_gateway()
        user_id = "user-ledger-deterministic"
        self.request(
            "POST",
            "/iap/webhooks/google_play",
            body=gateway_body(
                GOOGLE_PLAY_CHANNEL,
                user_id=user_id,
                product_id=PRO_YEARLY_PRODUCT_ID,
                transaction_id="ledger-deterministic-active",
                eventTime="2026-06-26T10:00:00Z",
            ),
            app=app,
        )
        self.request(
            "POST",
            "/iap/webhooks/google_play",
            body=gateway_body(
                GOOGLE_PLAY_CHANNEL,
                user_id=user_id,
                product_id=PRO_YEARLY_PRODUCT_ID,
                transaction_id="ledger-deterministic-expired",
                status="expired",
                eventTime="2026-06-27T10:00:00Z",
            ),
            app=app,
        )
        events = app.gateway_service.event_store.get_events(user_id)

        normal = app.gateway_service.replay_engine.replay(
            user_id,
            update_projection=False,
            events=events,
        )
        shuffled = app.gateway_service.replay_engine.replay(
            user_id,
            update_projection=False,
            events=list(reversed(events)),
        )

        self.assertEqual(normal.current_entitlement_body(), shuffled.current_entitlement_body())
        self.assertEqual(normal.to_dict()["productStates"], shuffled.to_dict()["productStates"])

    def test_scp_v2_event_history_integrity_matches_projection(self):
        app = self._app_with_gateway()
        user_id = "user-ledger-integrity"
        self.request(
            "POST",
            "/iap/webhooks/xiaomi",
            body=gateway_body(
                XIAOMI_CHANNEL,
                user_id=user_id,
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="ledger-integrity-active",
                source="webhook",
                eventTime="2026-06-26T10:00:00Z",
            ),
            app=app,
        )

        snapshots = app.gateway_service.replay_engine.replay_all(update_projection=True)
        diff = app.gateway_service.replay_engine.projection_diff(user_id)

        self.assertIn(user_id, snapshots)
        self.assertTrue(diff["matches"])
        self.assertEqual(
            app.store.get_entitlement_projection(user_id)["last_replayed_event_id"],
            app.gateway_service.event_store.get_events(user_id)[-1].event_id,
        )

    def test_scp_v2_tampered_projection_is_overwritten_by_replay(self):
        app = self._app_with_gateway()
        user_id = "user-ledger-tamper"
        self.request(
            "POST",
            "/iap/webhooks/oppo",
            body=gateway_body(
                OPPO_CHANNEL,
                user_id=user_id,
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="ledger-tamper-active",
                eventTime="2026-06-26T10:00:00Z",
            ),
            app=app,
        )
        current = app.store.get_latest_entitlement_for_user(user_id)
        tampered = EntitlementRecord(
            outcome="expired",
            entitlement_tier="none",
            product_id=current.product_id,
            app_account_token=current.app_account_token,
            original_transaction_id=current.original_transaction_id,
            latest_transaction_id="ledger-tamper-forged",
            environment=current.environment,
            expires_at="2020-01-01T00:00:00.000Z",
        )
        context = app.store.internal_admin_write_context(
            operation="test_tamper_projection",
            user_id=user_id,
            product_id=MAX_YEARLY_PRODUCT_ID,
            transaction_id="ledger-tamper-forged",
        )
        app.store.upsert_entitlement(tampered, user_id=user_id, write_context=context)
        app.store.upsert_subscription_state(
            user_id=user_id,
            product_id=MAX_YEARLY_PRODUCT_ID,
            state=STATE_EXPIRED,
            authority_score=1,
            event_time="2026-06-27T10:00:00Z",
            event_version=999,
            channel=OPPO_CHANNEL,
            transaction_id="ledger-tamper-forged",
            write_context=context,
        )

        replayed = app.gateway_service.replay_engine.replay(user_id, update_projection=True)

        self.assertEqual(replayed.current_entitlement.outcome, "verifiedActiveMax")
        self.assertEqual(app.store.get_latest_entitlement_for_user(user_id).outcome, "verifiedActiveMax")
        self.assertEqual(
            app.store.get_subscription_state(user_id, MAX_YEARLY_PRODUCT_ID).state,
            STATE_ACTIVE,
        )

    def test_scp_v2_reconciliation_emits_correction_event_not_direct_fix(self):
        app = self._app_with_gateway()
        user_id = "user-ledger-reconciliation-event"
        self.request(
            "POST",
            "/iap/webhooks/oppo",
            body=gateway_body(
                OPPO_CHANNEL,
                user_id=user_id,
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="ledger-reconciliation-initial",
                eventTime="2026-06-26T10:00:00Z",
            ),
            app=app,
        )
        contexts = []
        original_execute_write = app.store.execute_write

        def spy_execute_write(conn, sql, parameters=(), *, table_name, operation, context=None):
            active_context = context or RuntimeWriteFirewall.current_context()
            if table_name in {"iap_entitlements", "iap_subscription_state"}:
                contexts.append(None if active_context is None else active_context.source)
            return original_execute_write(
                conn,
                sql,
                parameters,
                table_name=table_name,
                operation=operation,
                context=context,
            )

        app.store.execute_write = spy_execute_write
        worker = SubscriptionReconciliationWorker(
            store=app.store,
            provider_verifiers={
                OPPO_CHANNEL: FixedProviderVerifier(
                    ProviderSubscriptionState(
                        state=STATE_EXPIRED,
                        channel=OPPO_CHANNEL,
                        transaction_id="ledger-reconciliation-correction",
                        event_time="2026-06-27T10:00:00Z",
                    )
                )
            },
            entitlement_engine=EntitlementEngine(app.store, DEFAULT_ALLOWED_PRODUCTS),
        )
        before_events = app.gateway_service.event_store.get_events(user_id)

        result = worker.reconcile_active_entitlements(system_job=True)

        after_events = app.gateway_service.event_store.get_events(user_id)
        self.assertEqual(result["repaired"], 1)
        self.assertEqual(len(after_events), len(before_events) + 1)
        self.assertEqual(after_events[-1].source, "reconciliation")
        self.assertEqual(after_events[-1].event_type, "EXPIRE")
        self.assertEqual(
            app.store.get_subscription_state(user_id, MAX_YEARLY_PRODUCT_ID).state,
            STATE_GRACE,
        )
        self.assertEqual(set(contexts), {"subscription_replay_engine.py"})

    def test_scp_v2_full_system_rebuild_recovers_from_event_store_only(self):
        app = self._app_with_gateway()
        user_id = "user-ledger-rebuild"
        self.request(
            "POST",
            "/iap/webhooks/vivo",
            body=gateway_body(
                VIVO_CHANNEL,
                user_id=user_id,
                product_id=PRO_YEARLY_PRODUCT_ID,
                transaction_id="ledger-rebuild-active",
                eventTime="2026-06-26T10:00:00Z",
            ),
            app=app,
        )
        context = app.store.internal_admin_write_context(
            operation="test_clear_projection_for_rebuild",
            user_id=user_id,
            product_id=PRO_YEARLY_PRODUCT_ID,
            transaction_id="ledger-rebuild-clear",
        )
        with closing(app.store._store._connect()) as conn:
            with conn:
                for table_name in (
                    "iap_entitlements",
                    "iap_subscription_state",
                    "iap_entitlement_projections",
                ):
                    app.store.execute_write(
                        conn,
                        f"DELETE FROM {table_name}",
                        (),
                        table_name=table_name,
                        operation="test_clear_projection_for_rebuild",
                        context=context,
                    )

        self.assertIsNone(app.store.get_latest_entitlement_for_user(user_id))

        app.gateway_service.replay_engine.replay_all(update_projection=True)

        self.assertEqual(
            app.store.get_latest_entitlement_for_user(user_id).outcome,
            "verifiedActivePro",
        )
        self.assertEqual(
            app.store.get_subscription_state(user_id, PRO_YEARLY_PRODUCT_ID).state,
            STATE_ACTIVE,
        )

    def test_scp_v2_internal_ledger_replay_api_returns_diff_and_events(self):
        app = self._app_with_gateway(internal_entitlement_token="internal-token")
        user_id = "user-ledger-api"
        self.request(
            "POST",
            "/iap/webhooks/google_play",
            body=gateway_body(
                GOOGLE_PLAY_CHANNEL,
                user_id=user_id,
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="ledger-api-active",
                eventTime="2026-06-26T10:00:00Z",
            ),
            app=app,
        )

        status, body = self.request(
            "GET",
            f"/internal/v2/ledger/replay/{user_id}",
            app=app,
            headers={"Authorization": "Bearer internal-token"},
        )

        self.assertEqual(status, 200)
        self.assertEqual(body["userId"], user_id)
        self.assertEqual(len(body["events"]), 1)
        self.assertEqual(
            body["reconstructedState"]["currentEntitlement"]["outcome"],
            "verifiedActiveMax",
        )
        self.assertTrue(body["projectionDiffAfter"]["matches"])

    def test_bol_explanation_consistency_matches_replay_transition(self):
        app = self._app_with_gateway()
        user_id = "user-bol-consistency"
        self.request(
            "POST",
            "/iap/webhooks/google_play",
            body=gateway_body(
                GOOGLE_PLAY_CHANNEL,
                user_id=user_id,
                product_id=PRO_YEARLY_PRODUCT_ID,
                transaction_id="bol-consistency-active",
                eventTime="2026-06-26T10:00:00Z",
            ),
            app=app,
        )
        event = app.gateway_service.event_store.get_events(user_id)[0]

        replayed = app.gateway_service.replay_engine.replay(user_id, update_projection=False)
        decision = replayed.decision_for_event_id(event.event_id)
        explanation = app.gateway_service.explanation_store.get_explanation_by_event(
            event.event_id
        )

        self.assertIsNotNone(decision)
        self.assertIsNotNone(explanation)
        self.assertEqual(
            explanation.state_transition,
            {
                "previous_state": decision.previous_state,
                "new_state": decision.new_state,
            },
        )
        self.assertTrue(explanation.integrity_context["hash_verified"])
        self.assertTrue(explanation.integrity_context["replay_verified"])
        self.assertEqual(explanation.event_type, "PURCHASE")

    def test_bol_authority_explanation_includes_high_authority_override_reason(self):
        app = self._app_with_gateway()
        user_id = "user-bol-authority"
        self.request(
            "POST",
            "/iap/webhooks/xiaomi",
            body=gateway_body(
                XIAOMI_CHANNEL,
                user_id=user_id,
                product_id=PRO_YEARLY_PRODUCT_ID,
                transaction_id="bol-authority-low-grace",
                status="grace",
                source="verify",
                eventTime="2026-06-26T10:00:00Z",
            ),
            app=app,
        )
        self.request(
            "POST",
            "/iap/webhooks/xiaomi",
            body=gateway_body(
                XIAOMI_CHANNEL,
                user_id=user_id,
                product_id=PRO_YEARLY_PRODUCT_ID,
                transaction_id="bol-authority-high-active",
                source="webhook",
                eventTime="2026-06-27T10:00:00Z",
            ),
            app=app,
        )
        high_event = app.gateway_service.event_store.get_events(user_id)[-1]

        explanation = app.gateway_service.explanation_store.get_explanation_by_event(
            high_event.event_id
        )

        self.assertEqual(explanation.state_transition["previous_state"], STATE_GRACE)
        self.assertEqual(explanation.state_transition["new_state"], STATE_ACTIVE)
        self.assertEqual(explanation.authority_context["authority_score"], 90)
        self.assertIn("override_reason", explanation.authority_context)
        self.assertIn("High authority XIAOMI event", explanation.authority_context["override_reason"])
        self.assertIn("moved entitlement from GRACE to ACTIVE", explanation.causal_reason)

    def test_bol_reconciliation_correction_event_has_explanation(self):
        app = self._app_with_gateway()
        user_id = "user-bol-reconciliation"
        self.request(
            "POST",
            "/iap/webhooks/oppo",
            body=gateway_body(
                OPPO_CHANNEL,
                user_id=user_id,
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="bol-reconciliation-initial",
                eventTime="2026-06-26T10:00:00Z",
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
                        transaction_id="bol-reconciliation-correction",
                        event_time="2026-06-27T10:00:00Z",
                    )
                )
            },
            entitlement_engine=EntitlementEngine(app.store, DEFAULT_ALLOWED_PRODUCTS),
        )

        result = worker.reconcile_active_entitlements(system_job=True)

        events = app.gateway_service.event_store.get_events(user_id)
        correction = events[-1]
        explanation = app.gateway_service.explanation_store.get_explanation_by_event(
            correction.event_id
        )
        self.assertEqual(result["repaired"], 1)
        self.assertEqual(correction.source, "reconciliation")
        self.assertEqual(explanation.trigger_source, "reconcile")
        self.assertIn("Provider reconciliation detected entitlement drift", explanation.causal_reason)
        self.assertEqual(explanation.state_transition["new_state"], STATE_GRACE)

    def test_bol_explanations_are_deterministic_when_events_are_shuffled(self):
        app = self._app_with_gateway()
        user_id = "user-bol-deterministic"
        self.request(
            "POST",
            "/iap/webhooks/google_play",
            body=gateway_body(
                GOOGLE_PLAY_CHANNEL,
                user_id=user_id,
                product_id=PRO_YEARLY_PRODUCT_ID,
                transaction_id="bol-deterministic-active",
                eventTime="2026-06-26T10:00:00Z",
            ),
            app=app,
        )
        self.request(
            "POST",
            "/iap/webhooks/google_play",
            body=gateway_body(
                GOOGLE_PLAY_CHANNEL,
                user_id=user_id,
                product_id=PRO_YEARLY_PRODUCT_ID,
                transaction_id="bol-deterministic-expired",
                status="expired",
                eventTime="2026-06-27T10:00:00Z",
            ),
            app=app,
        )
        events = app.gateway_service.event_store.get_events(user_id)

        normal = app.gateway_service.replay_engine.replay(
            user_id,
            update_projection=False,
            events=events,
        )
        shuffled = app.gateway_service.replay_engine.replay(
            user_id,
            update_projection=False,
            events=list(reversed(events)),
        )

        self.assertEqual(
            [explanation.to_dict() for explanation in normal.explanations],
            [explanation.to_dict() for explanation in shuffled.explanations],
        )

    def test_bol_event_trace_is_complete_and_internal_explain_apis_return_chain(self):
        app = self._app_with_gateway(internal_entitlement_token="internal-token")
        user_id = "user-bol-trace"
        self.request(
            "POST",
            "/iap/webhooks/google_play",
            body=gateway_body(
                GOOGLE_PLAY_CHANNEL,
                user_id=user_id,
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="bol-trace-active",
                eventTime="2026-06-26T10:00:00Z",
            ),
            app=app,
        )
        self.request(
            "POST",
            "/iap/webhooks/google_play",
            body=gateway_body(
                GOOGLE_PLAY_CHANNEL,
                user_id=user_id,
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="bol-trace-renew",
                eventType="RENEW",
                eventTime="2026-06-27T10:00:00Z",
            ),
            app=app,
        )

        coverage = app.gateway_service.explanation_coverage_report(user_id)
        status, body = self.request(
            "GET",
            f"/internal/v3/billing/explain/{user_id}",
            app=app,
            headers={"Authorization": "Bearer internal-token"},
        )
        event_id = app.gateway_service.event_store.get_events(user_id)[0].event_id
        event_status, event_body = self.request(
            "GET",
            f"/internal/v3/billing/explain/event/{event_id}",
            app=app,
            headers={"Authorization": "Bearer internal-token"},
        )

        self.assertEqual(coverage["events_with_explanation_percent"], 100.0)
        self.assertEqual(coverage["missing_explanation_list"], [])
        self.assertEqual(status, 200)
        self.assertEqual(body["user_id"], user_id)
        self.assertEqual(body["current_state"], STATE_ACTIVE)
        self.assertEqual(len(body["event_explanations"]), 2)
        self.assertEqual(len(body["decision_trace"]), 2)
        self.assertEqual(body["explanation_coverage_report"]["missing_explanation_list"], [])
        self.assertIn("Rule applied", body["latest_reason"])
        self.assertEqual(event_status, 200)
        self.assertEqual(event_body["event_id"], event_id)
        self.assertEqual(
            [step["stage"] for step in event_body["decision_chain"]],
            ["event", "authority", "ordering", "state_machine", "entitlement_engine"],
        )

    def test_bol_explain_apis_require_internal_service_token(self):
        app = self._app_with_gateway(internal_entitlement_token="internal-token")

        missing_status, missing_body = self.request(
            "GET",
            "/internal/v3/billing/explain/user-bol-auth",
            app=app,
        )
        client_status, client_body = self.request(
            "GET",
            "/internal/v3/billing/explain/user-bol-auth",
            app=app,
            headers={"Authorization": "Bearer login-token-a"},
        )

        self.assertEqual(missing_status, 401)
        self.assertEqual(missing_body["error"]["code"], "unauthorized")
        self.assertEqual(client_status, 401)
        self.assertEqual(client_body["error"]["code"], "unauthorized")

    def test_bol_explain_api_does_not_leak_purchase_token_or_signature(self):
        app = self._app_with_gateway(internal_entitlement_token="internal-token")
        user_id = "user-bol-sensitive"
        purchase_token = "google-purchase-token-secret-001"
        webhook_body = {
            "channel": GOOGLE_PLAY_CHANNEL,
            "user_id": user_id,
            "product_id": MAX_YEARLY_PRODUCT_ID,
            "purchaseToken": purchase_token,
            "status": "active",
            "eventTime": "2026-06-26T10:00:00Z",
        }
        signature = signature_for_payload(webhook_body, gateway_secrets()[GOOGLE_PLAY_CHANNEL])
        webhook_body["signature"] = signature
        self.request(
            "POST",
            "/iap/webhooks/google_play",
            body=webhook_body,
            app=app,
        )

        user_status, user_body = self.request(
            "GET",
            f"/internal/v3/billing/explain/{user_id}",
            app=app,
            headers={"Authorization": "Bearer internal-token"},
        )
        event_id = app.gateway_service.event_store.get_events(user_id)[0].event_id
        event_status, event_body = self.request(
            "GET",
            f"/internal/v3/billing/explain/event/{event_id}",
            app=app,
            headers={"Authorization": "Bearer internal-token"},
        )
        serialized = json.dumps(
            {"user": user_body, "event": event_body},
            sort_keys=True,
            separators=(",", ":"),
        )

        self.assertEqual(user_status, 200)
        self.assertEqual(event_status, 200)
        self.assertNotIn(purchase_token, serialized)
        self.assertNotIn(signature, serialized)
        self.assertNotIn("purchaseToken", serialized)
        self.assertNotIn("transaction_id", serialized)
        self.assertNotIn("transactionId", serialized)
        self.assertNotIn("signature", serialized)

    def test_bol_explain_api_does_not_mutate_billing_state(self):
        app = self._app_with_gateway(internal_entitlement_token="internal-token")
        user_id = "user-bol-read-only"
        self.request(
            "POST",
            "/iap/webhooks/oppo",
            body=gateway_body(
                OPPO_CHANNEL,
                user_id=user_id,
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="bol-read-only-active",
                eventTime="2026-06-26T10:00:00Z",
            ),
            app=app,
        )
        events_before = [
            event.to_dict() for event in app.gateway_service.event_store.get_events(user_id)
        ]
        state_before = app.store.get_subscription_state(user_id, MAX_YEARLY_PRODUCT_ID)
        entitlement_before = app.store.get_latest_entitlement_for_user(user_id)
        projection_before = app.store.get_entitlement_projection(user_id)

        status, _ = self.request(
            "GET",
            f"/internal/v3/billing/explain/{user_id}",
            app=app,
            headers={"Authorization": "Bearer internal-token"},
        )

        events_after = [
            event.to_dict() for event in app.gateway_service.event_store.get_events(user_id)
        ]
        state_after = app.store.get_subscription_state(user_id, MAX_YEARLY_PRODUCT_ID)
        entitlement_after = app.store.get_latest_entitlement_for_user(user_id)
        projection_after = app.store.get_entitlement_projection(user_id)
        self.assertEqual(status, 200)
        self.assertEqual(events_after, events_before)
        self.assertEqual(state_after, state_before)
        self.assertEqual(entitlement_after.to_response_body(), entitlement_before.to_response_body())
        self.assertEqual(projection_after, projection_before)

    def test_bol_explanation_store_is_append_only(self):
        app = self._app_with_gateway()
        user_id = "user-bol-append-only"
        self.request(
            "POST",
            "/iap/webhooks/oppo",
            body=gateway_body(
                OPPO_CHANNEL,
                user_id=user_id,
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="bol-append-only-active",
                eventTime="2026-06-26T10:00:00Z",
            ),
            app=app,
        )
        event = app.gateway_service.event_store.get_events(user_id)[0]

        with closing(sqlite3.connect(app.store.db_path)) as conn:
            with self.assertRaises(sqlite3.DatabaseError):
                conn.execute(
                    """
                    UPDATE iap_subscription_event_explanations
                    SET explanation_json = ?
                    WHERE event_id = ?
                    """,
                    ("{}", event.event_id),
                )
            conn.rollback()
            with self.assertRaises(sqlite3.DatabaseError):
                conn.execute(
                    "DELETE FROM iap_subscription_event_explanations WHERE event_id = ?",
                    (event.event_id,),
                )

    def test_scp_v3_hash_chain_tamper_detection(self):
        app = self._app_with_gateway()
        user_id = "user-ledger-v3-tamper"
        self.request(
            "POST",
            "/iap/webhooks/google_play",
            body=gateway_body(
                GOOGLE_PLAY_CHANNEL,
                user_id=user_id,
                product_id=PRO_YEARLY_PRODUCT_ID,
                transaction_id="ledger-v3-tamper-active",
                eventTime="2026-06-26T10:00:00Z",
            ),
            app=app,
        )
        verifier = IntegrityVerifier(app.gateway_service.event_store)

        valid = verifier.verify_user_chain(user_id)
        self.assertTrue(valid.chain_valid)
        self.assertFalse(valid.tamper_detected)
        self.assertEqual(valid.final_verdict, FINAL_VERDICT_VERIFIED)

        _tamper_event_payload(
            app.store.db_path,
            "ledger-v3-tamper-active",
            normalizedStatus="expired",
        )
        compromised = verifier.verify_user_chain(user_id)

        self.assertFalse(compromised.chain_valid)
        self.assertTrue(compromised.tamper_detected)
        self.assertEqual(compromised.broken_event_index, 0)
        self.assertEqual(compromised.final_verdict, FINAL_VERDICT_COMPROMISED)
        with self.assertRaises(SubscriptionLedgerIntegrityError):
            app.gateway_service.event_store.get_events(user_id)

    def test_scp_v3_insertion_attack_breaks_hash_chain(self):
        app = self._app_with_gateway()
        user_id = "user-ledger-v3-insert"
        self.request(
            "POST",
            "/iap/webhooks/oppo",
            body=gateway_body(
                OPPO_CHANNEL,
                user_id=user_id,
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="ledger-v3-insert-active",
                eventTime="2026-06-26T10:00:00Z",
            ),
            app=app,
        )
        self.request(
            "POST",
            "/iap/webhooks/oppo",
            body=gateway_body(
                OPPO_CHANNEL,
                user_id=user_id,
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="ledger-v3-insert-expired",
                status="expired",
                eventTime="2026-06-27T10:00:00Z",
            ),
            app=app,
        )

        _insert_middle_subscription_event(app.store.db_path, user_id)
        report = IntegrityVerifier(app.gateway_service.event_store).verify_user_chain(user_id)

        self.assertFalse(report.chain_valid)
        self.assertTrue(report.tamper_detected)
        self.assertEqual(report.broken_event_index, 2)
        with self.assertRaises(SubscriptionLedgerIntegrityError):
            app.gateway_service.replay_engine.replay(user_id, update_projection=False)

    def test_scp_v3_replay_integrity_validation_blocks_broken_chain(self):
        app = self._app_with_gateway()
        user_id = "user-ledger-v3-replay"
        self.request(
            "POST",
            "/iap/webhooks/xiaomi",
            body=gateway_body(
                XIAOMI_CHANNEL,
                user_id=user_id,
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="ledger-v3-replay-active",
                eventTime="2026-06-26T10:00:00Z",
            ),
            app=app,
        )

        replayed = app.gateway_service.replay_engine.replay(user_id, update_projection=True)
        self.assertEqual(replayed.current_entitlement.outcome, "verifiedActiveMax")
        self.assertIn("CACHE ONLY", PROJECTION_CACHE_ONLY_NOTICE)

        _corrupt_current_event_hash(app.store.db_path, "ledger-v3-replay-active")

        with self.assertRaises(SubscriptionLedgerIntegrityError):
            app.gateway_service.replay_engine.replay(user_id, update_projection=True)

    def test_scp_v3_silent_corruption_detection(self):
        app = self._app_with_gateway()
        user_id = "user-ledger-v3-corruption"
        self.request(
            "POST",
            "/iap/webhooks/vivo",
            body=gateway_body(
                VIVO_CHANNEL,
                user_id=user_id,
                product_id=PRO_YEARLY_PRODUCT_ID,
                transaction_id="ledger-v3-corruption-active",
                eventTime="2026-06-26T10:00:00Z",
            ),
            app=app,
        )

        _corrupt_current_event_hash(app.store.db_path, "ledger-v3-corruption-active")
        report = IntegrityVerifier(app.gateway_service.event_store).verify_global_ledger()

        self.assertFalse(report.chain_valid)
        self.assertTrue(report.tamper_detected)
        self.assertEqual(report.broken_user_id, user_id)
        self.assertEqual(report.final_verdict, FINAL_VERDICT_COMPROMISED)

    def test_scp_v3_global_ledger_detects_forged_new_user_genesis(self):
        app = self._app_with_gateway()
        self.request(
            "POST",
            "/iap/webhooks/vivo",
            body=gateway_body(
                VIVO_CHANNEL,
                user_id="user-ledger-v3-global-seed",
                product_id=PRO_YEARLY_PRODUCT_ID,
                transaction_id="ledger-v3-global-seed-active",
                eventTime="2026-06-26T10:00:00Z",
            ),
            app=app,
        )

        _insert_forged_new_user_genesis(app.store.db_path)
        report = IntegrityVerifier(app.gateway_service.event_store).verify_global_ledger()

        self.assertFalse(report.chain_valid)
        self.assertTrue(report.tamper_detected)
        self.assertEqual(report.broken_user_id, "user-ledger-v3-forged-new")
        self.assertEqual(report.broken_event_index, 1)

    def test_scp_v3_reconciliation_aborts_when_ledger_integrity_invalid(self):
        app = self._app_with_gateway()
        user_id = "user-ledger-v3-reconcile"
        self.request(
            "POST",
            "/iap/webhooks/oppo",
            body=gateway_body(
                OPPO_CHANNEL,
                user_id=user_id,
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="ledger-v3-reconcile-active",
                eventTime="2026-06-26T10:00:00Z",
            ),
            app=app,
        )
        before_events = app.gateway_service.event_store.get_events_unchecked(user_id)
        _tamper_event_payload(
            app.store.db_path,
            "ledger-v3-reconcile-active",
            latestTransactionId="ledger-v3-reconcile-forged",
        )
        worker = SubscriptionReconciliationWorker(
            store=app.store,
            provider_verifiers={
                OPPO_CHANNEL: FixedProviderVerifier(
                    ProviderSubscriptionState(
                        state=STATE_EXPIRED,
                        channel=OPPO_CHANNEL,
                        transaction_id="ledger-v3-reconcile-correction",
                        event_time="2026-06-27T12:00:00Z",
                    )
                )
            },
            entitlement_engine=EntitlementEngine(app.store, DEFAULT_ALLOWED_PRODUCTS),
        )

        with self.assertRaises(SubscriptionLedgerIntegrityError):
            worker.reconcile_active_entitlements(system_job=True)

        after_events = app.gateway_service.event_store.get_events_unchecked(user_id)
        self.assertEqual(len(after_events), len(before_events))
        self.assertEqual(
            app.store.get_subscription_state(user_id, MAX_YEARLY_PRODUCT_ID).state,
            STATE_ACTIVE,
        )

    def test_rbl_legacy_handler_write_uses_gateway_context(self):
        app = self._app_with_authenticator()
        contexts = []
        original_execute_write = app.store.execute_write

        def spy_execute_write(conn, sql, parameters=(), *, table_name, operation, context=None):
            active_context = context or RuntimeWriteFirewall.current_context()
            if table_name in {"iap_entitlements", "iap_subscription_state"}:
                contexts.append(
                    (None if active_context is None else active_context.source, table_name, operation)
                )
            return original_execute_write(
                conn,
                sql,
                parameters,
                table_name=table_name,
                operation=operation,
                context=context,
            )

        app.store.execute_write = spy_execute_write
        original_commit = app.gateway_service.commit_legacy_apple_record

        with mock.patch.object(
            app.gateway_service,
            "commit_legacy_apple_record",
            wraps=original_commit,
        ) as commit_spy:
            status, body = self.verify_purchase(
                "fake:max-active",
                MAX_TOKEN,
                MAX_YEARLY_PRODUCT_ID,
                app=app,
                authorization="Bearer login-token-a",
            )

        self.assertEqual(status, 200)
        self.assertTrue(commit_spy.called)
        self.assert_contract_response(body, "verifiedActiveMax", "max")
        self.assertTrue(contexts)
        self.assertEqual({source for source, _, _ in contexts}, {"subscription_replay_engine.py"})
        self.assertEqual(app.store.get_entitlement(MAX_TOKEN).user_id, "user-a")

    def test_pwpi_import_bypass_attempt_fails(self):
        with self.assertRaisesRegex(RuntimeError, "forbidden storage import"):
            __import__("storage")

    def test_rbl_storage_direct_entitlement_write_is_blocked_and_audited(self):
        record = EntitlementRecord(
            outcome="verifiedActivePro",
            entitlement_tier="pro",
            product_id=PRO_YEARLY_PRODUCT_ID,
            app_account_token="00000000-0000-4000-8000-000000009001",
            original_transaction_id="rbl-storage-direct-original",
            latest_transaction_id="rbl-storage-direct-latest",
            environment="Sandbox",
            expires_at="2099-01-01T00:00:00.000Z",
        )

        with self.assertRaisesRegex(RblViolation, "RBL VIOLATION"):
            self.store.upsert_entitlement(record, user_id="user-rbl-direct")

        self.assertIsNone(self.store.get_entitlement(record.app_account_token))
        violations = self.store.list_subscription_audit_log(RBL_VIOLATION_LOG)
        self.assertEqual(len(violations), 1)
        self.assertEqual(violations[0]["reason"], "rbl_blocked_upsert_entitlement_iap_entitlements")

    def test_pwpi_direct_sql_execution_without_gateway_fails(self):
        token = "00000000-0000-4000-8000-000000009002"
        with closing(sqlite3.connect(self.store.db_path)) as conn:
            with self.assertRaises(sqlite3.DatabaseError):
                conn.execute(
                    """
                    INSERT INTO iap_entitlements (
                      app_account_token, entitlement_tier, original_transaction_id,
                      latest_transaction_id, product_id, environment, expires_at,
                      revoked_at, outcome, updated_at, user_id
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        token,
                        "pro",
                        "rbl-db-direct-original",
                        "rbl-db-direct-latest",
                        PRO_YEARLY_PRODUCT_ID,
                        "Sandbox",
                        "2099-01-01T00:00:00.000Z",
                        None,
                        "verifiedActivePro",
                        "2026-06-27T00:00:00.000Z",
                        "user-rbl-db-direct",
                    ),
                )

        self.assertIsNone(self.store.get_entitlement(token))

    def test_pwpi_dbgateway_execute_write_without_context_is_blocked_and_audited(self):
        token = "00000000-0000-4000-8000-000000009003"
        with closing(sqlite3.connect(self.store.db_path)) as conn:
            with self.assertRaisesRegex(RblViolation, "RBL VIOLATION"):
                self.store.execute_write(
                    conn,
                    """
                    INSERT INTO iap_entitlements (
                      app_account_token, entitlement_tier, original_transaction_id,
                      latest_transaction_id, product_id, environment, expires_at,
                      revoked_at, outcome, updated_at, user_id
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        token,
                        "pro",
                        "rbl-dbgateway-direct-original",
                        "rbl-dbgateway-direct-latest",
                        PRO_YEARLY_PRODUCT_ID,
                        "Sandbox",
                        "2099-01-01T00:00:00.000Z",
                        None,
                        "verifiedActivePro",
                        "2026-06-27T00:00:00.000Z",
                        "user-rbl-dbgateway-direct",
                    ),
                    table_name="iap_entitlements",
                    operation="direct_sql_attempt",
                )

        self.assertIsNone(self.store.get_entitlement(token))
        violations = self.store.list_subscription_audit_log(RBL_VIOLATION_LOG)
        self.assertEqual(len(violations), 1)
        self.assertEqual(violations[0]["reason"], "rbl_blocked_execute_write_iap_entitlements")

    def test_pwpi_fake_system_job_injection_is_rejected(self):
        record = EntitlementRecord(
            outcome="verifiedActivePro",
            entitlement_tier="pro",
            product_id=PRO_YEARLY_PRODUCT_ID,
            app_account_token="00000000-0000-4000-8000-000000009004",
            original_transaction_id="rbl-fake-system-original",
            latest_transaction_id="rbl-fake-system-latest",
            environment="Sandbox",
            expires_at="2099-01-01T00:00:00.000Z",
        )
        forged_context = RuntimeWriteContext(
            source="subscription_reconciliation_worker.py",
            operation="forged_reconciliation_repair",
            actor="reconciliation_worker",
            user_id="user-rbl-fake-system",
            product_id=PRO_YEARLY_PRODUCT_ID,
            transaction_id="rbl-fake-system-latest",
            system_job=True,
        )

        with self.assertRaisesRegex(RblViolation, "RBL VIOLATION"):
            self.store.upsert_entitlement(
                record,
                user_id="user-rbl-fake-system",
                write_context=forged_context,
            )

        self.assertIsNone(self.store.get_entitlement(record.app_account_token))

    def test_rbl_gateway_write_is_allowed(self):
        app = self._app_with_gateway()

        status, body = self.request(
            "POST",
            "/iap/webhooks/google_play",
            body=gateway_body(
                GOOGLE_PLAY_CHANNEL,
                user_id="user-rbl-gateway",
                product_id=PRO_YEARLY_PRODUCT_ID,
                transaction_id="rbl-gateway-tx-1",
            ),
            app=app,
        )

        self.assertEqual(status, 200)
        self.assertEqual(body["gatewayStatus"], "applied")
        self.assertEqual(
            app.store.get_latest_entitlement_for_user("user-rbl-gateway").entitlement_tier,
            "pro",
        )
        self.assertEqual(app.store.list_subscription_audit_log(RBL_VIOLATION_LOG), [])

    def test_rbl_reconciliation_requires_system_job_flag(self):
        app = self._app_with_gateway()
        user_id = "user-rbl-reconcile"
        self.request(
            "POST",
            "/iap/webhooks/oppo",
            body=gateway_body(
                OPPO_CHANNEL,
                user_id=user_id,
                product_id=MAX_YEARLY_PRODUCT_ID,
                transaction_id="rbl-reconcile-initial",
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
                        transaction_id="rbl-reconcile-provider",
                        event_time="2026-06-27T12:00:00Z",
                    )
                )
            },
            entitlement_engine=EntitlementEngine(app.store, DEFAULT_ALLOWED_PRODUCTS),
        )

        with self.assertRaisesRegex(RblViolation, "RBL VIOLATION"):
            worker.reconcile_active_entitlements()
        state_after_block = app.store.get_subscription_state(user_id, MAX_YEARLY_PRODUCT_ID)
        self.assertEqual(state_after_block.state, STATE_ACTIVE)
        self.assertEqual(len(app.store.list_subscription_audit_log(RBL_VIOLATION_LOG)), 1)

        result = worker.reconcile_active_entitlements(system_job=True)

        state_after_job = app.store.get_subscription_state(user_id, MAX_YEARLY_PRODUCT_ID)
        self.assertEqual(result["repaired"], 1)
        self.assertEqual(state_after_job.state, STATE_GRACE)

    def test_rbl_authority_state_cannot_be_bypassed_by_direct_storage_write(self):
        app = self._app_with_gateway()
        user_id = "user-rbl-authority"
        status, _ = self.request(
            "POST",
            "/iap/webhooks/xiaomi",
            body=gateway_body(
                XIAOMI_CHANNEL,
                user_id=user_id,
                product_id=PRO_YEARLY_PRODUCT_ID,
                transaction_id="rbl-authority-high",
                source="webhook",
                eventTime="2026-06-26T12:00:00Z",
            ),
            app=app,
        )
        self.assertEqual(status, 200)
        downgrade = EntitlementRecord(
            outcome="expired",
            entitlement_tier="none",
            product_id=PRO_YEARLY_PRODUCT_ID,
            app_account_token="gateway:attempted-rbl-bypass",
            original_transaction_id="rbl-bypass-original",
            latest_transaction_id="rbl-bypass-latest",
            environment=XIAOMI_CHANNEL,
            expires_at="2020-01-01T00:00:00.000Z",
        )

        with self.assertRaisesRegex(RblViolation, "RBL VIOLATION"):
            app.store.upsert_entitlement(downgrade, user_id=user_id)

        entitlement = app.store.get_latest_entitlement_for_user(user_id)
        state = app.store.get_subscription_state(user_id, PRO_YEARLY_PRODUCT_ID)
        self.assertEqual(entitlement.outcome, "verifiedActivePro")
        self.assertEqual(state.state, STATE_ACTIVE)

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


def _tamper_event_payload(db_path, transaction_id, **updates):
    _drop_subscription_event_guards(db_path)
    with closing(sqlite3.connect(db_path)) as conn:
        with conn:
            row = conn.execute(
                """
                SELECT raw_payload_json
                FROM iap_subscription_events
                WHERE transaction_id = ?
                """,
                (transaction_id,),
            ).fetchone()
            payload = json.loads(row[0])
            payload.update(updates)
            conn.execute(
                """
                UPDATE iap_subscription_events
                SET raw_payload_json = ?
                WHERE transaction_id = ?
                """,
                (_canonical_json(payload), transaction_id),
            )


def _corrupt_current_event_hash(db_path, transaction_id):
    _drop_subscription_event_guards(db_path)
    with closing(sqlite3.connect(db_path)) as conn:
        with conn:
            conn.execute(
                """
                UPDATE iap_subscription_events
                SET current_event_hash = ?
                WHERE transaction_id = ?
                """,
                ("f" * 64, transaction_id),
            )


def _insert_middle_subscription_event(db_path, user_id):
    _drop_subscription_event_guards(db_path)
    with closing(sqlite3.connect(db_path)) as conn:
        conn.row_factory = sqlite3.Row
        with conn:
            rows = conn.execute(
                """
                SELECT *
                FROM iap_subscription_events
                WHERE user_id = ?
                ORDER BY event_id ASC
                """,
                (user_id,),
            ).fetchall()
            first = rows[0]
            second = rows[1]
            inserted_event_id = int(second["event_id"])
            conn.execute(
                """
                UPDATE iap_subscription_events
                SET event_id = ?
                WHERE event_id = ?
                """,
                (inserted_event_id + 1, inserted_event_id),
            )
            payload = {
                "appAccountToken": "gateway:inserted-event",
                "eventType": "RENEW",
                "normalizedStatus": "active",
                "originalTransactionId": "ledger-v3-insert-forged-original",
                "latestTransactionId": "ledger-v3-insert-forged",
                "environment": str(first["channel"]),
                "source": "forged_middle_insert",
            }
            previous_hash = str(first["current_event_hash"])
            payload_digest = _payload_hash(payload)
            forged_event = SubscriptionEvent(
                event_id=inserted_event_id,
                user_id=str(first["user_id"]),
                product_id=str(first["product_id"]),
                channel=str(first["channel"]),
                event_type="RENEW",
                authority_score=int(first["authority_score"]),
                event_time="2026-06-26T12:00:00Z",
                server_time="2026-06-26T12:00:00Z",
                payload_hash=payload_digest,
                transaction_id="ledger-v3-insert-forged",
                raw_payload=payload,
                source="forged_middle_insert",
                event_version=None,
                previous_event_hash=previous_hash,
            )
            current_hash = EventHashChain.compute_hash(forged_event, previous_hash)
            conn.execute(
                """
                INSERT INTO iap_subscription_events (
                  event_id, user_id, product_id, channel, event_type,
                  authority_score, event_time, server_time, payload_hash,
                  transaction_id, source, event_version, raw_payload_json,
                  previous_event_hash, current_event_hash
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    inserted_event_id,
                    forged_event.user_id,
                    forged_event.product_id,
                    forged_event.channel,
                    forged_event.event_type,
                    forged_event.authority_score,
                    forged_event.event_time,
                    forged_event.server_time,
                    forged_event.payload_hash,
                    forged_event.transaction_id,
                    forged_event.source,
                    forged_event.event_version,
                    _canonical_json(payload),
                    previous_hash,
                    current_hash,
                ),
            )


def _insert_forged_new_user_genesis(db_path):
    _drop_subscription_event_guards(db_path)
    payload = {
        "appAccountToken": "gateway:forged-new-user",
        "eventType": "PURCHASE",
        "normalizedStatus": "active",
        "originalTransactionId": "ledger-v3-forged-new-original",
        "latestTransactionId": "ledger-v3-forged-new",
        "environment": VIVO_CHANNEL,
        "source": "forged_new_user_genesis",
    }
    previous_hash = "0" * 64
    payload_digest = _payload_hash(payload)
    forged_event = SubscriptionEvent(
        event_id=0,
        user_id="user-ledger-v3-forged-new",
        product_id=PRO_YEARLY_PRODUCT_ID,
        channel=VIVO_CHANNEL,
        event_type="PURCHASE",
        authority_score=100,
        event_time="2026-06-26T12:00:00Z",
        server_time="2026-06-26T12:00:00Z",
        payload_hash=payload_digest,
        transaction_id="ledger-v3-forged-new",
        raw_payload=payload,
        source="forged_new_user_genesis",
        event_version=None,
        previous_event_hash=previous_hash,
    )
    current_hash = EventHashChain.compute_hash(forged_event, previous_hash)
    with closing(sqlite3.connect(db_path)) as conn:
        with conn:
            conn.execute(
                """
                INSERT INTO iap_subscription_events (
                  user_id, product_id, channel, event_type,
                  authority_score, event_time, server_time, payload_hash,
                  transaction_id, source, event_version, raw_payload_json,
                  previous_event_hash, current_event_hash
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    forged_event.user_id,
                    forged_event.product_id,
                    forged_event.channel,
                    forged_event.event_type,
                    forged_event.authority_score,
                    forged_event.event_time,
                    forged_event.server_time,
                    forged_event.payload_hash,
                    forged_event.transaction_id,
                    forged_event.source,
                    forged_event.event_version,
                    _canonical_json(payload),
                    previous_hash,
                    current_hash,
                ),
            )


def _drop_subscription_event_guards(db_path):
    with closing(sqlite3.connect(db_path)) as conn:
        with conn:
            for trigger_name in (
                "guard_iap_subscription_events_insert",
                "prevent_iap_subscription_events_update",
                "prevent_iap_subscription_events_delete",
            ):
                conn.execute(f"DROP TRIGGER IF EXISTS {trigger_name}")


def _payload_hash(payload):
    return hashlib.sha256(_canonical_json(payload).encode("utf-8")).hexdigest()


def _canonical_json(payload):
    return json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


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
