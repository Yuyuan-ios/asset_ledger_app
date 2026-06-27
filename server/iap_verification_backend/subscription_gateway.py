from __future__ import annotations

import dataclasses
import hashlib
from typing import Any, Dict, Mapping, Optional, Protocol

from auth import require_text
from config import MAX_YEARLY_PRODUCT_ID, PRO_YEARLY_PRODUCT_ID
from http_helpers import HttpError
from subscription_storage_gateway import (
    EntitlementClaimConflict,
    EntitlementDBGateway,
)
from subscription_audit_log import SubscriptionAuditLog
from subscription_authority_resolver import SubscriptionAuthorityResolver
from subscription_event_ordering import SubscriptionEventOrdering
from subscription_event_model import (
    event_kind_for_subscription_event,
    event_type_for_payload,
    normalized_status,
    payload_hash,
    state_for_subscription_event,
)
from subscription_event_store import SubscriptionEventReplay, SubscriptionEventStore
from entitlement_projection_store import EntitlementProjectionStore
from subscription_replay_engine import SubscriptionReplayEngine
from subscription_state_machine import (
    STATE_ACTIVE,
    STATE_EXPIRED,
    STATE_GRACE,
    STATE_NONE,
    STATE_REVOKED,
    StateTransitionResult,
    SubscriptionStateMachine,
)
from verifier import EntitlementRecord, OUTCOME_TO_TIER, PurchaseVerificationRequest


