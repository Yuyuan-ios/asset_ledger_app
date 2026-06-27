from __future__ import annotations

import dataclasses
from typing import Any, Mapping, Optional, Protocol

from subscription_audit_log import SubscriptionAuditLog
from subscription_state_machine import (
    STATE_ACTIVE,
    STATE_EXPIRED,
    STATE_GRACE,
    STATE_NONE,
    STATE_REVOKED,
    SubscriptionStateMachine,
)
from subscription_gateway import EntitlementEngine, PurchaseEvent


@dataclasses.dataclass(frozen=True)
class ProviderSubscriptionState:
    state: str
    channel: str
    transaction_id: Optional[str] = None
    event_time: Optional[str] = None
    authority_score: int = 100
    raw_payload: Optional[Mapping[str, Any]] = None


class SubscriptionProviderVerifier(Protocol):
    def verify(
        self,
        *,
        user_id: str,
        product_id: str,
        current_entitlement: Any,
    ) -> ProviderSubscriptionState:
        ...


class SubscriptionReconciliationWorker:
    """Logical reconciliation worker; scheduling is intentionally external."""

    def __init__(
        self,
        *,
        store: Any,
        provider_verifiers: Mapping[str, SubscriptionProviderVerifier],
        entitlement_engine: EntitlementEngine,
        state_machine: Optional[SubscriptionStateMachine] = None,
        audit_log: Optional[SubscriptionAuditLog] = None,
    ):
        self.store = store
        self.provider_verifiers = dict(provider_verifiers)
        self.entitlement_engine = entitlement_engine
        self.state_machine = state_machine or SubscriptionStateMachine()
        self.audit_log = audit_log or SubscriptionAuditLog(store)

    def reconcile_active_entitlements(self) -> dict[str, int]:
        scanned = 0
        repaired = 0
        skipped = 0
        for entitlement in self.store.list_active_entitlements():
            scanned += 1
            user_id = entitlement.user_id
            product_id = entitlement.product_id
            if not user_id or not product_id:
                skipped += 1
                continue
            current_state = self.store.get_subscription_state(user_id, product_id)
            channel = current_state.channel if current_state else entitlement.environment
            verifier = self.provider_verifiers.get(channel or "")
            if verifier is None:
                skipped += 1
                continue
            provider_state = verifier.verify(
                user_id=user_id,
                product_id=product_id,
                current_entitlement=entitlement,
            )
            if self._repair_from_provider_state(entitlement, current_state, provider_state):
                repaired += 1
            else:
                skipped += 1
        return {"scanned": scanned, "repaired": repaired, "skipped": skipped}

    def _repair_from_provider_state(
        self,
        entitlement: Any,
        current_state: Optional[Any],
        provider_state: ProviderSubscriptionState,
    ) -> bool:
        previous_state = current_state.state if current_state else STATE_ACTIVE
        requested_state = provider_state.state
        event_kind = "reconciliation"
        reason = "reconciliation_noop"
        if requested_state == STATE_ACTIVE:
            event_kind = "reconciliation_recovery"
            reason = "reconciliation_upgrade"
        elif requested_state in {STATE_EXPIRED, STATE_REVOKED, STATE_NONE}:
            if previous_state == STATE_ACTIVE:
                requested_state = STATE_GRACE
                reason = "reconciliation_downgrade_to_grace"
            else:
                self._audit_noop(entitlement, current_state, provider_state, "reconciliation_downgrade_noop")
                return False

        transition = self.state_machine.transition(
            previous_state,
            requested_state,
            event_kind=event_kind,
        )
        event = self._event_for_repair(entitlement, provider_state, transition.new_state)
        if transition.safe_no_op:
            self.audit_log.record_processed_event(
                event,
                authority_score=provider_state.authority_score,
                previous_state=transition.previous_state,
                new_state=transition.new_state,
                reason=transition.reason,
            )
            return False
        if not transition.changed:
            self.audit_log.record_processed_event(
                event,
                authority_score=provider_state.authority_score,
                previous_state=transition.previous_state,
                new_state=transition.new_state,
                reason="reconciliation_noop",
            )
            return False
        record = self.entitlement_engine.apply(event, state=transition.new_state)
        self.store.upsert_entitlement(record, user_id=entitlement.user_id)
        self.store.upsert_subscription_state(
            user_id=event.user_id,
            product_id=event.product_id,
            state=transition.new_state,
            authority_score=max(
                provider_state.authority_score,
                current_state.authority_score if current_state else 0,
            ),
            event_time=provider_state.event_time,
            event_version=current_state.event_version if current_state else 0,
            channel=event.channel,
            transaction_id=event.transaction_id,
        )
        self.audit_log.record_entitlement_change(
            event,
            authority_score=provider_state.authority_score,
            previous_state=transition.previous_state,
            new_state=transition.new_state,
            reason=reason,
        )
        return transition.changed

    def _audit_noop(
        self,
        entitlement: Any,
        current_state: Optional[Any],
        provider_state: ProviderSubscriptionState,
        reason: str,
    ) -> None:
        previous_state = current_state.state if current_state else STATE_NONE
        event = self._event_for_repair(entitlement, provider_state, previous_state)
        self.audit_log.record_processed_event(
            event,
            authority_score=provider_state.authority_score,
            previous_state=previous_state,
            new_state=previous_state,
            reason=reason,
        )

    def _event_for_repair(
        self,
        entitlement: Any,
        provider_state: ProviderSubscriptionState,
        final_state: str,
    ) -> PurchaseEvent:
        raw_payload = dict(provider_state.raw_payload or {})
        raw_payload.update(
            {
                "appAccountToken": entitlement.app_account_token,
                "normalizedStatus": _status_for_state(final_state),
                "originalTransactionId": entitlement.original_transaction_id,
                "latestTransactionId": provider_state.transaction_id
                or entitlement.latest_transaction_id,
                "expiresAt": entitlement.expires_at,
                "environment": provider_state.channel,
                "source": "reconciliation",
            }
        )
        return PurchaseEvent(
            user_id=entitlement.user_id,
            channel=provider_state.channel,
            product_id=entitlement.product_id,
            transaction_id=provider_state.transaction_id
            or entitlement.latest_transaction_id
            or f"reconcile:{entitlement.user_id}:{entitlement.product_id}",
            signature=None,
            raw_payload=raw_payload,
            event_time=provider_state.event_time,
            source="reconciliation",
        )


def _status_for_state(state: str) -> str:
    if state == STATE_ACTIVE:
        return "active"
    if state == STATE_GRACE:
        return "grace"
    if state == STATE_REVOKED:
        return "revoked"
    return "expired"
