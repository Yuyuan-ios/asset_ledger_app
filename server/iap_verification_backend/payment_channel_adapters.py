from __future__ import annotations

import hashlib
import hmac
import json
import os
from typing import Any, Mapping, Optional

from auth import RequestValidator, require_text
from common.auth_identity.auth_planes import AuthPlane
from common.auth_identity.resolver import require_stable_user_id
from http_helpers import HttpError
from subscription_gateway import ChannelVerificationResult, PurchaseEvent
from verifier import (
    AppleVerificationFailed,
    AppleVerificationUnavailable,
    AppleVerifier,
    EntitlementRecord,
)


APPLE_CHANNEL = "apple"
GOOGLE_PLAY_CHANNEL = "google_play"
OPPO_CHANNEL = "oppo"
XIAOMI_CHANNEL = "xiaomi"
HUAWEI_CHANNEL = "huawei"
VIVO_CHANNEL = "vivo"
WEBHOOK_CHANNELS = (
    GOOGLE_PLAY_CHANNEL,
    OPPO_CHANNEL,
    XIAOMI_CHANNEL,
    HUAWEI_CHANNEL,
    VIVO_CHANNEL,
)
CHANNEL_ENV_PREFIX = {
    GOOGLE_PLAY_CHANNEL: "FLEET_IAP_GOOGLE_PLAY",
    OPPO_CHANNEL: "FLEET_IAP_OPPO",
    XIAOMI_CHANNEL: "FLEET_IAP_XIAOMI",
    HUAWEI_CHANNEL: "FLEET_IAP_HUAWEI",
    VIVO_CHANNEL: "FLEET_IAP_VIVO",
}


def normalize_channel_name(value: str) -> str:
    normalized = value.strip().lower().replace("-", "_")
    aliases = {
        "app_store": APPLE_CHANNEL,
        "ios": APPLE_CHANNEL,
        "google": GOOGLE_PLAY_CHANNEL,
        "googleplay": GOOGLE_PLAY_CHANNEL,
        "google_play_billing": GOOGLE_PLAY_CHANNEL,
        "mi": XIAOMI_CHANNEL,
        "xiaomi_iap": XIAOMI_CHANNEL,
        "hms": HUAWEI_CHANNEL,
        "huawei_hms": HUAWEI_CHANNEL,
        "vivo_iap": VIVO_CHANNEL,
        "oppo_iap": OPPO_CHANNEL,
    }
    return aliases.get(normalized, normalized)


def build_default_payment_channel_adapters(
    validator: RequestValidator,
    apple_verifier: AppleVerifier,
    channel_signature_secrets: Optional[Mapping[str, str]] = None,
) -> dict[str, object]:
    secrets = dict(channel_signature_secrets or _channel_secrets_from_env())
    adapters: dict[str, object] = {
        APPLE_CHANNEL: AppleAdapter(validator, apple_verifier),
    }
    for channel in WEBHOOK_CHANNELS:
        adapters[channel] = SignedWebhookAdapter(
            channel=channel,
            signature_secret=secrets.get(channel),
        )
    return adapters