@dataclasses.dataclass(frozen=True)
class PurchaseEvent:
    user_id: str
    channel: str
    product_id: str
    transaction_id: str
    signature: Optional[str]
    raw_payload: Mapping[str, Any]
    event_time: Optional[str] = None
    source: Optional[str] = None
    event_version: Optional[int] = None


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
    """Pure entitlement decision engine for verified purchase events."""

    def __init__(self, store: EntitlementDBGateway, allowed_products: tuple[str, ...]):
        self.store = store
        self.allowed_products = tuple(allowed_products)

    def apply(self, event: PurchaseEvent, *, state: Optional[str] = None) -> EntitlementRecord:
        return self.record_for_event(event, state=state)

    def record_for_event(
        self,
        event: PurchaseEvent,
        *,
        state: Optional[str] = None,
    ) -> EntitlementRecord:
        tier = self._tier_for_product_id(event.product_id)
        outcome = self._outcome_for_event(event, tier, state=state)
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

    def _outcome_for_event(
        self,
        event: PurchaseEvent,
        tier: str,
        *,
        state: Optional[str] = None,
    ) -> str:
        legacy_outcome = event.raw_payload.get("legacyOutcome")
        if state == STATE_NONE and legacy_outcome in {
            "verificationFailed",
            "verificationUnavailable",
        }:
            return str(legacy_outcome)
        if state == STATE_ACTIVE:
            if tier == "max":
                return "verifiedActiveMax"
            if tier == "pro":
                return "verifiedActivePro"
            return "noActiveEntitlement"
        if state == STATE_GRACE:
            if tier == "max":
                return "verifiedGracePeriodMax"
            if tier == "pro":
                return "verifiedGracePeriodPro"
            return "noActiveEntitlement"
        if state == STATE_REVOKED:
            return "revoked"
        if state == STATE_EXPIRED:
            if normalized_status(event.raw_payload) == "billing_retry":
                return "billingRetry"
            return "expired"
        if state == STATE_NONE:
            return "noActiveEntitlement"

        status = normalized_status(event.raw_payload)
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
        store: EntitlementDBGateway,
        adapters: Mapping[str, PaymentChannelAdapter],
        entitlement_engine: EntitlementEngine,
        authority_resolver: Optional[SubscriptionAuthorityResolver] = None,
        ordering_layer: Optional[SubscriptionEventOrdering] = None,
        state_machine: Optional[SubscriptionStateMachine] = None,
        audit_log: Optional[SubscriptionAuditLog] = None,
        event_store: Optional[SubscriptionEventStore] = None,
        projection_store: Optional[EntitlementProjectionStore] = None,
        replay_engine: Optional[SubscriptionReplayEngine] = None,
    ):
        self.store = store
        self.adapters = dict(adapters)
        self.entitlement_engine = entitlement_engine
        self.authority_resolver = authority_resolver or SubscriptionAuthorityResolver()
        self.ordering_layer = ordering_layer or SubscriptionEventOrdering(store)
        self.state_machine = state_machine or SubscriptionStateMachine()
        self.audit_log = audit_log or SubscriptionAuditLog(store)
        self.event_store = event_store or SubscriptionEventStore(store)
        self.projection_store = projection_store or EntitlementProjectionStore(store)
        self.replay_engine = replay_engine or SubscriptionReplayEngine(
            event_store=self.event_store,
            projection_store=self.projection_store,
            entitlement_engine=self.entitlement_engine,
            state_machine=self.state_machine,
        )

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
        requested_state = _state_for_event(event)
        authority = self.authority_resolver.resolve(event, None)
        self.audit_log.record_raw_event(
            event,
            authority_score=authority.authority_score,
        )

        self.entitlement_engine.record_for_event(
            event,
            state=requested_state or STATE_NONE,
        )
        try:
            append_result = self.event_store.append_with_result(
                event,
                authority_score=authority.authority_score,
                event_type=event_type_for_payload(event.raw_payload),
                payload_digest=payload_hash(payload),
            )
        except SubscriptionEventReplay as exc:
            raise HttpError(
                409,
                "replay_attack",
                "transaction_id was already processed with different payload",
            ) from exc
        if not append_result.appended:
            record = self.store.get_latest_entitlement_for_user(event.user_id)
            self.audit_log.record_processed_event(
                event,
                authority_score=authority.authority_score,
                previous_state=STATE_NONE,
                new_state=STATE_NONE,
                reason="duplicate_transaction_ignored",
            )
            return self._response("ignored", event, record)

        try:
            replayed = self.replay_engine.replay(event.user_id, update_projection=True)
        except EntitlementClaimConflict as exc:
            raise HttpError(
                409,
                "subscription_bound_to_other_user",
                "subscription is already bound to another account",
            ) from exc
        decision = replayed.decision_for_event_id(append_result.event_id)
        product_state = replayed.product_states.get(event.product_id)
        event_is_current_projection = (
            product_state is not None
            and product_state.last_event_id == append_result.event_id
        )
        record = (
            decision.record
            if (
                event_is_current_projection
                and decision is not None
                and decision.record is not None
            )
            else replayed.current_entitlement
        )
        previous_state = decision.previous_state if decision is not None else STATE_NONE
        new_state = decision.new_state if decision is not None else previous_state
        reason = decision.reason if decision is not None else "event_replay_missing_decision"
        if decision is not None and decision.applied and not event_is_current_projection:
            reason = "stale_event_ignored"
        self.audit_log.record_processed_event(
            event,
            authority_score=authority.authority_score,
            previous_state=previous_state,
            new_state=new_state,
            reason=reason,
        )
        if decision is not None and decision.applied and event_is_current_projection:
            self.audit_log.record_entitlement_change(
                event,
                authority_score=authority.authority_score,
                previous_state=previous_state,
                new_state=new_state,
                reason="entitlement_projection_replayed",
            )
        if decision is None or not decision.applied or not event_is_current_projection:
            status = "ignored"
        else:
            status = "applied" if record and record.entitlement_tier != "none" else "rejected"
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

    def forward_to_entitlement_engine(
        self,
        event: PurchaseEvent,
        *,
        transition: StateTransitionResult,
        authority_score: int,
    ) -> EntitlementRecord:
        append_result = self.event_store.append_with_result(
            event,
            authority_score=authority_score,
            event_type=event_type_for_payload(event.raw_payload),
            payload_digest=payload_hash(event.raw_payload),
        )
        replayed = self.replay_engine.replay(event.user_id, update_projection=True)
        decision = replayed.decision_for_event_id(append_result.event_id)
        if decision is not None and decision.record is not None:
            return decision.record
        if replayed.current_entitlement is not None:
            return replayed.current_entitlement
        return self.entitlement_engine.apply(event, state=transition.new_state)

    def commit_legacy_apple_record(
        self,
        request: PurchaseVerificationRequest,
        record: EntitlementRecord,
        *,
        server_user_id: Optional[str] = None,
    ) -> EntitlementRecord:
        event = _legacy_event_for_record(request, record, server_user_id=server_user_id)
        requested_state = _state_for_entitlement_record(record)
        authority = self.authority_resolver.resolve(event, None)
        self.audit_log.record_raw_event(event, authority_score=authority.authority_score)
        try:
            append_result = self.event_store.append_with_result(
                event,
                authority_score=authority.authority_score,
                event_type=event_type_for_payload(event.raw_payload),
                payload_digest=payload_hash(event.raw_payload),
            )
        except SubscriptionEventReplay as exc:
            raise HttpError(
                409,
                "replay_attack",
                "transaction_id was already processed with different payload",
            ) from exc
        try:
            replayed = self.replay_engine.replay(event.user_id, update_projection=True)
        except EntitlementClaimConflict as exc:
            raise HttpError(
                409,
                "subscription_bound_to_other_user",
                "subscription is already bound to another account",
            ) from exc
        decision = replayed.decision_for_event_id(append_result.event_id)
        persisted = (
            decision.record
            if decision is not None and decision.record is not None
            else self.store.get_entitlement(record.app_account_token)
            or replayed.current_entitlement
            or record
        )
        previous_state = decision.previous_state if decision is not None else STATE_NONE
        new_state = decision.new_state if decision is not None else requested_state
        reason = decision.reason if decision is not None else "duplicate_transaction_ignored"
        self.audit_log.record_processed_event(
            event,
            authority_score=authority.authority_score,
            previous_state=previous_state,
            new_state=new_state,
            reason=reason,
        )
        if decision is not None and decision.applied:
            self.audit_log.record_entitlement_change(
                event,
                authority_score=authority.authority_score,
                previous_state=previous_state,
                new_state=new_state,
                reason="legacy_entitlement_projection_replayed",
            )
        return persisted

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
    return normalized_status(raw_payload)


