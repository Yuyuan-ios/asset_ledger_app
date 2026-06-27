from __future__ import annotations

import dataclasses
import json
from typing import Any, Mapping, Optional

from subscription_authority_resolver import normalize_authority_source
from subscription_event_model import (
    event_kind_for_subscription_event,
    normalized_status,
)


class ExplanationIntegrityError(RuntimeError):
    pass


@dataclasses.dataclass(frozen=True)
class EventExplanation:
    event_id: int
    user_id: str
    trigger_source: str
    event_type: str
    causal_reason: str
    rule_applied: str
    decision_chain: list[dict[str, Any]]
    state_transition: dict[str, str]
    authority_context: dict[str, Any]
    integrity_context: dict[str, bool]
    explanation_text: str

    @classmethod
    def from_dict(cls, payload: Mapping[str, Any]) -> "EventExplanation":
        return cls(
            event_id=int(payload["event_id"]),
            user_id=str(payload["user_id"]),
            trigger_source=str(payload["trigger_source"]),
            event_type=str(payload["event_type"]),
            causal_reason=str(payload["causal_reason"]),
            rule_applied=str(payload["rule_applied"]),
            decision_chain=[dict(step) for step in payload["decision_chain"]],
            state_transition=dict(payload["state_transition"]),
            authority_context=dict(payload["authority_context"]),
            integrity_context=dict(payload["integrity_context"]),
            explanation_text=str(payload["explanation_text"]),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "event_id": self.event_id,
            "user_id": self.user_id,
            "trigger_source": self.trigger_source,
            "event_type": self.event_type,
            "causal_reason": self.causal_reason,
            "rule_applied": self.rule_applied,
            "decision_chain": [dict(step) for step in self.decision_chain],
            "state_transition": dict(self.state_transition),
            "authority_context": dict(self.authority_context),
            "integrity_context": dict(self.integrity_context),
            "explanation_text": self.explanation_text,
        }

    def canonical_json(self) -> str:
        return json.dumps(
            self.to_dict(),
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=True,
        )


class SubscriptionEventExplainer:
    """Builds deterministic, read-only causal explanations for replay decisions."""

    def explain(self, event: Any, context: Mapping[str, Any]) -> EventExplanation:
        decision = context.get("decision")
        if decision is None:
            raise ExplanationIntegrityError("missing replay decision for explanation")
        previous_state = str(getattr(decision, "previous_state", "NONE"))
        new_state = str(getattr(decision, "new_state", previous_state))
        event_id = int(getattr(event, "event_id", getattr(decision, "event_id", 0)))
        if event_id != int(getattr(decision, "event_id", event_id)):
            raise ExplanationIntegrityError("explanation event_id does not match replay decision")

        authority_source = _authority_source(event)
        trigger_source = _trigger_source(event, authority_source)
        event_type = str(getattr(event, "event_type", "") or "").upper()
        authority_score = int(getattr(event, "authority_score", 0) or 0)
        reason = str(getattr(decision, "reason", "") or "unknown")
        rule_applied = _rule_applied(event, decision, reason)
        override_reason = _override_reason(
            trigger_source=trigger_source,
            authority_score=authority_score,
            previous_state=previous_state,
            new_state=new_state,
            reason=reason,
            applied=bool(getattr(decision, "applied", False)),
        )
        causal_reason = _causal_reason(
            event=event,
            trigger_source=trigger_source,
            decision=decision,
            reason=reason,
            previous_state=previous_state,
            new_state=new_state,
        )
        authority_context: dict[str, Any] = {
            "source": authority_source,
            "authority_score": authority_score,
        }
        if override_reason is not None:
            authority_context["override_reason"] = override_reason
        integrity_context = {
            "hash_verified": _chain_valid(context.get("integrity_result")),
            "replay_verified": bool(context.get("replay_verified", True)),
        }
        state_transition = {
            "previous_state": previous_state,
            "new_state": new_state,
        }
        explanation = EventExplanation(
            event_id=event_id,
            user_id=str(getattr(event, "user_id", "")),
            trigger_source=trigger_source,
            event_type=event_type,
            causal_reason=causal_reason,
            rule_applied=rule_applied,
            decision_chain=_decision_chain(
                event=event,
                decision=decision,
                trigger_source=trigger_source,
                authority_source=authority_source,
                authority_score=authority_score,
                previous_state=previous_state,
                new_state=new_state,
                rule_applied=rule_applied,
            ),
            state_transition=state_transition,
            authority_context=authority_context,
            integrity_context=integrity_context,
            explanation_text=_explanation_text(
                event=event,
                decision=decision,
                trigger_source=trigger_source,
                rule_applied=rule_applied,
                causal_reason=causal_reason,
                previous_state=previous_state,
                new_state=new_state,
            ),
        )
        _assert_matches_decision(explanation, decision)
        return explanation


def explanation_from_json(value: str) -> EventExplanation:
    return EventExplanation.from_dict(json.loads(value))


def _authority_source(event: Any) -> str:
    source = getattr(event, "source", None)
    if isinstance(source, str) and source.strip():
        return normalize_authority_source(source)
    raw_payload = getattr(event, "raw_payload", {})
    if isinstance(raw_payload, Mapping):
        for key in ("authoritySource", "eventSource", "source", "sourceType"):
            value = raw_payload.get(key)
            if isinstance(value, str) and value.strip():
                return normalize_authority_source(value)
    return "verify"


