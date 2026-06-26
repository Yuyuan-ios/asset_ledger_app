from __future__ import annotations

import dataclasses
import hashlib
from typing import Any, Dict, Mapping, Optional, Protocol

from config import MAX_YEARLY_PRODUCT_ID, PRO_YEARLY_PRODUCT_ID


VALID_OUTCOMES = {
    "verifiedActivePro",
    "verifiedActiveMax",
    "verifiedGracePeriodPro",
    "verifiedGracePeriodMax",
    "billingRetry",
    "expired",
    "revoked",
    "verificationFailed",
    "verificationUnavailable",
    "noActiveEntitlement",
}
VALID_ENTITLEMENT_TIERS = {"pro", "max", "none"}
OUTCOME_TO_TIER = {
    "verifiedActivePro": "pro",
    "verifiedGracePeriodPro": "pro",
    "verifiedActiveMax": "max",
    "verifiedGracePeriodMax": "max",
    "billingRetry": "none",
    "expired": "none",
    "revoked": "none",
    "verificationFailed": "none",
    "verificationUnavailable": "none",
    "noActiveEntitlement": "none",
}
RESPONSE_FIELDS = {
    "outcome",
    "entitlementTier",
    "productId",
    "appAccountToken",
    "originalTransactionId",
    "expiresAt",
    "environment",
}


@dataclasses.dataclass(frozen=True)
class PurchaseVerificationRequest:
    platform: str
    product_id: str
    server_verification_data: str
    local_verification_data: str
    source: str
    status: str
    app_account_token: str
    purchase_id: Optional[str] = None
    transaction_date: Optional[str] = None
    bundle_id: Optional[str] = None


@dataclasses.dataclass(frozen=True)
class EntitlementRecord:
    outcome: str
    entitlement_tier: str
    app_account_token: str
    product_id: Optional[str] = None
    original_transaction_id: Optional[str] = None
    latest_transaction_id: Optional[str] = None
    environment: Optional[str] = None
    expires_at: Optional[str] = None
    revoked_at: Optional[str] = None
    updated_at: Optional[str] = None

    def __post_init__(self) -> None:
        if self.outcome not in VALID_OUTCOMES:
            raise ValueError(f"unknown outcome: {self.outcome}")
        if self.entitlement_tier not in VALID_ENTITLEMENT_TIERS:
            raise ValueError(f"unknown entitlement tier: {self.entitlement_tier}")
        expected_tier = OUTCOME_TO_TIER[self.outcome]
        if self.entitlement_tier != expected_tier:
            raise ValueError(f"{self.outcome} must map to entitlement tier {expected_tier}")

    def to_response_body(self) -> Dict[str, str]:
        body = {
            "outcome": self.outcome,
            "entitlementTier": self.entitlement_tier,
            "appAccountToken": self.app_account_token,
        }
        if self.product_id is not None:
            body["productId"] = self.product_id
        if self.original_transaction_id is not None:
            body["originalTransactionId"] = self.original_transaction_id
        if self.expires_at is not None:
            body["expiresAt"] = self.expires_at
        if self.environment is not None:
            body["environment"] = self.environment
        return body

    @classmethod
    def from_row(cls, row: Mapping[str, Any]) -> "EntitlementRecord":
        return cls(
            outcome=str(row["outcome"]),
            entitlement_tier=str(row["entitlement_tier"]),
            app_account_token=str(row["app_account_token"]),
            product_id=row["product_id"],
            original_transaction_id=row["original_transaction_id"],
            latest_transaction_id=row["latest_transaction_id"],
            environment=row["environment"],
            expires_at=row["expires_at"],
            revoked_at=row["revoked_at"],
            updated_at=row["updated_at"],
        )


class AppleVerificationUnavailable(Exception):
    pass


class AppleVerificationFailed(Exception):
    def __init__(
        self,
        message: str,
        *,
        has_transaction_app_account_token: bool | None = None,
        apple_verification_status: str | None = None,
        apple_verification_statuses: str | None = None,
    ):
        super().__init__(message)
        self.has_transaction_app_account_token = has_transaction_app_account_token
        self.apple_verification_status = apple_verification_status
        self.apple_verification_statuses = apple_verification_statuses


