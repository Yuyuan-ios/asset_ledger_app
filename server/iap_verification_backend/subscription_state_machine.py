from __future__ import annotations

import dataclasses
from typing import FrozenSet, Mapping, Optional


STATE_NONE = "NONE"
STATE_ACTIVE = "ACTIVE"
STATE_GRACE = "GRACE"
STATE_EXPIRED = "EXPIRED"
STATE_REVOKED = "REVOKED"

SUBSCRIPTION_STATES: FrozenSet[str] = frozenset(
    {
        STATE_NONE,
        STATE_ACTIVE,
        STATE_GRACE,
        STATE_EXPIRED,
        STATE_REVOKED,
    }
)

RENEWAL_EVENT_KINDS: FrozenSet[str] = frozenset(
    {
        "initial_purchase",
        "purchase",
        "renewal",
        "recover",
        "recovery",
        "reconciliation_recovery",
    }
)

ALLOWED_TRANSITIONS: Mapping[str, FrozenSet[str]] = {
    STATE_NONE: frozenset({STATE_NONE, STATE_ACTIVE, STATE_GRACE, STATE_EXPIRED, STATE_REVOKED}),
    STATE_ACTIVE: frozenset({STATE_ACTIVE, STATE_GRACE, STATE_EXPIRED, STATE_REVOKED}),
    STATE_GRACE: frozenset({STATE_ACTIVE, STATE_GRACE, STATE_EXPIRED, STATE_REVOKED}),
    STATE_EXPIRED: frozenset({STATE_EXPIRED, STATE_REVOKED}),
    STATE_REVOKED: frozenset({STATE_REVOKED}),
}


@dataclasses.dataclass(frozen=True)
class StateTransitionResult:
    previous_state: str
    requested_state: str
    new_state: str
    changed: bool
    safe_no_op: bool
    reason: str


class SubscriptionStateMachine:
    """Deterministic state transitions for subscription ledger state."""

    def transition(
        self,
        previous_state: Optional[str],
        requested_state: Optional[str],
        *,
        event_kind: Optional[str] = None,
    ) -> StateTransitionResult:
        previous = normalize_state(previous_state)
        requested = normalize_state(requested_state)
        if previous is None or requested is None:
            current = previous or STATE_NONE
            target = requested or current
            return StateTransitionResult(
                previous_state=current,
                requested_state=target,
                new_state=current,
                changed=False,
                safe_no_op=True,
                reason="undecidable_state",
            )

        normalized_event_kind = (event_kind or "").strip().lower()
        if previous in {STATE_EXPIRED, STATE_REVOKED} and requested == STATE_ACTIVE:
            if normalized_event_kind in RENEWAL_EVENT_KINDS:
                return _accepted_transition(previous, requested, "renewal_reactivation")
            return StateTransitionResult(
                previous_state=previous,
                requested_state=requested,
                new_state=previous,
                changed=False,
                safe_no_op=True,
                reason="reactivation_requires_renewal_event",
            )

        if requested not in ALLOWED_TRANSITIONS[previous]:
            return StateTransitionResult(
                previous_state=previous,
                requested_state=requested,
                new_state=previous,
                changed=False,
                safe_no_op=True,
                reason="illegal_state_transition",
            )

        return _accepted_transition(previous, requested, "accepted")


def normalize_state(value: Optional[str]) -> Optional[str]:
    if value is None:
        return STATE_NONE
    normalized = str(value).strip().upper()
    if not normalized:
        return STATE_NONE
    if normalized not in SUBSCRIPTION_STATES:
        return None
    return normalized


def _accepted_transition(previous: str, requested: str, reason: str) -> StateTransitionResult:
    return StateTransitionResult(
        previous_state=previous,
        requested_state=requested,
        new_state=requested,
        changed=previous != requested,
        safe_no_op=False,
        reason=reason,
    )
