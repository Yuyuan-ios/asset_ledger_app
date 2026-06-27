from __future__ import annotations

import dataclasses
import hashlib
import json
from typing import Any, Dict, Mapping, Optional, Protocol

from auth import require_text
from config import MAX_YEARLY_PRODUCT_ID, PRO_YEARLY_PRODUCT_ID
from http_helpers import HttpError
from runtime_write_firewall import RuntimeWriteContext, RuntimeWriteFirewall
from subscription_storage_gateway import EntitlementDBGateway, PurchaseTransactionReplay
from subscription_audit_log import SubscriptionAuditLog
from subscription_authority_resolver import SubscriptionAuthorityResolver
from subscription_event_ordering import SubscriptionEventOrdering
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
            if _normalized_status(event.raw_payload) == "billing_retry":
                return "billingRetry"
            return "expired"
        if state == STATE_NONE:
            return "noActiveEntitlement"

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
        store: EntitlementDBGateway,
        adapters: Mapping[str, PaymentChannelAdapter],
        entitlement_engine: EntitlementEngine,
        authority_resolver: Optional[SubscriptionAuthorityResolver] = None,
        ordering_layer: Optional[SubscriptionEventOrdering] = None,
        state_machine: Optional[SubscriptionStateMachine] = None,
        audit_log: Optional[SubscriptionAuditLog] = None,
    ):
        self.store = store
        self.adapters = dict(adapters)
        self.entitlement_engine = entitlement_engine
        self.authority_resolver = authority_resolver or SubscriptionAuthorityResolver()
        self.ordering_layer = ordering_layer or SubscriptionEventOrdering(store)
        self.state_machine = state_machine or SubscriptionStateMachine()
        self.audit_log = audit_log or SubscriptionAuditLog(store)

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
        current_state = self.store.get_subscription_state(event.user_id, event.product_id)
        requested_state = _state_for_event(event)
        authority = self.authority_resolver.resolve(event, current_state)
        self.audit_log.record_raw_event(
            event,
            authority_score=authority.authority_score,
        )
        if requested_state is None:
            self.audit_log.record_processed_event(
                event,
                authority_score=authority.authority_score,
                previous_state=current_state.state if current_state else STATE_NONE,
                new_state=current_state.state if current_state else STATE_NONE,
                reason="undecidable_purchase_status",
            )
            record = self.store.get_latest_entitlement_for_user(event.user_id)
            return self._response("ignored", event, record)

        record_preview = self.entitlement_engine.record_for_event(
            event,
            state=requested_state,
        )
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
            self.audit_log.record_processed_event(
                event,
                authority_score=authority.authority_score,
                previous_state=current_state.state if current_state else STATE_NONE,
                new_state=current_state.state if current_state else STATE_NONE,
                reason="duplicate_transaction_ignored",
            )
            return self._response("ignored", event, record)

        if not authority.accepted:
            record = self.store.get_latest_entitlement_for_user(event.user_id)
            self.audit_log.record_processed_event(
                event,
                authority_score=authority.authority_score,
                previous_state=current_state.state if current_state else STATE_NONE,
                new_state=current_state.state if current_state else STATE_NONE,
                reason=authority.reason,
            )
            return self._response("ignored", event, record)

        ordering = self.ordering_layer.evaluate(event, current_state)
        if not ordering.accepted:
            record = self.store.get_latest_entitlement_for_user(event.user_id)
            self.audit_log.record_processed_event(
                dataclasses.replace(
                    event,
                    event_time=ordering.event_time,
                    event_version=ordering.event_version,
                ),
                authority_score=authority.authority_score,
                previous_state=current_state.state if current_state else STATE_NONE,
                new_state=current_state.state if current_state else STATE_NONE,
                reason=ordering.reason,
            )
            return self._response("ignored", event, record)

        event = dataclasses.replace(
            event,
            event_time=ordering.event_time,
            event_version=ordering.event_version,
        )
        previous_state = current_state.state if current_state else STATE_NONE
        transition = self.state_machine.transition(
            previous_state,
            requested_state,
            event_kind=_event_kind_for_event(event, previous_state),
        )
        if transition.safe_no_op:
            record = self.store.get_latest_entitlement_for_user(event.user_id)
            self.audit_log.record_processed_event(
                event,
                authority_score=authority.authority_score,
                previous_state=transition.previous_state,
                new_state=transition.new_state,
                reason=transition.reason,
            )
            return self._response("ignored", event, record)

        record = self.forward_to_entitlement_engine(
            event,
            transition=transition,
            authority_score=authority.authority_score,
        )
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

    def forward_to_entitlement_engine(
        self,
        event: PurchaseEvent,
        *,
        transition: StateTransitionResult,
        authority_score: int,
    ) -> EntitlementRecord:
        record = self.entitlement_engine.apply(event, state=transition.new_state)
        write_context = RuntimeWriteContext.gateway(
            operation="gateway_apply_entitlement",
            route="SubscriptionGatewayService.forward_to_entitlement_engine",
            user_id=event.user_id,
            product_id=event.product_id,
            transaction_id=event.transaction_id,
        )
        with RuntimeWriteFirewall.activate(write_context):
            persisted = self.store.upsert_entitlement(record, user_id=event.user_id)
            self.store.upsert_subscription_state(
                user_id=event.user_id,
                product_id=event.product_id,
                state=transition.new_state,
                authority_score=authority_score,
                event_time=event.event_time,
                event_version=event.event_version or 0,
                channel=event.channel,
                transaction_id=event.transaction_id,
            )
        self.audit_log.record_processed_event(
            event,
            authority_score=authority_score,
            previous_state=transition.previous_state,
            new_state=transition.new_state,
            reason=transition.reason,
        )
        self.audit_log.record_entitlement_change(
            event,
            authority_score=authority_score,
            previous_state=transition.previous_state,
            new_state=transition.new_state,
            reason="entitlement_state_applied",
        )
        return persisted

    def commit_legacy_apple_record(
        self,
        request: PurchaseVerificationRequest,
        record: EntitlementRecord,
        *,
        server_user_id: Optional[str] = None,
    ) -> EntitlementRecord:
        event = _legacy_event_for_record(request, record, server_user_id=server_user_id)
        current_state = self.store.get_subscription_state(event.user_id, event.product_id)
        requested_state = _state_for_entitlement_record(record)
        authority = self.authority_resolver.resolve(event, current_state)
        self.audit_log.record_raw_event(event, authority_score=authority.authority_score)

        if not authority.accepted:
            self.audit_log.record_processed_event(
                event,
                authority_score=authority.authority_score,
                previous_state=current_state.state if current_state else STATE_NONE,
                new_state=current_state.state if current_state else STATE_NONE,
                reason=authority.reason,
            )
            return self.store.get_entitlement(record.app_account_token) or record

        ordering = self.ordering_layer.evaluate(event, current_state)
        if not ordering.accepted:
            self.audit_log.record_processed_event(
                dataclasses.replace(
                    event,
                    event_time=ordering.event_time,
                    event_version=ordering.event_version,
                ),
                authority_score=authority.authority_score,
                previous_state=current_state.state if current_state else STATE_NONE,
                new_state=current_state.state if current_state else STATE_NONE,
                reason=ordering.reason,
            )
            return self.store.get_entitlement(record.app_account_token) or record

        event = dataclasses.replace(
            event,
            event_time=ordering.event_time,
            event_version=ordering.event_version,
        )
        previous_state = current_state.state if current_state else STATE_NONE
        transition = self.state_machine.transition(
            previous_state,
            requested_state,
            event_kind=_event_kind_for_event(event, previous_state),
        )
        if transition.safe_no_op:
            self.audit_log.record_processed_event(
                event,
                authority_score=authority.authority_score,
                previous_state=transition.previous_state,
                new_state=transition.new_state,
                reason=transition.reason,
            )
            return self.store.get_entitlement(record.app_account_token) or record

        entitlement_user_id = server_user_id
        write_context = RuntimeWriteContext.gateway(
            operation="legacy_apple_gateway_commit",
            route="/iap/apple/verify-purchase",
            user_id=event.user_id,
            product_id=event.product_id,
            transaction_id=event.transaction_id,
        )
        with RuntimeWriteFirewall.activate(write_context):
            persisted = self.store.upsert_entitlement(record, user_id=entitlement_user_id)
            self.store.upsert_subscription_state(
                user_id=event.user_id,
                product_id=event.product_id,
                state=transition.new_state,
                authority_score=authority.authority_score,
                event_time=event.event_time,
                event_version=event.event_version or 0,
                channel=event.channel,
                transaction_id=event.transaction_id,
            )
        self.audit_log.record_processed_event(
            event,
            authority_score=authority.authority_score,
            previous_state=transition.previous_state,
            new_state=transition.new_state,
            reason=transition.reason,
        )
        self.audit_log.record_entitlement_change(
            event,
            authority_score=authority.authority_score,
            previous_state=transition.previous_state,
            new_state=transition.new_state,
            reason="legacy_entitlement_state_applied",
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


def _state_for_event(event: PurchaseEvent) -> Optional[str]:
    status = _normalized_status(event.raw_payload)
    if status == "active":
        return STATE_ACTIVE
    if status == "grace":
        return STATE_GRACE
    if status in {"billing_retry", "expired"}:
        return STATE_EXPIRED
    if status == "revoked":
        return STATE_REVOKED
    return None


def _event_kind_for_event(event: PurchaseEvent, previous_state: str) -> str:
    for key in ("eventType", "event_type", "notificationType", "subtype"):
        value = event.raw_payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip().lower().replace("-", "_")
    status = _normalized_status(event.raw_payload)
    if status == "active" and previous_state == STATE_NONE:
        return "initial_purchase"
    return "status_update"


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
    return PurchaseEvent(
        user_id=user_id,
        channel="apple",
        product_id=request.product_id,
        transaction_id=transaction_id,
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