class AppleVerifier(Protocol):
    def verify_purchase(self, request: PurchaseVerificationRequest) -> EntitlementRecord:
        ...

    def refresh_current_entitlement(self, record: EntitlementRecord) -> EntitlementRecord:
        ...


class FakeAppleVerifier:
    """Deterministic test verifier for IAP-S1.

    The fake reads serverVerificationData tokens such as "fake:pro-active".
    It never calls Apple services and carries no production credentials.
    """

    _SCENARIO_TO_OUTCOME = {
        "fake:pro-active": ("verifiedActivePro", PRO_YEARLY_PRODUCT_ID, "2099-01-01T00:00:00.000Z", None),
        "fake:max-active": ("verifiedActiveMax", MAX_YEARLY_PRODUCT_ID, "2099-01-01T00:00:00.000Z", None),
        "fake:pro-grace": ("verifiedGracePeriodPro", PRO_YEARLY_PRODUCT_ID, "2099-01-01T00:00:00.000Z", None),
        "fake:max-grace": ("verifiedGracePeriodMax", MAX_YEARLY_PRODUCT_ID, "2099-01-01T00:00:00.000Z", None),
        "fake:billing-retry": ("billingRetry", PRO_YEARLY_PRODUCT_ID, "2099-01-01T00:00:00.000Z", None),
        "fake:expired": ("expired", PRO_YEARLY_PRODUCT_ID, "2020-01-01T00:00:00.000Z", None),
        "fake:revoked": ("revoked", PRO_YEARLY_PRODUCT_ID, "2020-01-01T00:00:00.000Z", "2020-01-02T00:00:00.000Z"),
    }

    def verify_purchase(self, request: PurchaseVerificationRequest) -> EntitlementRecord:
        scenario = request.server_verification_data.strip()
        if scenario == "fake:outage":
            raise AppleVerificationUnavailable("fake apple outage")
        if scenario == "fake:invalid":
            raise AppleVerificationFailed("fake invalid purchase")

        mapped = self._SCENARIO_TO_OUTCOME.get(scenario)
        if mapped is None:
            raise AppleVerificationFailed("unknown fake verification token")
        outcome, expected_product_id, expires_at, revoked_at = mapped
        if request.product_id != expected_product_id:
            raise AppleVerificationFailed("fake token does not match product id")
        digest = hashlib.sha256(f"{request.app_account_token}:{scenario}".encode("utf-8")).hexdigest()
        return EntitlementRecord(
            outcome=outcome,
            entitlement_tier=OUTCOME_TO_TIER[outcome],
            product_id=request.product_id,
            app_account_token=request.app_account_token,
            original_transaction_id=f"fake-original-{digest[:16]}",
            latest_transaction_id=request.purchase_id or f"fake-latest-{digest[16:32]}",
            environment="Sandbox",
            expires_at=expires_at,
            revoked_at=revoked_at,
        )

    def refresh_current_entitlement(self, record: EntitlementRecord) -> EntitlementRecord:
        return record


class AppleServerApiVerifierPlaceholder:
    """IAP-S2 seam for real Apple verification.

    This placeholder keeps the service bootable when credentials are absent.
    If wired in before S2 is implemented, it fail-closes as verificationUnavailable.
    """

    def verify_purchase(self, request: PurchaseVerificationRequest) -> EntitlementRecord:
        raise AppleVerificationUnavailable("apple verifier is not configured")

    def refresh_current_entitlement(self, record: EntitlementRecord) -> EntitlementRecord:
        raise AppleVerificationUnavailable("apple verifier is not configured")


def verification_failed_record(request: PurchaseVerificationRequest) -> EntitlementRecord:
    return EntitlementRecord(
        outcome="verificationFailed",
        entitlement_tier="none",
        product_id=request.product_id,
        app_account_token=request.app_account_token,
    )


def verification_unavailable_record(request: PurchaseVerificationRequest) -> EntitlementRecord:
    return EntitlementRecord(
        outcome="verificationUnavailable",
        entitlement_tier="none",
        product_id=request.product_id,
        app_account_token=request.app_account_token,
    )


def no_active_entitlement_record(app_account_token: str) -> EntitlementRecord:
    return EntitlementRecord(
        outcome="noActiveEntitlement",
        entitlement_tier="none",
        app_account_token=app_account_token,
    )
