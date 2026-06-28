from __future__ import annotations

import hashlib
import json
from typing import Any, Mapping, Optional

from subscription_decision_graph import (
    NODE_AUTHORITY_RESOLUTION,
    NODE_CORRECTION_EVENT,
    NODE_ENTITLEMENT_DECISION,
    NODE_EVENT,
    NODE_IGNORED_EVENT,
    NODE_INTEGRITY_CHECK,
    NODE_ORDERING_DECISION,
    NODE_PROJECTION,
    NODE_REJECTED_EVENT,
    NODE_STATE_TRANSITION,
    STATUS_APPLIED,
    STATUS_ERROR,
    STATUS_IGNORED,
    STATUS_REJECTED,
    STATUS_VERIFIED,
    STATUS_WARNING,
    DecisionEdge,
    DecisionGraph,
    DecisionNode,
)
from subscription_event_hash_chain import EventHashChain
from subscription_event_store import SubscriptionLedgerIntegrityError
from subscription_observability_sanitizer import sanitize_observability_payload
from subscription_state_machine import STATE_NONE


_IGNORED_REASONS = {
    "lower_authority_event_ignored",
    "stale_event_ignored",
    "ambiguous_equal_event_time",
    "event_time_missing_cannot_override_timed_state",
    "stale_event_version_ignored",
    "duplicate_transaction_ignored",
}


