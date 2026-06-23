from __future__ import annotations

import sys
import unittest
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

from app import (  # noqa: E402
    APPLE_STATUS_ACTIVE,
    APPLE_STATUS_BILLING_GRACE_PERIOD,
    APPLE_STATUS_BILLING_RETRY,
    APPLE_STATUS_EXPIRED,
    APPLE_STATUS_REVOKED,
    ENVIRONMENT_PRODUCTION,
    ENVIRONMENT_SANDBOX,
    MAX_YEARLY_PRODUCT_ID,
    PRO_YEARLY_PRODUCT_ID,
    AppleSubscriptionStatusItem,
    AppStoreServerAppleVerifier,
    DecodedAppleRenewalInfo,
    DecodedAppleTransaction,
    PurchaseVerificationRequest,
)
from verifier import AppleVerificationFailed, AppleVerificationUnavailable  # noqa: E402


APP_TOKEN = "00000000-0000-4000-8000-000000000777"
BUNDLE_ID = "com.yuyuan.assetledger"


class AppStoreServerAppleVerifierTestCase(unittest.TestCase):
    def test_maps_apple_statuses_to_contract_outcomes_and_tiers(self):
        cases = [
            (APPLE_STATUS_ACTIVE, PRO_YEARLY_PRODUCT_ID, "verifiedActivePro", "pro"),
            (APPLE_STATUS_ACTIVE, MAX_YEARLY_PRODUCT_ID, "verifiedActiveMax", "max"),
            (APPLE_STATUS_BILLING_GRACE_PERIOD, PRO_YEARLY_PRODUCT_ID, "verifiedGracePeriodPro", "pro"),
            (APPLE_STATUS_BILLING_GRACE_PERIOD, MAX_YEARLY_PRODUCT_ID, "verifiedGracePeriodMax", "max"),
            (APPLE_STATUS_BILLING_RETRY, PRO_YEARLY_PRODUCT_ID, "billingRetry", "none"),
            (APPLE_STATUS_EXPIRED, PRO_YEARLY_PRODUCT_ID, "expired", "none"),
            (APPLE_STATUS_REVOKED, PRO_YEARLY_PRODUCT_ID, "revoked", "none"),
        ]
        for status, product_id, outcome, tier in cases:
            with self.subTest(status=status, product_id=product_id):
                verifier, signed_verifier, _ = make_verifier(status=status, product_id=product_id)
                record = verifier.verify_purchase(purchase_request(product_id=product_id))

                self.assertEqual(record.outcome, outcome)
                self.assertEqual(record.entitlement_tier, tier)
                self.assertEqual(record.product_id, product_id)
                self.assertEqual(record.app_account_token, APP_TOKEN)
                self.assertEqual(record.original_transaction_id, "orig-1")
                self.assertEqual(record.latest_transaction_id, "txn-status")
                self.assertEqual(record.environment, ENVIRONMENT_SANDBOX)
                self.assertIn("request-jws", signed_verifier.verified_transactions)
                self.assertIn("status-jws", signed_verifier.verified_transactions)

    def test_grace_period_uses_renewal_grace_expiry_when_available(self):
        verifier, _, _ = make_verifier(
            status=APPLE_STATUS_BILLING_GRACE_PERIOD,
            renewal=DecodedAppleRenewalInfo(grace_period_expires_date_ms=4102531200000),
        )

        record = verifier.verify_purchase(purchase_request())

        self.assertEqual(record.outcome, "verifiedGracePeriodPro")
        self.assertEqual(record.expires_at, "2100-01-02T00:00:00.000Z")

    def test_revocation_date_overrides_active_status(self):
        verifier, _, _ = make_verifier(
            status=APPLE_STATUS_ACTIVE,
            status_transaction=transaction("txn-status", revocation_date_ms=1700000000000),
        )

        record = verifier.verify_purchase(purchase_request())

        self.assertEqual(record.outcome, "revoked")
        self.assertEqual(record.entitlement_tier, "none")
        self.assertEqual(record.revoked_at, "2023-11-14T22:13:20.000Z")

    def test_preserves_sandbox_and_production_environment(self):
        for environment in (ENVIRONMENT_SANDBOX, ENVIRONMENT_PRODUCTION):
            with self.subTest(environment=environment):
                verifier, _, status_client = make_verifier(
                    status=APPLE_STATUS_ACTIVE,
                    request_transaction=transaction("txn-request", environment=environment),
                    status_transaction=transaction("txn-status", environment=environment),
                )

                record = verifier.verify_purchase(purchase_request())

                self.assertEqual(record.environment, environment)
                self.assertEqual(status_client.calls, [("txn-request", environment)])

    def test_signed_transaction_verification_failure_is_definitive_failed(self):
        signed_verifier = FakeSignedPayloadVerifier(
            transactions={},
            transaction_failures={"request-jws": AppleVerificationFailed("bad signature")},
        )
        verifier = AppStoreServerAppleVerifier(
            allowed_products=(PRO_YEARLY_PRODUCT_ID, MAX_YEARLY_PRODUCT_ID),
            bundle_id=BUNDLE_ID,
            signed_payload_verifier=signed_verifier,
            subscription_status_client=FakeSubscriptionStatusClient({}),
        )

        with self.assertRaises(AppleVerificationFailed):
            verifier.verify_purchase(purchase_request())

    def test_library_internal_verifier_error_is_unavailable(self):
        signed_verifier = FakeSignedPayloadVerifier(
            transactions={},
            transaction_failures={"request-jws": RuntimeError("decoder crashed")},
        )
        verifier = AppStoreServerAppleVerifier(
            allowed_products=(PRO_YEARLY_PRODUCT_ID, MAX_YEARLY_PRODUCT_ID),
            bundle_id=BUNDLE_ID,
            signed_payload_verifier=signed_verifier,
            subscription_status_client=FakeSubscriptionStatusClient({}),
        )

        with self.assertRaises(AppleVerificationUnavailable):
            verifier.verify_purchase(purchase_request())

    def test_apple_api_outage_is_unavailable(self):
        signed_verifier = FakeSignedPayloadVerifier(
            transactions={"request-jws": transaction("txn-request")},
        )
        verifier = AppStoreServerAppleVerifier(
            allowed_products=(PRO_YEARLY_PRODUCT_ID, MAX_YEARLY_PRODUCT_ID),
            bundle_id=BUNDLE_ID,
            signed_payload_verifier=signed_verifier,
            subscription_status_client=FakeSubscriptionStatusClient(
                {},
                failure=AppleVerificationUnavailable("network timeout"),
            ),
        )

        with self.assertRaises(AppleVerificationUnavailable):
            verifier.verify_purchase(purchase_request())

    def test_status_signed_transaction_must_be_verified_before_mapping(self):
        signed_verifier = FakeSignedPayloadVerifier(
            transactions={"request-jws": transaction("txn-request")},
            transaction_failures={"status-jws": AppleVerificationFailed("status signature failed")},
        )
        status_client = FakeSubscriptionStatusClient(
            {
                "txn-request": [
                    AppleSubscriptionStatusItem(
                        status=APPLE_STATUS_ACTIVE,
                        original_transaction_id="orig-1",
                        signed_transaction_info="status-jws",
                    )
                ]
            }
        )
        verifier = AppStoreServerAppleVerifier(
            allowed_products=(PRO_YEARLY_PRODUCT_ID, MAX_YEARLY_PRODUCT_ID),
            bundle_id=BUNDLE_ID,
            signed_payload_verifier=signed_verifier,
            subscription_status_client=status_client,
        )

        with self.assertRaises(AppleVerificationFailed):
            verifier.verify_purchase(purchase_request())

        self.assertEqual(signed_verifier.verified_transactions, ["request-jws", "status-jws"])

    def test_unknown_product_from_signed_payload_is_rejected(self):
        signed_verifier = FakeSignedPayloadVerifier(
            transactions={
                "request-jws": transaction("txn-request", product_id="com.yuyuan.assetledger.legacy.monthly"),
            },
        )
        verifier = AppStoreServerAppleVerifier(
            allowed_products=(PRO_YEARLY_PRODUCT_ID, MAX_YEARLY_PRODUCT_ID),
            bundle_id=BUNDLE_ID,
            signed_payload_verifier=signed_verifier,
            subscription_status_client=FakeSubscriptionStatusClient({}),
        )

        with self.assertRaises(AppleVerificationFailed):
            verifier.verify_purchase(purchase_request(product_id="com.yuyuan.assetledger.legacy.monthly"))


