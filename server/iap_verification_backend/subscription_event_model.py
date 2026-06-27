from __future__ import annotations

import dataclasses
import hashlib
import json
from typing import Any, Mapping, Optional

from subscription_state_machine import (
    STATE_ACTIVE,
    STATE_EXPIRED,
    STATE_GRACE,
    STATE_NONE,
    STATE_REVOKED,
)


EVENT_PURCHASE = "PURCHASE"
EVENT_RENEW = "RENEW"
EVENT_EXPIRE = "EXPIRE"
EVENT_REVOKE = "REVOKE"
EVENT_REFUND = "REFUND"

SUBSCRIPTION_EVENT_TYPES = frozenset(
    {
        EVENT_PURCHASE,
        EVENT_RENEW,
        EVENT_EXPIRE,
        EVENT_REVOKE,
        EVENT_REFUND,
    }
)


@dataclasses.dataclass(frozen=True)
class SubscriptionEvent:
    event_id: int
    user_id: str
    product_id: str
    channel: str
    event_type: str
    authority_score: int
    event_time: Optional[str]
    server_time: str
    payload_hash: str
    transaction_id: str
    raw_payload: Mapping[str, Any]
    source: Optional[str] = None
    event_version: Optional[int] = None

    @classmethod
    def from_row(cls, row: Mapping[str, Any]) -> "SubscriptionEvent":
        raw_payload_json = row["raw_payload_json"]
        raw_payload = json.loads(raw_payload_json) if raw_payload_json else {}
        return cls(
            event_id=int(row["event_id"]),
            user_id=str(row["user_id"]),
            product_id=str(row["product_id"]),
            channel=str(row["channel"]),
            event_type=str(row["event_type"]),
            authority_score=int(row["authority_score"]),
            event_time=row["event_time"],
            server_time=str(row["server_time"]),
            payload_hash=str(row["payload_hash"]),
            transaction_id=str(row["transaction_id"]),
            raw_payload=raw_payload,
            source=row["source"],
            event_version=(
                int(row["event_version"]) if row["event_version"] is not None else None
            ),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "eventId": self.event_id,
            "userId": self.user_id,
            "productId": self.product_id,
            "channel": self.channel,
            "eventType": self.event_type,
            "authorityScore": self.authority_score,
            "eventTime": self.event_time,
            "serverTime": self.server_time,
            "payloadHash": self.payload_hash,
            "transactionId": self.transaction_id,
            "source": self.source,
            "eventVersion": self.event_version,
            "rawPayload": dict(self.raw_payload),
        }


Event = SubscriptionEvent


def canonical_payload_json(payload: Mapping[str, Any]) -> str:
    return json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def payload_hash(payload: Mapping[str, Any]) -> str:
    return hashlib.sha256(canonical_payload_json(payload).encode("utf-8")).hexdigest()


def event_type_for_payload(raw_payload: Mapping[str, Any]) -> str:
    for key in ("eventType", "event_type", "notificationType", "subtype"):
        value = raw_payload.get(key)
        if isinstance(value, str) and value.strip():
            mapped = _event_type_for_text(value)
            if mapped is not None:
                return mapped
    status = normalized_status(raw_payload)
    if status in {"active", "grace"}:
        return EVENT_PURCHASE
    if status in {"billing_retry", "expired"}:
        return EVENT_EXPIRE
    if status == "revoked":
        return EVENT_REVOKE
    if status == "refunded":
        return EVENT_REFUND
    return EVENT_EXPIRE


def normalized_status(raw_payload: Mapping[str, Any]) -> str:
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
        "refunded": "refunded",
    }
    return aliases.get(normalized, normalized)


def state_for_subscription_event(event: Any) -> Optional[str]:
    raw_payload = getattr(event, "raw_payload", {})
    if not isinstance(raw_payload, Mapping):
        raw_payload = {}
    legacy_outcome = raw_payload.get("legacyOutcome")
    if legacy_outcome in {"verificationFailed", "verificationUnavailable"}:
        return STATE_NONE
    event_type = str(getattr(event, "event_type", "") or "").upper()
    status = normalized_status(raw_payload)
    if status == "active":
        return STATE_ACTIVE
    if status == "grace":
        return STATE_GRACE
    if status in {"billing_retry", "expired"}:
        return STATE_EXPIRED
    if status == "revoked":
        return STATE_REVOKED
    if event_type in {EVENT_REVOKE, EVENT_REFUND}:
        return STATE_REVOKED
    if event_type == EVENT_EXPIRE:
        return STATE_EXPIRED
    if event_type in {EVENT_PURCHASE, EVENT_RENEW}:
        return STATE_ACTIVE
    return None


def event_kind_for_subscription_event(event: Any, previous_state: str) -> str:
    raw_payload = getattr(event, "raw_payload", {})
    if not isinstance(raw_payload, Mapping):
        raw_payload = {}
    for key in ("eventType", "event_type", "notificationType", "subtype"):
        value = raw_payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip().lower().replace("-", "_")
    event_type = str(getattr(event, "event_type", "") or "").upper()
    if event_type == EVENT_RENEW:
        return "renewal"
    if event_type == EVENT_PURCHASE:
        return "initial_purchase" if previous_state == STATE_NONE else "purchase"
    if event_type == EVENT_REFUND:
        return "refund"
    if event_type == EVENT_REVOKE:
        return "revoke"
    status = normalized_status(raw_payload)
    if status == "active" and previous_state == STATE_NONE:
        return "initial_purchase"
    return "status_update"


def _event_type_for_text(value: str) -> Optional[str]:
    normalized = value.strip().lower().replace("-", "_")
    if any(token in normalized for token in ("refund", "refunded")):
        return EVENT_REFUND
    if any(token in normalized for token in ("revoke", "revoked", "cancel", "cancelled")):
        return EVENT_REVOKE
    if any(token in normalized for token in ("expire", "expired", "grace", "billing_retry")):
        return EVENT_EXPIRE
    if any(token in normalized for token in ("renew", "renewal", "recover", "recovery")):
        return EVENT_RENEW
    if any(token in normalized for token in ("purchase", "initial_buy", "buy")):
        return EVENT_PURCHASE
    return None
