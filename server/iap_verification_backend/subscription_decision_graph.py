from __future__ import annotations

import dataclasses
import json
from typing import Any, Mapping, Optional

from subscription_observability_sanitizer import sanitize_observability_payload


NODE_EVENT = "event"
NODE_INTEGRITY_CHECK = "integrity_check"
NODE_AUTHORITY_RESOLUTION = "authority_resolution"
NODE_ORDERING_DECISION = "ordering_decision"
NODE_STATE_TRANSITION = "state_transition"
NODE_ENTITLEMENT_DECISION = "entitlement_decision"
NODE_PROJECTION = "projection"
NODE_IGNORED_EVENT = "ignored_event"
NODE_REJECTED_EVENT = "rejected_event"
NODE_CORRECTION_EVENT = "correction_event"

STATUS_APPLIED = "applied"
STATUS_IGNORED = "ignored"
STATUS_REJECTED = "rejected"
STATUS_VERIFIED = "verified"
STATUS_WARNING = "warning"
STATUS_ERROR = "error"


@dataclasses.dataclass(frozen=True)
class DecisionNode:
    node_id: str
    node_type: str
    label: str
    status: str
    event_id: Optional[int] = None
    rule_id: Optional[str] = None
    timestamp: Optional[str] = None
    metadata: Mapping[str, Any] = dataclasses.field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        body: dict[str, Any] = {
            "node_id": self.node_id,
            "node_type": self.node_type,
            "label": self.label,
            "status": self.status,
            "metadata": sanitize_observability_payload(dict(self.metadata)),
        }
        if self.event_id is not None:
            body["event_id"] = self.event_id
        if self.rule_id is not None:
            body["rule_id"] = self.rule_id
        if self.timestamp is not None:
            body["timestamp"] = self.timestamp
        return body


@dataclasses.dataclass(frozen=True)
class DecisionEdge:
    from_node_id: str
    to_node_id: str
    edge_type: str
    label: str
    metadata: Mapping[str, Any] = dataclasses.field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "from_node_id": self.from_node_id,
            "to_node_id": self.to_node_id,
            "edge_type": self.edge_type,
            "label": self.label,
            "metadata": sanitize_observability_payload(dict(self.metadata)),
        }


@dataclasses.dataclass(frozen=True)
class DecisionGraph:
    graph_id: str
    user_id: str
    generated_at: str
    current_state: str
    current_tier: str
    nodes: list[DecisionNode]
    edges: list[DecisionEdge]
    summary: Mapping[str, Any]
    warnings: list[str] = dataclasses.field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "graph_id": self.graph_id,
            "user_id": self.user_id,
            "generated_at": self.generated_at,
            "current_state": self.current_state,
            "current_tier": self.current_tier,
            "nodes": [node.to_dict() for node in self.nodes],
            "edges": [edge.to_dict() for edge in self.edges],
            "summary": sanitize_observability_payload(dict(self.summary)),
            "warnings": list(self.warnings),
        }

    def canonical_json(self) -> str:
        return json.dumps(
            self.to_dict(),
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=True,
        )