def make_verifier(
    *,
    status,
    product_id=PRO_YEARLY_PRODUCT_ID,
    request_transaction=None,
    status_transaction=None,
    renewal=None,
):
    request_transaction = request_transaction or transaction("txn-request", product_id=product_id)
    status_transaction = status_transaction or transaction("txn-status", product_id=product_id)
    signed_verifier = FakeSignedPayloadVerifier(
        transactions={
            "request-jws": request_transaction,
            "status-jws": status_transaction,
        },
        renewals={"renewal-jws": renewal or DecodedAppleRenewalInfo()},
    )
    status_client = FakeSubscriptionStatusClient(
        {
            request_transaction.transaction_id: [
                AppleSubscriptionStatusItem(
                    status=status,
                    original_transaction_id=status_transaction.original_transaction_id,
                    signed_transaction_info="status-jws",
                    signed_renewal_info="renewal-jws",
                )
            ]
        }
    )
    verifier = AppStoreServerAppleVerifier(
        allowed_products=(PRO_YEARLY_PRODUCT_ID, MAX_YEARLY_PRODUCT_ID),
        bundle_id=BUNDLE_ID,
        signed_payload_verifier=signed_verifier,
        subscription_status_client=status_client,
    )
    return verifier, signed_verifier, status_client


def transaction(
    transaction_id,
    *,
    product_id=PRO_YEARLY_PRODUCT_ID,
    environment=ENVIRONMENT_SANDBOX,
    revocation_date_ms=None,
):
    return DecodedAppleTransaction(
        original_transaction_id="orig-1",
        transaction_id=transaction_id,
        product_id=product_id,
        bundle_id=BUNDLE_ID,
        app_account_token=APP_TOKEN,
        environment=environment,
        expires_date_ms=4102444800000,
        revocation_date_ms=revocation_date_ms,
    )


