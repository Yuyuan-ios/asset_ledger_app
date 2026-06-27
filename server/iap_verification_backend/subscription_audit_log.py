from __future__ import annotations

import json
from typing import Any, Mapping, Optional


RAW_EVENT_LOG = "raw_event_log"
PROCESSED_EVENT_LOG = "processed_event_log"
ENTITLEMENT_CHANGE_LOG = "entitlement_change_log"


class SubscriptionAuditLog:
    """Append-only audit facade for subscription events and state changes."""

    def __init__(self, store: Any):
        self.store = store

    def record_raw_event(
        self,
        event: Any,
        *,
        authority_score: int = 0,
        reason: str = "received",
    ) -> None:
        self._append(
            RAW_EVENT_LOG,
            event,
            authority_score=authority_score,
            previous_state=None,
            new_state=None,
            reason=reason,
        )

    def record_processed_event(
        self,
        event: Any,
        *,
        authority_score: int,
        previous_state: Optional[str],
        new_state: Optional[str],
        reason: str,
    ) -> None:
        self._append(
            PROCESSED_EVENT_LOG,
            event,
            authority_score=authority_score,
            previous_state=previous_state,
            new_state=new_state,
            reason=reason,
        )

    def record_entitlement_change(
        self,
        event: Any,
        *,
        authority_score: int,
        previous_state: Optional[str],
        new_state: Optional[str],
        reason: str,
    ) -> None:
        self._append(
            ENTITLEMENT_CHANGE_LOG,
            event,
            authority_score=authority_score,
            previous_state=previous_state,
            new_state=new_state,
            reason=reason,
        )

    def _append(
        self,
        log_type: str,
        event: Any,
        *,
        authority_score: int,
        previous_state: Optional[str],
        new_state: Optional[str],
        reason: str,
    ) -> None:
        raw_payload = getattr(event, "raw_payload", {})
        self.store.append_subscription_audit_log(
            log_type=log_type,
            user_id=str(getattr(event, "user_id", "")),
            product_id=str(getattr(event, "product_id", "")),
            channel=str(getattr(event, "channel", "")),
            authority_score=authority_score,
            previous_state=previous_state,
            new_state=new_state,
            event_time=getattr(event, "event_time", None)
            or _first_text(raw_payload, "eventTime", "event_time", "transactionDate"),
            transaction_id=str(getattr(event, "transaction_id", "")),
            reason=reason,
            raw_payload_json=json.dumps(
                raw_payload,
                sort_keys=True,
                separators=(",", ":"),
                ensure_ascii=True,
            ),
        )


def _first_text(payload: Any, *keys: str) -> Optional[str]:
    if not isinstance(payload, Mapping):
        return None
    for key in keys:
        value = payload.get(key)
        if value is not None and str(value).strip():
            return str(value).strip()
    return None