class AppleAdapter:
    channel = APPLE_CHANNEL

    def __init__(self, validator: RequestValidator, verifier: AppleVerifier):
        self.validator = validator
        self.verifier = verifier

    def verify(self, payload: Mapping[str, Any]) -> ChannelVerificationResult:
        request = self.validator.validate_purchase_body(payload)
        try:
            record = self.verifier.verify_purchase(request)
        except AppleVerificationUnavailable as exc:
            raise HttpError(
                503,
                "subscription_verification_unavailable",
                "Subscription verification is currently unavailable.",
            ) from exc
        except AppleVerificationFailed as exc:
            raise HttpError(401, "verification_failed", "purchase verification failed") from exc
        return _verification_from_apple_record(record)

    def parse(
        self,
        payload: Mapping[str, Any],
        verification: ChannelVerificationResult,
        *,
        server_user_id: Optional[str] = None,
    ) -> PurchaseEvent:
        request = self.validator.validate_purchase_body(payload)
        user_id = require_stable_user_id(
            server_user_id,
            field_name="user_id",
            auth_plane=AuthPlane.USER,
        )
        raw_payload = dict(payload)
        raw_payload.update(
            {
                "normalizedStatus": verification.status,
                "originalTransactionId": verification.original_transaction_id,
                "latestTransactionId": verification.latest_transaction_id,
                "expiresAt": verification.expires_at,
                "revokedAt": verification.revoked_at,
                "environment": verification.environment,
                "appAccountToken": verification.app_account_token
                or request.app_account_token,
            }
        )
        return PurchaseEvent(
            user_id=user_id,
            channel=self.channel,
            product_id=request.product_id,
            transaction_id=verification.latest_transaction_id
            or request.purchase_id
            or verification.original_transaction_id
            or request.app_account_token,
            signature=request.server_verification_data,
            raw_payload=raw_payload,
            event_time=_first_text(payload, "eventTime", "event_time")
            or request.transaction_date,
            source=_first_text(payload, "authoritySource", "eventSource", "source")
            or request.source,
        )

    def getUserId(self, payload: Mapping[str, Any]) -> str:
        return require_stable_user_id(
            payload.get("user_id"),
            field_name="user_id",
            auth_plane=AuthPlane.USER,
        )

    def getProductId(self, payload: Mapping[str, Any]) -> str:
        request = self.validator.validate_purchase_body(payload)
        return request.product_id


class SignedWebhookAdapter:
    def __init__(self, *, channel: str, signature_secret: Optional[str]):
        self.channel = channel
        self.signature_secret = signature_secret

    def verify(self, payload: Mapping[str, Any]) -> ChannelVerificationResult:
        expected_channel = normalize_channel_name(str(payload.get("channel", self.channel)))
        if expected_channel != self.channel:
            raise HttpError(400, "invalid_channel", "payload channel does not match endpoint")
        signature = require_text(payload.get("signature"), "signature", max_length=512)
        if not self.signature_secret:
            raise HttpError(
                503,
                "channel_signature_unconfigured",
                "payment channel signature verification is not configured",
            )
        expected = signature_for_payload(payload, self.signature_secret)
        if not _constant_time_signature_match(signature, expected):
            raise HttpError(401, "invalid_signature", "payment channel signature is invalid")
        return ChannelVerificationResult(
            status=_status_from_payload(payload),
            original_transaction_id=_first_text(
                payload,
                "originalTransactionId",
                "original_transaction_id",
                "orderId",
                "order_id",
                fallback=self._transaction_id(payload),
            ),
            latest_transaction_id=self._transaction_id(payload),
            expires_at=_first_text(payload, "expiresAt", "expires_at"),
            revoked_at=_first_text(payload, "revokedAt", "revoked_at"),
            environment=_first_text(payload, "environment", fallback=self.channel),
        )

    def parse(
        self,
        payload: Mapping[str, Any],
        verification: ChannelVerificationResult,
        *,
        server_user_id: Optional[str] = None,
    ) -> PurchaseEvent:
        raw_payload = dict(payload)
        raw_payload.update(
            {
                "normalizedStatus": verification.status,
                "originalTransactionId": verification.original_transaction_id,
                "latestTransactionId": verification.latest_transaction_id,
                "expiresAt": verification.expires_at,
                "revokedAt": verification.revoked_at,
                "environment": verification.environment,
                "source": _first_text(
                    payload,
                    "authoritySource",
                    "eventSource",
                    "source",
                    "sourceType",
                    fallback="webhook",
                ),
            }
        )
        return PurchaseEvent(
            user_id=self.getUserId(payload),
            channel=self.channel,
            product_id=self.getProductId(payload),
            transaction_id=self._transaction_id(payload),
            signature=require_text(payload.get("signature"), "signature", max_length=512),
            raw_payload=raw_payload,
            event_time=_first_text(
                payload,
                "eventTime",
                "event_time",
                "serverTime",
                "server_time",
                "transactionDate",
                "transaction_date",
            ),
            source=_first_text(
                payload,
                "authoritySource",
                "eventSource",
                "source",
                "sourceType",
                fallback="webhook",
            ),
        )

    def getUserId(self, payload: Mapping[str, Any]) -> str:
        return require_stable_user_id(
            _first_raw(payload, "user_id", "userId", "accountId", "account_id"),
            field_name="user_id",
            auth_plane=AuthPlane.SERVICE,
        )

    def getProductId(self, payload: Mapping[str, Any]) -> str:
        return require_text(
            _first_raw(payload, "product_id", "productId", "sku"),
            "product_id",
            max_length=256,
        )

    def _transaction_id(self, payload: Mapping[str, Any]) -> str:
        return require_text(
            _first_raw(
                payload,
                "transaction_id",
                "transactionId",
                "purchaseToken",
                "orderId",
                "order_id",
            ),
            "transaction_id",
            max_length=256,
        )


