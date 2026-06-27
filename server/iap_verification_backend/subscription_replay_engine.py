from __future__ import annotations

import dataclasses
from datetime import datetime, timezone
from typing import Any, Mapping, Optional

from entitlement_projection_store import EntitlementProjectionStore
from runtime_write_firewall import RuntimeWriteContext
from subscription_event_model import (
    SubscriptionEvent,
    event_kind_for_subscription_event,
    state_for_subscription_event,
)
from subscription_event_store import SubscriptionEventStore
from subscription_state_machine import STATE_NONE, SubscriptionStateMachine
from verifier import EntitlementRecord


@dataclasses.dataclass(frozen=True)
class ReplayDecision:
    event_id: int
    product_id: str
    previous_state: str
    new_state: str
    applied: bool
    reason: str
    record: Optional[EntitlementRecord] = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "eventId": self.event_id,
            "productId": self.product_id,
            "previousState": self.previous_state,
            "newState": self.new_state,
            "applied": self.applied,
            "reason": self.reason,
            "entitlement": None if self.record is None else self.record.to_response_body(),
        }


@dataclasses.dataclass
class ProductReplayState:
    product_id: str
    state: str = STATE_NONE
    authority_score: int = 0
    event_time: Optional[str] = None
    event_version: int = 0
    channel: str = ""
    transaction_id: str = ""
    record: Optional[EntitlementRecord] = None
    binding_user_id: Optional[str] = None
    last_event_id: int = 0


@dataclasses.dataclass(frozen=True)
class EntitlementState:
    user_id: str
    product_states: dict[str, ProductReplayState]
    decisions: list[ReplayDecision]
    last_replayed_event_id: int
    current_entitlement: Optional[EntitlementRecord]

    def current_entitlement_body(self) -> dict[str, Any]:
        if self.current_entitlement is None:
            return {
                "outcome": "noActiveEntitlement",
                "entitlementTier": "none",
            }
        return self.current_entitlement.to_response_body()

    def decision_for_event_id(self, event_id: int) -> Optional[ReplayDecision]:
        for decision in reversed(self.decisions):
            if decision.event_id == event_id:
                return decision
        return None

    def to_dict(self) -> dict[str, Any]:
        return {
            "userId": self.user_id,
            "currentEntitlement": self.current_entitlement_body(),
            "lastReplayedEventId": self.last_replayed_event_id,
            "productStates": {
                product_id: {
                    "state": product_state.state,
                    "authorityScore": product_state.authority_score,
                    "eventTime": product_state.event_time,
                    "eventVersion": product_state.event_version,
                    "channel": product_state.channel,
                    "transactionId": product_state.transaction_id,
                    "lastEventId": product_state.last_event_id,
                    "entitlement": None
                    if product_state.record is None
                    else product_state.record.to_response_body(),
                }
                for product_id, product_state in sorted(self.product_states.items())
            },
            "decisions": [decision.to_dict() for decision in self.decisions],
        }