class SubscriptionDecisionGraphBuilder:
    """Builds read-only BOL decision graphs from ledger events and replay trace."""

    def __init__(
        self,
        *,
        event_store: Any,
        replay_engine: Any,
        explanation_store: Optional[Any] = None,
    ):
        self.event_store = event_store
        self.replay_engine = replay_engine
        self.explanation_store = explanation_store

    def build_for_user(self, user_id: str) -> DecisionGraph:
        normalized_user_id = _require_text(user_id, "user_id")
        try:
            replayed = self.replay_engine.replay(
                normalized_user_id,
                update_projection=False,
                include_trace=True,
            )
            events = list(self.event_store.get_events(normalized_user_id))
        except SubscriptionLedgerIntegrityError as exc:
            events = _unchecked_events_for_user(self.event_store, normalized_user_id)
            return self._build_blocked_graph(normalized_user_id, events, exc.result)
        trace = list(getattr(replayed, "replay_trace", []))
        explanations = _explanations_by_event_id(self.explanation_store, normalized_user_id)
        return self._build_graph_from_entries(
            normalized_user_id,
            trace,
            events=events,
            replayed=replayed,
            explanations=explanations,
        )

    def build_for_event(self, event_id: int) -> DecisionGraph:
        normalized_event_id = int(event_id)
        if normalized_event_id <= 0:
            raise ValueError("event_id must be positive")
        try:
            event = self.event_store.get_event_by_id(normalized_event_id)
        except SubscriptionLedgerIntegrityError:
            event = _unchecked_event_by_id(self.event_store, normalized_event_id)
        if event is None:
            raise KeyError(normalized_event_id)
        graph = self.build_for_user(str(getattr(event, "user_id", "")))
        node_ids = {
            node.node_id
            for node in graph.nodes
            if node.event_id == normalized_event_id
        }
        nodes = [node for node in graph.nodes if node.node_id in node_ids]
        edges = [
            edge
            for edge in graph.edges
            if edge.from_node_id in node_ids and edge.to_node_id in node_ids
        ]
        summary = dict(graph.summary)
        summary["focus_event_id"] = normalized_event_id
        return DecisionGraph(
            graph_id=_stable_graph_id(
                graph.user_id,
                [{"event_id": normalized_event_id, "focus": True}],
            ),
            user_id=graph.user_id,
            generated_at=graph.generated_at,
            current_state=graph.current_state,
            current_tier=graph.current_tier,
            nodes=nodes,
            edges=edges,
            summary=summary,
            warnings=list(graph.warnings),
        )

    def build_from_replay_trace(self, user_id: str, replay_trace: Any) -> DecisionGraph:
        normalized_user_id = _require_text(user_id, "user_id")
        entries = [_normalize_trace_entry(entry) for entry in list(replay_trace or [])]
        return self._build_graph_from_entries(normalized_user_id, entries)

    def _build_blocked_graph(
        self,
        user_id: str,
        events: list[Any],
        integrity_result: Any,
    ) -> DecisionGraph:
        entries = []
        broken_event_id = getattr(integrity_result, "broken_event_id", None)
        reason = str(getattr(integrity_result, "reason", "") or "ledger_integrity_failed")
        for event in EventHashChain.chain_order(events):
            event_id = int(getattr(event, "event_id", 0))
            entries.append(
                {
                    "event_id": event_id,
                    "event_type": str(getattr(event, "event_type", "")),
                    "product_id": str(getattr(event, "product_id", "")),
                    "channel": str(getattr(event, "channel", "")),
                    "source": getattr(event, "source", None),
                    "authority_score": int(getattr(event, "authority_score", 0) or 0),
                    "timestamp": getattr(event, "event_time", None)
                    or getattr(event, "server_time", None),
                    "payload_hash": str(getattr(event, "payload_hash", "")),
                    "hash_chain_position": event_id,
                    "previous_state": STATE_NONE,
                    "new_state": STATE_NONE,
                    "applied": False,
                    "status": STATUS_ERROR if event_id == broken_event_id else STATUS_WARNING,
                    "applied_rule": "integrity: replay blocked by hash-chain verification",
                    "integrity_result": {
                        "chain_valid": False,
                        "tamper_detected": bool(
                            getattr(integrity_result, "tamper_detected", True)
                        ),
                        "reason": reason,
                        "broken_event_id": broken_event_id,
                    },
                    "ordering_result": "replay_blocked",
                    "entitlement_result": "not_evaluated",
                    "rejected_reason": reason,
                }
            )
        return self._build_graph_from_entries(
            user_id,
            entries,
            warnings=[f"Replay blocked by ledger integrity verification: {reason}"],
        )

    def _build_graph_from_entries(
        self,
        user_id: str,
        trace: list[Mapping[str, Any]],
        *,
        events: Optional[list[Any]] = None,
        replayed: Optional[Any] = None,
        explanations: Optional[Mapping[int, Any]] = None,
        warnings: Optional[list[str]] = None,
    ) -> DecisionGraph:
        entries = [_normalize_trace_entry(entry) for entry in trace]
        events_by_id = {
            int(getattr(event, "event_id", 0)): event
            for event in EventHashChain.chain_order(events or [])
        }
        explanations = explanations or {}
        nodes: list[DecisionNode] = []
        edges: list[DecisionEdge] = []
        final_deciding_event_id = _final_deciding_event_id(replayed, entries)
        current_state = _current_state(replayed, entries)
        current_tier = _current_tier(replayed, entries)
        for entry in entries:
            event_id = int(entry["event_id"])
            event = events_by_id.get(event_id)
            explanation = explanations.get(event_id)
            entry = _merge_event_context(entry, event, explanation)
            event_node_id = _node_id("event", event_id)
            integrity_node_id = _node_id("integrity", event_id)
            authority_node_id = _node_id("authority", event_id)
            ordering_node_id = _node_id("ordering", event_id)
            branch_node_type = _branch_node_type(entry)
            branch_node_id = _node_id(branch_node_type, event_id)
            status = str(entry["status"])
            nodes.append(
                DecisionNode(
                    node_id=event_node_id,
                    node_type=(
                        NODE_CORRECTION_EVENT
                        if _is_correction_event(entry)
                        else NODE_EVENT
                    ),
                    label=f"Event #{event_id} {entry.get('event_type') or 'subscription'}",
                    status=status,
                    event_id=event_id,
                    timestamp=_optional_text(entry.get("timestamp")),
                    metadata={
                        "event_type": entry.get("event_type"),
                        "product_id": entry.get("product_id"),
                        "channel": entry.get("channel"),
                        "source": entry.get("source"),
                        "payload_hash": entry.get("payload_hash"),
                        "hash_chain_position": entry.get("hash_chain_position"),
                        "event_kind": entry.get("event_kind"),
                    },
                )
            )
            nodes.append(
                DecisionNode(
                    node_id=integrity_node_id,
                    node_type=NODE_INTEGRITY_CHECK,
                    label=f"Integrity check #{event_id}",
                    status=_integrity_status(entry),
                    event_id=event_id,
                    rule_id="ledger_hash_chain",
                    metadata=entry.get("integrity_result", {}),
                )
            )
            nodes.append(
                DecisionNode(
                    node_id=authority_node_id,
                    node_type=NODE_AUTHORITY_RESOLUTION,
                    label=f"Authority resolution #{event_id}",
                    status=STATUS_IGNORED
                    if entry.get("ignored_reason") == "lower_authority_event_ignored"
                    else STATUS_VERIFIED,
                    event_id=event_id,
                    rule_id="authority_score",
                    metadata={
                        "authority_score": entry.get("authority_score"),
                        "source": entry.get("source"),
                        "rule": entry.get("applied_rule"),
                    },
                )
            )
            nodes.append(
                DecisionNode(
                    node_id=ordering_node_id,
                    node_type=NODE_ORDERING_DECISION,
                    label=f"Ordering decision #{event_id}",
                    status=_ordering_status(entry),
                    event_id=event_id,
                    rule_id="deterministic_replay_order",
                    metadata={
                        "ordering_result": entry.get("ordering_result"),
                        "reason": _reason(entry),
                    },
                )
            )
            _append_edge(edges, event_node_id, integrity_node_id, "verifies")
            _append_edge(edges, integrity_node_id, authority_node_id, "authorizes")
            _append_edge(edges, authority_node_id, ordering_node_id, "orders")
            if branch_node_type == NODE_STATE_TRANSITION:
                state_node_id = branch_node_id
                entitlement_node_id = _node_id("entitlement", event_id)
                projection_node_id = _node_id("projection", event_id)
                nodes.append(
                    DecisionNode(
                        node_id=state_node_id,
                        node_type=NODE_STATE_TRANSITION,
                        label=f"State transition #{event_id}",
                        status=STATUS_APPLIED,
                        event_id=event_id,
                        rule_id="subscription_state_machine",
                        metadata={
                            "previous_state": entry.get("previous_state"),
                            "new_state": entry.get("new_state"),
                            "reason": _reason(entry),
                        },
                    )
                )
                nodes.append(
                    DecisionNode(
                        node_id=entitlement_node_id,
                        node_type=NODE_ENTITLEMENT_DECISION,
                        label=f"Entitlement decision #{event_id}",
                        status=_entitlement_status(entry),
                        event_id=event_id,
                        rule_id="entitlement_engine",
                        metadata={
                            "entitlement_result": entry.get("entitlement_result"),
                            "entitlement_tier": entry.get("entitlement_tier"),
                            "is_final_deciding_event": event_id == final_deciding_event_id,
                        },
                    )
                )
                nodes.append(
                    DecisionNode(
                        node_id=projection_node_id,
                        node_type=NODE_PROJECTION,
                        label=f"Projection result #{event_id}",
                        status=STATUS_VERIFIED,
                        event_id=event_id,
                        rule_id="projection_cache_only",
                        metadata={
                            "current_state": current_state,
                            "current_tier": current_tier,
                            "final_deciding_event_id": final_deciding_event_id,
                            "cache_only": True,
                        },
                    )
                )
                _append_edge(edges, ordering_node_id, state_node_id, "applies")
                _append_edge(edges, state_node_id, entitlement_node_id, "derives_entitlement")
                _append_edge(edges, entitlement_node_id, projection_node_id, "projects_cache")
            else:
                nodes.append(
                    DecisionNode(
                        node_id=branch_node_id,
                        node_type=branch_node_type,
                        label=f"{branch_node_type} #{event_id}",
                        status=STATUS_IGNORED
                        if branch_node_type == NODE_IGNORED_EVENT
                        else entry.get("status", STATUS_REJECTED),
                        event_id=event_id,
                        rule_id=str(entry.get("applied_rule") or "replay_decision"),
                        metadata={
                            "reason": _reason(entry),
                            "previous_state": entry.get("previous_state"),
                            "new_state": entry.get("new_state"),
                        },
                    )
                )
                _append_edge(edges, ordering_node_id, branch_node_id, "branches")
        summary = _summary(
            user_id=user_id,
            current_state=current_state,
            current_tier=current_tier,
            final_deciding_event_id=final_deciding_event_id,
            entries=entries,
            explanations=explanations,
        )
        return DecisionGraph(
            graph_id=_stable_graph_id(user_id, entries),
            user_id=user_id,
            generated_at=_generated_at(entries),
            current_state=current_state,
            current_tier=current_tier,
            nodes=nodes,
            edges=edges,
            summary=summary,
            warnings=list(warnings or []),
        )