def _state_for_event(event: PurchaseEvent) -> Optional[str]:
    return state_for_subscription_event(event)


def _event_kind_for_event(event: PurchaseEvent, previous_state: str) -> str:
    return event_kind_for_subscription_event(event, previous_state)


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


def _state_for_entitlement_record(record: EntitlementRecord) -> str:
    if record.outcome in {"verifiedActivePro", "verifiedActiveMax"}:
        return STATE_ACTIVE
    if record.outcome in {"verifiedGracePeriodPro", "verifiedGracePeriodMax"}:
        return STATE_GRACE
    if record.outcome == "revoked":
        return STATE_REVOKED
    if record.outcome in {"billingRetry", "expired"}:
        return STATE_EXPIRED
    return STATE_NONE


def _legacy_event_for_record(
    request: PurchaseVerificationRequest,
    record: EntitlementRecord,
    *,
    server_user_id: Optional[str],
) -> PurchaseEvent:
    user_id = server_user_id or f"legacy-app-account:{request.app_account_token}"
    transaction_id = (
        record.latest_transaction_id
        or request.purchase_id
        or record.original_transaction_id
        or request.app_account_token
    )
    legacy_event_digest = hashlib.sha256(
        (
            f"{transaction_id}:{record.outcome}:{request.server_verification_data}:"
            f"{server_user_id or ''}"
        ).encode("utf-8")
    ).hexdigest()[:16]
    return PurchaseEvent(
        user_id=user_id,
        channel="apple",
        product_id=request.product_id,
        transaction_id=f"legacy:{transaction_id}:{legacy_event_digest}",
        signature=request.server_verification_data,
        raw_payload={
            "appAccountToken": request.app_account_token,
            "normalizedStatus": _legacy_status_for_record(record),
            "originalTransactionId": record.original_transaction_id,
            "latestTransactionId": record.latest_transaction_id,
            "expiresAt": record.expires_at,
            "revokedAt": record.revoked_at,
            "environment": record.environment,
            "source": request.source,
            "legacyEndpoint": "/iap/apple/verify-purchase",
            "legacyOutcome": record.outcome,
            "authenticatedUserId": server_user_id or "",
        },
        event_time=None,
        source=request.source,
    )


def _legacy_status_for_record(record: EntitlementRecord) -> str:
    if record.outcome in {"verifiedActivePro", "verifiedActiveMax"}:
        return "active"
    if record.outcome in {"verifiedGracePeriodPro", "verifiedGracePeriodMax"}:
        return "grace"
    if record.outcome == "revoked":
        return "revoked"
    if record.outcome == "billingRetry":
        return "billing_retry"
    if record.outcome == "expired":
        return "expired"
    return "none"