def signature_for_payload(payload: Mapping[str, Any], secret: str) -> str:
    canonical = canonical_payload(payload)
    return hmac.new(secret.encode("utf-8"), canonical.encode("utf-8"), hashlib.sha256).hexdigest()


def canonical_payload(payload: Mapping[str, Any]) -> str:
    signing_payload = {key: value for key, value in payload.items() if key != "signature"}
    return json.dumps(signing_payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def _channel_secrets_from_env() -> dict[str, str]:
    secrets: dict[str, str] = {}
    for channel, prefix in CHANNEL_ENV_PREFIX.items():
        secret = os.environ.get(f"{prefix}_SIGNATURE_SECRET", "").strip()
        if secret:
            secrets[channel] = secret
    return secrets


def _constant_time_signature_match(value: str, expected_hex: str) -> bool:
    normalized = value.strip()
    if normalized.startswith("sha256="):
        normalized = normalized[len("sha256=") :]
    return hmac.compare_digest(normalized, expected_hex)


def _verification_from_apple_record(record: EntitlementRecord) -> ChannelVerificationResult:
    outcome_status = {
        "verifiedActivePro": "active",
        "verifiedActiveMax": "active",
        "verifiedGracePeriodPro": "grace",
        "verifiedGracePeriodMax": "grace",
        "billingRetry": "billing_retry",
        "expired": "expired",
        "revoked": "revoked",
        "noActiveEntitlement": "expired",
        "verificationFailed": "expired",
        "verificationUnavailable": "expired",
    }
    return ChannelVerificationResult(
        status=outcome_status[record.outcome],
        original_transaction_id=record.original_transaction_id,
        latest_transaction_id=record.latest_transaction_id,
        expires_at=record.expires_at,
        revoked_at=record.revoked_at,
        environment=record.environment,
        app_account_token=record.app_account_token,
    )


def _status_from_payload(payload: Mapping[str, Any]) -> str:
    raw_status = _first_text(payload, "status", "purchaseStatus", fallback="active")
    normalized = raw_status.strip().lower().replace("-", "_")
    aliases = {
        "purchased": "active",
        "paid": "active",
        "success": "active",
        "grace_period": "grace",
        "billingretry": "billing_retry",
        "billing_retry_period": "billing_retry",
        "canceled": "revoked",
        "cancelled": "revoked",
    }
    return aliases.get(normalized, normalized)


def _first_raw(payload: Mapping[str, Any], *keys: str) -> Any:
    for key in keys:
        value = payload.get(key)
        if value is not None:
            return value
    return None


def _first_text(
    payload: Mapping[str, Any],
    *keys: str,
    fallback: Optional[str] = None,
) -> Optional[str]:
    value = _first_raw(payload, *keys)
    if value is None:
        return fallback
    if not isinstance(value, str) or not value.strip():
        return fallback
    return value.strip()
