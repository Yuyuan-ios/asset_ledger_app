from __future__ import annotations

import dataclasses
import hashlib
import json
from typing import Any, Dict, Mapping, Optional, Protocol

from auth import require_text
from config import MAX_YEARLY_PRODUCT_ID, PRO_YEARLY_PRODUCT_ID
from http_helpers import HttpError
from storage import EntitlementStore, PurchaseTransactionReplay
from verifier import EntitlementRecord, OUTCOME_TO_TIER


@dataclasses.dataclass(frozen=True)
class PurchaseEvent:
    user_id: str
    channel: str
    product_id: str
    transaction_id: str
    signature: Optional[str]
    raw_payload: Mapping[str, Any]


@dataclasses.dataclass(frozen=True)
class ChannelVerificationResult:
    status: str
    original_transaction_id: Optional[str] = None
    latest_transaction_id: Optional[str] = None
    expires_at: Optional[str] = None
    revoked_at: Optional[str] = None
    environment: Optional[str] = None
    app_account_token: Optional[str] = None


class PaymentChannelAdapter(Protocol):
    channel: str

    def verify(self, payload: Mapping[str, Any]) -> ChannelVerificationResult:
        ...

    def parse(
        self,
        payload: Mapping[str, Any],
        verification: ChannelVerificationResult,
        *,
        server_user_id: Optional[str] = None,
    ) -> PurchaseEvent:
        ...

    def getUserId(self, payload: Mapping[str, Any]) -> str:
        ...

    def getProductId(self, payload: Mapping[str, Any]) -> str:
        ...


class EntitlementEngine:
    """Single entitlement source for all verified purchase events."""

    def __init__(self, store: EntitlementStore, allowed_products: tuple[str, ...]):
        self.store = store
        self.allowed_products = tuple(allowed_products)

    def apply(self, event: PurchaseEvent) -> EntitlementRecord:
        record = self.record_for_event(event)
        return self.store.upsert_entitlement(record, user_id=event.user_id)

    def record_for_event(self, event: PurchaseEvent) -> EntitlementRecord:
        tier = self._tier_for_product_id(event.product_id)
        outcome = self._outcome_for_event(event, tier)
        raw = event.raw_payload
        return EntitlementRecord(
            outcome=outcome,
            entitlement_tier=OUTCOME_TO_TIER[outcome],
            product_id=event.product_id,
            app_account_token=_app_account_token_for_event(event),
            original_transaction_id=_optional_raw_text(raw, "originalTransactionId")
            or event.transaction_id,
            latest_transaction_id=_optional_raw_text(raw, "latestTransactionId")
            or event.transaction_id,
            environment=_optional_raw_text(raw, "environment") or event.channel,
            expires_at=_optional_raw_text(raw, "expiresAt"),
            revoked_at=_optional_raw_text(raw, "revokedAt"),
        )

    def _tier_for_product_id(self, product_id: str) -> str:
        if product_id not in self.allowed_products:
            raise HttpError(400, "unknown_product", "product_id is not allowed")
        if product_id == PRO_YEARLY_PRODUCT_ID or product_id.endswith(".pro.yearly"):
            return "pro"
        if product_id == MAX_YEARLY_PRODUCT_ID or product_id.endswith(".max.yearly"):
            return "max"
        return "none"

    def _outcome_for_event(self, event: PurchaseEvent, tier: str) -> str:
        status = _normalized_status(event.raw_payload)
        if status == "active":
            if tier == "max":
                return "verifiedActiveMax"
            if tier == "pro":
                return "verifiedActivePro"
            return "noActiveEntitlement"
        if status == "grace":
            if tier == "max":
                return "verifiedGracePeriodMax"
            if tier == "pro":
                return "verifiedGracePeriodPro"
            return "noActiveEntitlement"
        if status == "billing_retry":
            return "billingRetry"
        if status == "expired":
            return "expired"
        if status == "revoked":
            return "revoked"
        raise HttpError(400, "invalid_purchase_status", "purchase status is not supported")