def _append_edge(
    edges: list[DecisionEdge],
    from_node_id: str,
    to_node_id: str,
    label: str,
) -> None:
    edges.append(
        DecisionEdge(
            from_node_id=from_node_id,
            to_node_id=to_node_id,
            edge_type=label,
            label=label.replace("_", " "),
        )
    )


def _normalize_trace_entry(entry: Mapping[str, Any]) -> dict[str, Any]:
    reason = _first_present(entry, "ignored_reason", "rejected_reason", "reason")
    status = _status_for_trace_entry(entry, reason)
    normalized = {
        "event_id": int(_first_present(entry, "event_id", "eventId") or 0),
        "event_type": _first_present(entry, "event_type", "eventType"),
        "product_id": _first_present(entry, "product_id", "productId"),
        "channel": entry.get("channel"),
        "source": entry.get("source"),
        "authority_score": int(entry.get("authority_score", entry.get("authorityScore", 0)) or 0),
        "timestamp": _first_present(entry, "timestamp", "event_time", "eventTime"),
        "payload_hash": _first_present(entry, "payload_hash", "payloadHash"),
        "hash_chain_position": _first_present(
            entry,
            "hash_chain_position",
            "hashChainPosition",
        ),
        "event_kind": _first_present(entry, "event_kind", "eventKind"),
        "previous_state": _first_present(entry, "previous_state", "previousState")
        or STATE_NONE,
        "new_state": _first_present(entry, "new_state", "newState") or STATE_NONE,
        "applied": bool(entry.get("applied", status == STATUS_APPLIED)),
        "status": status,
        "applied_rule": _first_present(entry, "applied_rule", "appliedRule"),
        "integrity_result": sanitize_observability_payload(
            entry.get("integrity_result", entry.get("integrityResult", {}))
        ),
        "ordering_result": _first_present(entry, "ordering_result", "orderingResult"),
        "entitlement_result": _first_present(
            entry,
            "entitlement_result",
            "entitlementResult",
        ),
        "entitlement_tier": _first_present(entry, "entitlement_tier", "entitlementTier"),
        "ignored_reason": entry.get("ignored_reason", entry.get("ignoredReason")),
        "rejected_reason": entry.get("rejected_reason", entry.get("rejectedReason")),
    }
    if normalized["event_id"] <= 0:
        raise ValueError("trace entry event_id must be positive")
    if reason and status == STATUS_IGNORED:
        normalized["ignored_reason"] = reason
    if reason and status in {STATUS_REJECTED, STATUS_ERROR, STATUS_WARNING}:
        normalized["rejected_reason"] = reason
    return sanitize_observability_payload(normalized)


