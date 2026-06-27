from __future__ import annotations

import json
from typing import Any, Optional

from http_helpers import utc_now_iso
from runtime_write_firewall import REPLAY_ENGINE_WRITER_SOURCE, RblViolation, RuntimeWriteContext


class EntitlementProjectionStore:
    """Disposable projection writer for replay-derived entitlement state."""

    def __init__(self, store: Any):
        self.store = store

    def write_projection(self, replayed_state: Any, *, context: RuntimeWriteContext) -> None:
        if context.source != REPLAY_ENGINE_WRITER_SOURCE:
            raise RblViolation("RBL VIOLATION: projection writes require replay engine context")
        for product_state in replayed_state.product_states.values():
            if product_state.record is None:
                continue
            self.store.upsert_entitlement(
                product_state.record,
                user_id=product_state.binding_user_id,
                write_context=context,
            )
            self.store.upsert_subscription_state(
                user_id=replayed_state.user_id,
                product_id=product_state.product_id,
                state=product_state.state,
                authority_score=product_state.authority_score,
                event_time=product_state.event_time,
                event_version=product_state.event_version,
                channel=product_state.channel,
                transaction_id=product_state.transaction_id,
                write_context=context,
            )
        self.store.upsert_entitlement_projection(
            user_id=replayed_state.user_id,
            current_entitlement_json=json.dumps(
                replayed_state.current_entitlement_body(),
                sort_keys=True,
                separators=(",", ":"),
                ensure_ascii=True,
            ),
            last_replayed_event_id=replayed_state.last_replayed_event_id,
            computed_at=utc_now_iso(),
            write_context=context,
        )

    def get_projection(self, user_id: str) -> Optional[dict[str, Any]]:
        projection = self.store.get_entitlement_projection(user_id)
        if projection is None:
            return None
        return {
            "userId": projection["user_id"],
            "currentEntitlement": json.loads(projection["current_entitlement_json"]),
            "lastReplayedEventId": int(projection["last_replayed_event_id"]),
            "computedAt": projection["computed_at"],
        }

    def diff(self, user_id: str, replayed_state: Any) -> dict[str, Any]:
        stored = self.get_projection(user_id)
        reconstructed = replayed_state.current_entitlement_body()
        if stored is None:
            return {
                "matches": False,
                "reason": "missing_projection",
                "stored": None,
                "reconstructed": reconstructed,
            }
        stored_current = stored["currentEntitlement"]
        field_diffs = {}
        for key in sorted(set(stored_current) | set(reconstructed)):
            stored_value = stored_current.get(key)
            reconstructed_value = reconstructed.get(key)
            if stored_value != reconstructed_value:
                field_diffs[key] = {
                    "stored": stored_value,
                    "reconstructed": reconstructed_value,
                }
        if stored["lastReplayedEventId"] != replayed_state.last_replayed_event_id:
            field_diffs["lastReplayedEventId"] = {
                "stored": stored["lastReplayedEventId"],
                "reconstructed": replayed_state.last_replayed_event_id,
            }
        return {
            "matches": not field_diffs,
            "fields": field_diffs,
            "stored": stored,
            "reconstructed": reconstructed,
        }