class SubscriptionReplayEngine:
    """Deterministically rebuilds entitlement projection from event log only."""

    def __init__(
        self,
        *,
        event_store: SubscriptionEventStore,
        projection_store: EntitlementProjectionStore,
        entitlement_engine: Any,
        state_machine: Optional[SubscriptionStateMachine] = None,
    ):
        self.event_store = event_store
        self.projection_store = projection_store
        self.entitlement_engine = entitlement_engine
        self.state_machine = state_machine or SubscriptionStateMachine()

    def replay(
        self,
        user_id: str,
        *,
        update_projection: bool = True,
        events: Optional[list[SubscriptionEvent]] = None,
    ) -> EntitlementState:
        replay_events = events if events is not None else self.event_store.get_events(user_id)
        state = self._replay_events(user_id, replay_events)
        if update_projection:
            context = RuntimeWriteContext.replay_engine(
                operation="replay_projection_update",
                user_id=user_id,
                transaction_id=str(state.last_replayed_event_id or ""),
            )
            self.projection_store.write_projection(state, context=context)
        return state

    def replay_all(self, *, update_projection: bool = True) -> dict[str, EntitlementState]:
        snapshots: dict[str, EntitlementState] = {}
        for user_id in self.event_store.list_user_ids():
            snapshots[user_id] = self.replay(user_id, update_projection=update_projection)
        return snapshots

    def projection_diff(self, user_id: str) -> dict[str, Any]:
        state = self.replay(user_id, update_projection=False)
        return self.projection_store.diff(user_id, state)

    def _replay_events(
        self,
        user_id: str,
        events: list[SubscriptionEvent],
    ) -> EntitlementState:
        product_states: dict[str, ProductReplayState] = {}
        decisions: list[ReplayDecision] = []
        app_token_claims: dict[str, str] = {}
        original_transaction_claims: dict[str, str] = {}
        sorted_events = sorted(events, key=_event_sort_key)

        for event in sorted_events:
            product_state = product_states.setdefault(
                event.product_id,
                ProductReplayState(product_id=event.product_id),
            )
            previous_state = product_state.state
            event_time_order = _parse_event_time(event.event_time)
            current_time_order = _parse_event_time(product_state.event_time)
            if event.event_time is not None and event_time_order is None:
                decisions.append(
                    ReplayDecision(
                        event_id=event.event_id,
                        product_id=event.product_id,
                        previous_state=previous_state,
                        new_state=previous_state,
                        applied=False,
                        reason="event_time_unorderable",
                    )
                )
                continue
            if (
                event.event_time is not None
                and product_state.event_time is not None
                and current_time_order is not None
                and event_time_order == current_time_order
                and event.event_id != product_state.last_event_id
            ):
                decisions.append(
                    ReplayDecision(
                        event_id=event.event_id,
                        product_id=event.product_id,
                        previous_state=previous_state,
                        new_state=previous_state,
                        applied=False,
                        reason="ambiguous_equal_event_time",
                    )
                )
                continue
            if event.authority_score < product_state.authority_score:
                decisions.append(
                    ReplayDecision(
                        event_id=event.event_id,
                        product_id=event.product_id,
                        previous_state=previous_state,
                        new_state=previous_state,
                        applied=False,
                        reason="lower_authority_event_ignored",
                    )
                )
                continue
            binding_user_id = _binding_user_id_for_event(event)
            claim_conflict = _claim_conflict_reason(
                event,
                binding_user_id=binding_user_id,
                app_token_claims=app_token_claims,
                original_transaction_claims=original_transaction_claims,
            )
            if claim_conflict is not None:
                decisions.append(
                    ReplayDecision(
                        event_id=event.event_id,
                        product_id=event.product_id,
                        previous_state=previous_state,
                        new_state=previous_state,
                        applied=False,
                        reason=claim_conflict,
                    )
                )
                continue
            requested_state = state_for_subscription_event(event)
            if requested_state is None:
                decisions.append(
                    ReplayDecision(
                        event_id=event.event_id,
                        product_id=event.product_id,
                        previous_state=previous_state,
                        new_state=previous_state,
                        applied=False,
                        reason="undecidable_purchase_status",
                    )
                )
                continue
            transition = self.state_machine.transition(
                previous_state,
                requested_state,
                event_kind=event_kind_for_subscription_event(event, previous_state),
            )
            if transition.safe_no_op:
                decisions.append(
                    ReplayDecision(
                        event_id=event.event_id,
                        product_id=event.product_id,
                        previous_state=transition.previous_state,
                        new_state=transition.new_state,
                        applied=False,
                        reason=transition.reason,
                    )
                )
                continue
            record = self.entitlement_engine.record_for_event(
                event,
                state=transition.new_state,
            )
            product_state.state = transition.new_state
            product_state.authority_score = event.authority_score
            product_state.event_time = event.event_time
            product_state.event_version = event.event_version or event.event_id
            product_state.channel = event.channel
            product_state.transaction_id = event.transaction_id
            product_state.record = record
            product_state.binding_user_id = binding_user_id
            product_state.last_event_id = event.event_id
            _record_claims(
                event,
                binding_user_id=binding_user_id,
                app_token_claims=app_token_claims,
                original_transaction_claims=original_transaction_claims,
            )
            decisions.append(
                ReplayDecision(
                    event_id=event.event_id,
                    product_id=event.product_id,
                    previous_state=transition.previous_state,
                    new_state=transition.new_state,
                    applied=True,
                    reason=transition.reason,
                    record=record,
                )
            )

        return EntitlementState(
            user_id=user_id,
            product_states=product_states,
            decisions=decisions,
            last_replayed_event_id=max((event.event_id for event in sorted_events), default=0),
            current_entitlement=_current_entitlement(product_states),
        )