def _status_for_trace_entry(entry: Mapping[str, Any], reason: Any) -> str:
    status = entry.get("status")
    if isinstance(status, str) and status in {
        STATUS_APPLIED,
        STATUS_IGNORED,
        STATUS_REJECTED,
        STATUS_ERROR,
        STATUS_WARNING,
    }:
        return status
    if bool(entry.get("applied", False)):
        return STATUS_APPLIED
    if str(reason or "") in _IGNORED_REASONS:
        return STATUS_IGNORED
    return STATUS_REJECTED


def _merge_event_context(
    entry: Mapping[str, Any],
    event: Optional[Any],
    explanation: Optional[Any],
) -> dict[str, Any]:
    merged = dict(entry)
    if event is not None:
        merged.update(
            {
                "event_type": merged.get("event_type") or getattr(event, "event_type", None),
                "product_id": merged.get("product_id") or getattr(event, "product_id", None),
                "channel": merged.get("channel") or getattr(event, "channel", None),
                "source": merged.get("source") or getattr(event, "source", None),
                "payload_hash": merged.get("payload_hash") or getattr(event, "payload_hash", None),
                "hash_chain_position": merged.get("hash_chain_position")
                or getattr(event, "event_id", None),
                "timestamp": merged.get("timestamp")
                or getattr(event, "event_time", None)
                or getattr(event, "server_time", None),
            }
        )
    if explanation is not None:
        merged["applied_rule"] = merged.get("applied_rule") or getattr(
            explanation,
            "rule_applied",
            None,
        )
    return sanitize_observability_payload(merged)


