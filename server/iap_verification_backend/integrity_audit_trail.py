from __future__ import annotations

import json
from typing import Any, Mapping, Optional


INTEGRITY_AUDIT_LOG = "integrity_audit_trail"


class IntegrityAuditTrail:
    """Append-only audit facade for ledger integrity and replay verification."""

    def __init__(self, store: Any):
        self.store = store

    def record_integrity_check(self, result: Any, *, user_id: Optional[str] = None) -> None:
        payload = _to_dict(result)
        self._append(
            user_id=user_id or payload.get("userId"),
            reason="integrity_check_passed"
            if bool(payload.get("chain_valid"))
            else "integrity_check_failed",
            payload=payload,
        )

    def record_replay_verification(
        self,
        *,
        user_id: str,
        integrity_result: Any,
        projection_diff_before: Optional[Mapping[str, Any]] = None,
        projection_diff_after: Optional[Mapping[str, Any]] = None,
    ) -> None:
        payload = {
            "integrity": _to_dict(integrity_result),
            "projectionDiffBefore": dict(projection_diff_before or {}),
            "projectionDiffAfter": dict(projection_diff_after or {}),
        }
        integrity_valid = bool(payload["integrity"].get("chain_valid"))
        projection_valid = bool((projection_diff_after or projection_diff_before or {}).get("matches", True))
        self._append(
            user_id=user_id,
            reason="replay_verification_passed"
            if integrity_valid and projection_valid
            else "replay_verification_failed",
            payload=payload,
        )

    def record_tamper_attempt(
        self,
        *,
        user_id: Optional[str],
        result: Any,
        reason: str = "tamper_attempt_detected",
    ) -> None:
        self._append(user_id=user_id, reason=reason, payload=_to_dict(result))

    def _append(
        self,
        *,
        user_id: Optional[str],
        reason: str,
        payload: Mapping[str, Any],
    ) -> None:
        stable_user_id = user_id or "global"
        chain_valid = bool(payload.get("chain_valid", payload.get("integrity", {}).get("chain_valid")))
        self.store.append_subscription_audit_log(
            log_type=INTEGRITY_AUDIT_LOG,
            user_id=str(stable_user_id),
            product_id="subscription_ledger",
            channel="integrity",
            authority_score=0,
            previous_state=None,
            new_state="TRUSTED" if chain_valid else "UNTRUSTED",
            event_time=None,
            transaction_id=f"integrity:{reason}:{stable_user_id}",
            reason=reason,
            raw_payload_json=json.dumps(
                payload,
                sort_keys=True,
                separators=(",", ":"),
                ensure_ascii=True,
            ),
        )


def _to_dict(value: Any) -> dict[str, Any]:
    if hasattr(value, "to_dict"):
        return dict(value.to_dict())
    if isinstance(value, Mapping):
        return dict(value)
    return {"value": str(value)}