class SubscriptionGatewayService:
    def __init__(
        self,
        store: EntitlementStore,
        adapters: Mapping[str, PaymentChannelAdapter],
        entitlement_engine: EntitlementEngine,
    ):
        self.store = store
        self.adapters = dict(adapters)
        self.entitlement_engine = entitlement_engine

    def receive_purchase_event(
        self,
        channel: str,
        payload: Mapping[str, Any],
        *,
        server_user_id: Optional[str] = None,
    ) -> Dict[str, object]:
        if not isinstance(payload, Mapping):
            raise HttpError(400, "invalid_json", "request body must be a JSON object")
        adapter = self._adapter_for_channel(channel)
        verification = self.verify_channel_signature(adapter, payload)
        event = self.normalize_event(
            adapter,
            payload,
            verification,
            server_user_id=server_user_id,
        )
        record_preview = self.entitlement_engine.record_for_event(event)
        payload_hash = _payload_hash(payload)
        try:
            is_new = self.store.record_purchase_transaction(
                transaction_id=event.transaction_id,
                channel=event.channel,
                user_id=event.user_id,
                product_id=event.product_id,
                payload_hash=payload_hash,
                entitlement_tier=record_preview.entitlement_tier,
            )
        except PurchaseTransactionReplay as exc:
            raise HttpError(
                409,
                "replay_attack",
                "transaction_id was already processed with different payload",
            ) from exc
        if not is_new:
            record = self.store.get_latest_entitlement_for_user(event.user_id)
            return self._response("ignored", event, record)
        record = self.forward_to_entitlement_engine(event)
        status = "applied" if record.entitlement_tier != "none" else "rejected"
        return self._response(status, event, record)

    def verify_channel_signature(
        self,
        adapter: PaymentChannelAdapter,
        payload: Mapping[str, Any],
    ) -> ChannelVerificationResult:
        return adapter.verify(payload)

    def normalize_event(
        self,
        adapter: PaymentChannelAdapter,
        payload: Mapping[str, Any],
        verification: ChannelVerificationResult,
        *,
        server_user_id: Optional[str] = None,
    ) -> PurchaseEvent:
        return adapter.parse(payload, verification, server_user_id=server_user_id)

    def forward_to_entitlement_engine(self, event: PurchaseEvent) -> EntitlementRecord:
        return self.entitlement_engine.apply(event)

    def _adapter_for_channel(self, channel: str) -> PaymentChannelAdapter:
        normalized = require_text(channel, "channel", max_length=64)
        adapter = self.adapters.get(normalized)
        if adapter is None:
            raise HttpError(404, "unsupported_payment_channel", "payment channel is not supported")
        return adapter

    def _response(
        self,
        gateway_status: str,
        event: PurchaseEvent,
        record: Optional[EntitlementRecord],
    ) -> Dict[str, object]:
        body: Dict[str, object] = {
            "gatewayStatus": gateway_status,
            "event": {
                "userId": event.user_id,
                "channel": event.channel,
                "productId": event.product_id,
                "transactionId": event.transaction_id,
            },
        }
        if record is not None:
            body["entitlement"] = record.to_response_body()
        return body


def _normalized_status(raw_payload: Mapping[str, Any]) -> str:
    status = raw_payload.get("normalizedStatus", raw_payload.get("status"))
    if not isinstance(status, str) or not status.strip():
        return "active"
    normalized = status.strip().lower().replace("-", "_")
    aliases = {
        "purchased": "active",
        "renewed": "active",
        "paid": "active",
        "success": "active",
        "grace_period": "grace",
        "billingretry": "billing_retry",
        "billing_retry_period": "billing_retry",
        "canceled": "revoked",
        "cancelled": "revoked",
    }
    return aliases.get(normalized, normalized)


def _optional_raw_text(raw_payload: Mapping[str, Any], key: str) -> Optional[str]:
    value = raw_payload.get(key)
    if value is None:
        return None
    if not isinstance(value, str) or not value.strip():
        return None
    return value.strip()


def _app_account_token_for_event(event: PurchaseEvent) -> str:
    raw_token = _optional_raw_text(event.raw_payload, "appAccountToken")
    if raw_token is not None:
        return raw_token
    digest = hashlib.sha256(
        f"{event.channel}:{event.transaction_id}".encode("utf-8")
    ).hexdigest()
    return f"gateway:{digest}"


def _payload_hash(payload: Mapping[str, Any]) -> str:
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()