def _current_entitlement(
    product_states: Mapping[str, ProductReplayState],
) -> Optional[EntitlementRecord]:
    records = [state for state in product_states.values() if state.record is not None]
    if not records:
        return None
    active = [
        state
        for state in records
        if state.record is not None
        and state.record.entitlement_tier in {"pro", "max"}
        and state.record.outcome
        in {
            "verifiedActivePro",
            "verifiedActiveMax",
            "verifiedGracePeriodPro",
            "verifiedGracePeriodMax",
        }
    ]
    candidates = active or records
    return max(
        candidates,
        key=lambda state: (
            _tier_rank(state.record.entitlement_tier if state.record else "none"),
            state.last_event_id,
        ),
    ).record


def _tier_rank(tier: str) -> int:
    if tier == "max":
        return 2
    if tier == "pro":
        return 1
    return 0


def _event_sort_key(event: SubscriptionEvent) -> tuple[int, int, str, int]:
    event_order = _parse_event_time(event.event_time)
    if event_order is not None:
        return (0, event_order[0], event_order[1], event.event_id)
    server_order = _parse_event_time(event.server_time)
    if server_order is not None:
        return (1, server_order[0], server_order[1], event.event_id)
    return (2, event.event_id, "", event.event_id)


def _parse_event_time(value: Optional[str]) -> Optional[tuple[int, str]]:
    if value is None:
        return None
    stripped = str(value).strip()
    if not stripped:
        return None
    if stripped.isdigit():
        try:
            timestamp = int(stripped)
        except ValueError:
            return None
        if timestamp <= 10_000_000_000:
            timestamp *= 1000
        return (timestamp, stripped)
    candidate = stripped
    if candidate.endswith("Z"):
        candidate = f"{candidate[:-1]}+00:00"
    try:
        parsed = datetime.fromisoformat(candidate)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return (int(parsed.timestamp() * 1000), stripped)


def _binding_user_id_for_event(event: SubscriptionEvent) -> Optional[str]:
    authenticated = _first_text(event.raw_payload, "authenticatedUserId")
    if authenticated is not None:
        return authenticated
    if _first_text(event.raw_payload, "legacyEndpoint") is not None:
        return None
    return event.user_id


def _claim_conflict_reason(
    event: SubscriptionEvent,
    *,
    binding_user_id: Optional[str],
    app_token_claims: Mapping[str, str],
    original_transaction_claims: Mapping[str, str],
) -> Optional[str]:
    if binding_user_id is None:
        return None
    app_token = _first_text(event.raw_payload, "appAccountToken")
    original_transaction_id = _first_text(event.raw_payload, "originalTransactionId")
    if app_token is not None and app_token_claims.get(app_token, binding_user_id) != binding_user_id:
        return "app_account_token_claim_conflict"
    if (
        original_transaction_id is not None
        and original_transaction_claims.get(original_transaction_id, binding_user_id)
        != binding_user_id
    ):
        return "original_transaction_claim_conflict"
    return None


def _record_claims(
    event: SubscriptionEvent,
    *,
    binding_user_id: Optional[str],
    app_token_claims: dict[str, str],
    original_transaction_claims: dict[str, str],
) -> None:
    if binding_user_id is None:
        return
    app_token = _first_text(event.raw_payload, "appAccountToken")
    original_transaction_id = _first_text(event.raw_payload, "originalTransactionId")
    if app_token is not None:
        app_token_claims.setdefault(app_token, binding_user_id)
    if original_transaction_id is not None:
        original_transaction_claims.setdefault(original_transaction_id, binding_user_id)


def _first_text(payload: Any, *keys: str) -> Optional[str]:
    if not isinstance(payload, Mapping):
        return None
    for key in keys:
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None