def _branch_node_type(entry: Mapping[str, Any]) -> str:
    if entry.get("applied"):
        return NODE_STATE_TRANSITION
    if entry.get("status") == STATUS_IGNORED:
        return NODE_IGNORED_EVENT
    return NODE_REJECTED_EVENT


def _is_correction_event(entry: Mapping[str, Any]) -> bool:
    source = str(entry.get("source") or "").strip().lower()
    return source == "reconciliation" or str(entry.get("event_kind") or "") == "correction"


def _integrity_status(entry: Mapping[str, Any]) -> str:
    integrity = entry.get("integrity_result", {})
    if isinstance(integrity, Mapping) and integrity.get("chain_valid") is False:
        return STATUS_ERROR
    if entry.get("status") == STATUS_ERROR:
        return STATUS_ERROR
    return STATUS_VERIFIED


def _ordering_status(entry: Mapping[str, Any]) -> str:
    reason = str(_reason(entry) or "")
    if reason in {
        "event_time_unorderable",
        "ambiguous_equal_event_time",
        "stale_event_ignored",
        "event_time_missing_cannot_override_timed_state",
        "stale_event_version_ignored",
    }:
        return STATUS_IGNORED if reason in _IGNORED_REASONS else STATUS_REJECTED
    if entry.get("status") == STATUS_ERROR:
        return STATUS_ERROR
    return STATUS_VERIFIED


def _entitlement_status(entry: Mapping[str, Any]) -> str:
    result = str(entry.get("entitlement_result") or "")
    tier = str(entry.get("entitlement_tier") or "none")
    if result in {
        "billingRetry",
        "expired",
        "noActiveEntitlement",
        "no_state_change",
        "not_evaluated",
        "revoked",
    }:
        return STATUS_REJECTED
    if tier in {"pro", "max"}:
        return STATUS_APPLIED
    return STATUS_APPLIED if entry.get("applied") else STATUS_REJECTED


def _reason(entry: Mapping[str, Any]) -> Optional[str]:
    value = _first_present(entry, "ignored_reason", "rejected_reason", "ordering_result")
    if value is None:
        return None
    return str(value)


def _summary(
    *,
    user_id: str,
    current_state: str,
    current_tier: str,
    final_deciding_event_id: Optional[int],
    entries: list[Mapping[str, Any]],
    explanations: Mapping[int, Any],
) -> dict[str, Any]:
    ignored = [entry for entry in entries if entry.get("status") == STATUS_IGNORED]
    rejected = [
        entry
        for entry in entries
        if entry.get("status") in {STATUS_REJECTED, STATUS_ERROR}
    ]
    corrections = [entry for entry in entries if _is_correction_event(entry)]
    warnings = [
        entry
        for entry in entries
        if entry.get("status") in {STATUS_WARNING, STATUS_ERROR}
    ]
    final_explanation = None
    if final_deciding_event_id is not None and final_deciding_event_id in explanations:
        final_explanation = explanations[final_deciding_event_id].explanation_text
    elif explanations:
        final_explanation = list(explanations.values())[-1].explanation_text
    return {
        "user_id": user_id,
        "current_state": current_state,
        "current_tier": current_tier,
        "final_deciding_event_id": final_deciding_event_id,
        "applied_event_count": sum(1 for entry in entries if entry.get("applied")),
        "ignored_event_count": len(ignored),
        "rejected_event_count": len(rejected),
        "correction_event_count": len(corrections),
        "warning_count": len(warnings),
        "explanation_summary": final_explanation or "No subscription events have been recorded.",
    }