def purchase_request(product_id=PRO_YEARLY_PRODUCT_ID):
    return PurchaseVerificationRequest(
        platform="ios",
        product_id=product_id,
        server_verification_data="request-jws",
        local_verification_data="local",
        source="app_store",
        status="purchased",
        app_account_token=APP_TOKEN,
        bundle_id=BUNDLE_ID,
    )


class FakeSignedPayloadVerifier:
    def __init__(self, *, transactions, renewals=None, transaction_failures=None):
        self.transactions = transactions
        self.renewals = renewals or {}
        self.transaction_failures = transaction_failures or {}
        self.verified_transactions = []
        self.verified_renewals = []

    def verify_transaction(self, signed_transaction):
        self.verified_transactions.append(signed_transaction)
        if signed_transaction in self.transaction_failures:
            raise self.transaction_failures[signed_transaction]
        if signed_transaction not in self.transactions:
            raise AppleVerificationFailed("missing signed transaction")
        return self.transactions[signed_transaction]

    def verify_renewal_info(self, signed_renewal_info, environment):
        self.verified_renewals.append((signed_renewal_info, environment))
        if signed_renewal_info not in self.renewals:
            raise AppleVerificationFailed("missing signed renewal info")
        return self.renewals[signed_renewal_info]


class FakeSubscriptionStatusClient:
    def __init__(self, statuses_by_transaction_id, failure=None):
        self.statuses_by_transaction_id = statuses_by_transaction_id
        self.failure = failure
        self.calls = []

    def get_all_subscription_statuses(self, any_transaction_id, environment):
        self.calls.append((any_transaction_id, environment))
        if self.failure is not None:
            raise self.failure
        return self.statuses_by_transaction_id.get(any_transaction_id, [])


if __name__ == "__main__":
    unittest.main()