def _trigger_source(event: Any, authority_source: str) -> str:
    if authority_source == "reconciliation":
        return "reconcile"
    if authority_source == "verify":
        return "verify"
    channel = str(getattr(event, "channel", "") or "").strip().lower()
    labels = {
        "apple": "Apple",
        "google_play": "Google",
        "oppo": "OPPO",
        "xiaomi": "XIAOMI",
        "huawei": "HUAWEI",
        "vivo": "VIVO",
    }
    return labels.get(channel, authority_source)


def _rule_applied(event: Any, decision: Any, reason: str) -> str:
    status = normalized_status(getattr(event, "raw_payload", {}))
    if reason == "lower_authority_event_ignored":
        return "authority: higher-authority state wins"
    if reason in {
        "event_time_unorderable",
        "ambiguous_equal_event_time",
        "stale_event_ignored",
    }:
        return "ordering: deterministic event ordering"
    if status == "billing_retry":
        return "retry: billing retry does not unlock entitlement"
    if getattr(decision, "record", None) is not None:
        return "pricing: product_id entitlement tier mapping"
    return f"state_machine: {reason}"


def _override_reason(
    *,
    trigger_source: str,
    authority_score: int,
    previous_state: str,
    new_state: str,
    reason: str,
    applied: bool,
) -> Optional[str]:
    if reason == "lower_authority_event_ignored":
        return "Existing higher authority replay state overrode this lower authority event."
    if applied and authority_score >= 90 and previous_state not in {"NONE", new_state}:
        return (
            f"High authority {trigger_source} event overrode prior "
            f"{previous_state} state."
        )
    return None


def _causal_reason(
    *,
    event: Any,
    trigger_source: str,
    decision: Any,
    reason: str,
    previous_state: str,
    new_state: str,
) -> str:
    event_type = str(getattr(event, "event_type", "") or "event").upper()
    event_reference = _event_reference(event)
    if trigger_source == "reconcile":
        return (
            "Provider reconciliation detected entitlement drift and emitted "
            f"correction event {event_reference}."
        )
    if reason == "lower_authority_event_ignored":
        return (
            f"{event_type} event {event_reference} was ignored because a higher "
            "authority event already controls the replayed state."
        )
    if not bool(getattr(decision, "applied", False)):
        return (
            f"{event_type} event {event_reference} did not change entitlement "
            f"state because replay resolved it as {reason}."
        )
    if previous_state == new_state:
        return (
            f"{trigger_source} {event_type} event {event_reference} confirmed "
            f"the entitlement remains {new_state}."
        )
    return (
        f"{trigger_source} {event_type} event {event_reference} moved entitlement "
        f"from {previous_state} to {new_state}."
    )


def _decision_chain(
    *,
    event: Any,
    decision: Any,
    trigger_source: str,
    authority_source: str,
    authority_score: int,
    previous_state: str,
    new_state: str,
    rule_applied: str,
) -> list[dict[str, Any]]:
    record = getattr(decision, "record", None)
    entitlement_outcome = None if record is None else record.outcome
    return [
        {
            "stage": "event",
            "input": {
                "event_id": int(getattr(event, "event_id", 0)),
                "event_type": str(getattr(event, "event_type", "") or "").upper(),
                "product_id": str(getattr(event, "product_id", "")),
                "channel": str(getattr(event, "channel", "")),
                "trigger_source": trigger_source,
            },
            "outcome": event_kind_for_subscription_event(event, previous_state),
        },
        {
            "stage": "authority",
            "input": {
                "source": authority_source,
                "authority_score": authority_score,
            },
            "outcome": "accepted_for_replay"
            if getattr(decision, "applied", False)
            else str(getattr(decision, "reason", "ignored")),
        },
        {
            "stage": "ordering",
            "input": {
                "event_id": int(getattr(event, "event_id", 0)),
            },
            "outcome": "deterministic_replay_order",
        },
        {
            "stage": "state_machine",
            "input": {
                "previous_state": previous_state,
                "requested_state": new_state,
            },
            "outcome": str(getattr(decision, "reason", "")),
        },
        {
            "stage": "entitlement_engine",
            "input": {
                "product_id": str(getattr(event, "product_id", "")),
            },
            "outcome": entitlement_outcome
            or ("no_state_change" if not getattr(decision, "applied", False) else new_state),
            "rule": rule_applied,
        },
    ]


def _explanation_text(
    *,
    event: Any,
    decision: Any,
    trigger_source: str,
    rule_applied: str,
    causal_reason: str,
    previous_state: str,
    new_state: str,
) -> str:
    record = getattr(decision, "record", None)
    tier = None if record is None else str(record.entitlement_tier).upper()
    tier_text = "" if not tier or tier == "NONE" else f" ({tier})"
    if getattr(decision, "applied", False):
        return (
            f"User was moved from {previous_state} to {new_state}{tier_text} "
            f"because {causal_reason} Rule applied: {rule_applied}."
        )
    return (
        f"User remained in {new_state} because {causal_reason} "
        f"Rule applied: {rule_applied}."
    )


def _event_reference(event: Any) -> str:
    return f"#{int(getattr(event, 'event_id', 0))}"


def _chain_valid(result: Any) -> bool:
    if result is None:
        return False
    return bool(getattr(result, "chain_valid", False))


def _assert_matches_decision(explanation: EventExplanation, decision: Any) -> None:
    if explanation.state_transition.get("previous_state") != str(
        getattr(decision, "previous_state", "")
    ):
        raise ExplanationIntegrityError("explanation previous_state mismatches replay result")
    if explanation.state_transition.get("new_state") != str(getattr(decision, "new_state", "")):
        raise ExplanationIntegrityError("explanation new_state mismatches replay result")
    if explanation.event_id != int(getattr(decision, "event_id", 0)):
        raise ExplanationIntegrityError("explanation event_id mismatches replay result")