def _current_state(replayed: Optional[Any], entries: list[Mapping[str, Any]]) -> str:
    if replayed is not None:
        current = getattr(replayed, "current_entitlement", None)
        if current is not None:
            for product_state in getattr(replayed, "product_states", {}).values():
                record = getattr(product_state, "record", None)
                if record is current:
                    return str(getattr(product_state, "state", STATE_NONE))
                if record is not None and getattr(record, "latest_transaction_id", None) == getattr(
                    current,
                    "latest_transaction_id",
                    None,
                ):
                    return str(getattr(product_state, "state", STATE_NONE))
        return STATE_NONE
    for entry in reversed(entries):
        if entry.get("applied"):
            return str(entry.get("new_state") or STATE_NONE)
    return STATE_NONE


def _current_tier(replayed: Optional[Any], entries: list[Mapping[str, Any]]) -> str:
    if replayed is not None:
        body = replayed.current_entitlement_body()
        return str(body.get("entitlementTier") or "none")
    for entry in reversed(entries):
        tier = entry.get("entitlement_tier")
        if tier:
            return str(tier)
    return "none"


def _final_deciding_event_id(
    replayed: Optional[Any],
    entries: list[Mapping[str, Any]],
) -> Optional[int]:
    if replayed is not None:
        current = getattr(replayed, "current_entitlement", None)
        if current is not None:
            for product_state in getattr(replayed, "product_states", {}).values():
                record = getattr(product_state, "record", None)
                if record is current or (
                    record is not None
                    and getattr(record, "latest_transaction_id", None)
                    == getattr(current, "latest_transaction_id", None)
                ):
                    return int(getattr(product_state, "last_event_id", 0) or 0) or None
    for entry in reversed(entries):
        if entry.get("applied"):
            return int(entry["event_id"])
    return None


def _generated_at(entries: list[Mapping[str, Any]]) -> str:
    timestamps = [str(entry.get("timestamp")) for entry in entries if entry.get("timestamp")]
    if timestamps:
        return max(timestamps)
    return "1970-01-01T00:00:00Z"


def _stable_graph_id(user_id: str, entries: list[Mapping[str, Any]]) -> str:
    material = json.dumps(
        {
            "user_id": user_id,
            "events": [
                {
                    "event_id": entry.get("event_id"),
                    "payload_hash": entry.get("payload_hash"),
                    "status": entry.get("status"),
                    "new_state": entry.get("new_state"),
                }
                for entry in entries
            ],
        },
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
    )
    return hashlib.sha256(material.encode("utf-8")).hexdigest()


def _explanations_by_event_id(store: Optional[Any], user_id: str) -> dict[int, Any]:
    if store is None:
        return {}
    return {explanation.event_id: explanation for explanation in store.get_explanation(user_id)}


def _unchecked_events_for_user(event_store: Any, user_id: str) -> list[Any]:
    getter = getattr(event_store, "get_events_unchecked", None)
    if getter is not None:
        return list(getter(user_id))
    return list(event_store.get_events(user_id))


def _unchecked_event_by_id(event_store: Any, event_id: int) -> Optional[Any]:
    getter = getattr(event_store, "get_all_events_unchecked", None)
    events = list(getter()) if getter is not None else list(event_store.get_all_events())
    for event in events:
        if int(getattr(event, "event_id", 0)) == event_id:
            return event
    return None


def _node_id(prefix: str, event_id: int) -> str:
    return f"{prefix}:{event_id}"


def _first_present(mapping: Mapping[str, Any], *keys: str) -> Any:
    for key in keys:
        value = mapping.get(key)
        if value is not None:
            return value
    return None


def _optional_text(value: Any) -> Optional[str]:
    if not isinstance(value, str):
        return None
    normalized = value.strip()
    return normalized or None


def _require_text(value: Any, field_name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{field_name} is required")
    return value.strip()
