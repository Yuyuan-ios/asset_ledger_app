from __future__ import annotations

import dataclasses
import hashlib
import json
from typing import Any, Mapping, Optional, Sequence


GENESIS_EVENT_HASH = "0" * 64


@dataclasses.dataclass(frozen=True)
class ChainVerificationResult:
    chain_valid: bool
    tamper_detected: bool
    broken_index: Optional[int] = None
    broken_event_id: Optional[int] = None
    expected_previous_hash: Optional[str] = None
    actual_previous_hash: Optional[str] = None
    expected_current_hash: Optional[str] = None
    actual_current_hash: Optional[str] = None
    reason: Optional[str] = None


class EventHashChain:
    """SHA-256 hash chain for append-only subscription ledger events."""

    @classmethod
    def compute_hash(cls, event: Any, prev_hash: str) -> str:
        payload = cls.event_payload(event)
        payload_json = json.dumps(
            payload,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=True,
        )
        material = payload_json.encode("utf-8") + _required_hash(prev_hash).encode("ascii")
        return hashlib.sha256(material).hexdigest()

    @classmethod
    def verify_chain(cls, events: Sequence[Any]) -> bool:
        return cls.verify_chain_detailed(events).chain_valid

    @classmethod
    def verify_chain_detailed(cls, events: Sequence[Any]) -> ChainVerificationResult:
        previous_hash = GENESIS_EVENT_HASH
        for index, event in enumerate(events):
            actual_previous = _optional_hash(getattr(event, "previous_event_hash", None))
            actual_current = _optional_hash(getattr(event, "current_event_hash", None))
            expected_current = cls.compute_hash(event, previous_hash)
            event_id = _optional_int(getattr(event, "event_id", None))
            if actual_previous != previous_hash:
                return ChainVerificationResult(
                    chain_valid=False,
                    tamper_detected=True,
                    broken_index=index,
                    broken_event_id=event_id,
                    expected_previous_hash=previous_hash,
                    actual_previous_hash=actual_previous,
                    expected_current_hash=expected_current,
                    actual_current_hash=actual_current,
                    reason="previous_event_hash_mismatch",
                )
            if actual_current != expected_current:
                return ChainVerificationResult(
                    chain_valid=False,
                    tamper_detected=True,
                    broken_index=index,
                    broken_event_id=event_id,
                    expected_previous_hash=previous_hash,
                    actual_previous_hash=actual_previous,
                    expected_current_hash=expected_current,
                    actual_current_hash=actual_current,
                    reason="current_event_hash_mismatch",
                )
            previous_hash = actual_current
        return ChainVerificationResult(chain_valid=True, tamper_detected=False)

    @staticmethod
    def chain_order(events: Sequence[Any]) -> list[Any]:
        return sorted(events, key=lambda event: int(getattr(event, "event_id", 0)))

    @staticmethod
    def event_payload(event: Any) -> dict[str, Any]:
        raw_payload = getattr(event, "raw_payload", {})
        if not isinstance(raw_payload, Mapping):
            raw_payload = {}
        return {
            "userId": str(getattr(event, "user_id", "")),
            "productId": str(getattr(event, "product_id", "")),
            "channel": str(getattr(event, "channel", "")),
            "eventType": str(getattr(event, "event_type", "")),
            "authorityScore": int(getattr(event, "authority_score", 0)),
            "eventTime": getattr(event, "event_time", None),
            "serverTime": str(getattr(event, "server_time", "")),
            "payloadHash": str(getattr(event, "payload_hash", "")),
            "transactionId": str(getattr(event, "transaction_id", "")),
            "source": getattr(event, "source", None),
            "eventVersion": getattr(event, "event_version", None),
            "rawPayload": dict(raw_payload),
        }


def _required_hash(value: str) -> str:
    normalized = _optional_hash(value)
    if normalized is None:
        raise ValueError("previous hash is required")
    return normalized


def _optional_hash(value: Any) -> Optional[str]:
    if not isinstance(value, str):
        return None
    normalized = value.strip().lower()
    if len(normalized) != 64:
        return None
    try:
        int(normalized, 16)
    except ValueError:
        return None
    return normalized


def _optional_int(value: Any) -> Optional[int]:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None
