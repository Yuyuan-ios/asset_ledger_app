from __future__ import annotations

import dataclasses
from datetime import datetime, timezone
from typing import Any, Mapping, Optional


@dataclasses.dataclass(frozen=True)
class EventOrderingDecision:
    accepted: bool
    reason: str
    event_time: Optional[str]
    event_version: int


class SubscriptionEventOrdering:
    """Applies latest-event-wins ordering per user and product."""

    def __init__(self, store: Any):
        self.store = store

    def evaluate(
        self,
        event: Any,
        current_state: Optional[Any],
    ) -> EventOrderingDecision:
        event_time = event_time_for_event(event)
        current_event_time = _current_value(current_state, "event_time")
        current_version = _current_int(current_state, "event_version")

        if event_time is not None:
            event_order = _parse_event_time(event_time)
            current_order = _parse_event_time(current_event_time)
            if event_order is None:
                return EventOrderingDecision(
                    accepted=False,
                    reason="event_time_unorderable",
                    event_time=event_time,
                    event_version=current_version,
                )
            if current_event_time and current_order is None:
                return EventOrderingDecision(
                    accepted=False,
                    reason="current_event_time_unorderable",
                    event_time=event_time,
                    event_version=current_version,
                )
            if current_order is not None:
                if event_order < current_order:
                    return EventOrderingDecision(
                        accepted=False,
                        reason="stale_event_ignored",
                        event_time=event_time,
                        event_version=current_version,
                    )
                if event_order == current_order:
                    return EventOrderingDecision(
                        accepted=False,
                        reason="ambiguous_equal_event_time",
                        event_time=event_time,
                        event_version=current_version,
                    )
            return EventOrderingDecision(
                accepted=True,
                reason="event_time_accepted",
                event_time=event_time,
                event_version=current_version,
            )

        if current_event_time:
            return EventOrderingDecision(
                accepted=False,
                reason="event_time_missing_cannot_override_timed_state",
                event_time=None,
                event_version=current_version,
            )

        next_version = self.store.next_subscription_event_version(event.user_id)
        if next_version <= current_version:
            return EventOrderingDecision(
                accepted=False,
                reason="stale_event_version_ignored",
                event_time=None,
                event_version=next_version,
            )
        return EventOrderingDecision(
            accepted=True,
            reason="event_version_accepted",
            event_time=None,
            event_version=next_version,
        )


def event_time_for_event(event: Any) -> Optional[str]:
    explicit = getattr(event, "event_time", None)
    if isinstance(explicit, str) and explicit.strip():
        return explicit.strip()
    raw_payload = getattr(event, "raw_payload", {})
    if isinstance(raw_payload, Mapping):
        for key in (
            "eventTime",
            "event_time",
            "serverTime",
            "server_time",
            "transactionDate",
            "transaction_date",
        ):
            value = raw_payload.get(key)
            if value is not None and str(value).strip():
                return str(value).strip()
    return None


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


def _current_value(current_state: Optional[Any], key: str) -> Optional[str]:
    if current_state is None:
        return None
    if isinstance(current_state, Mapping):
        value = current_state.get(key)
    else:
        value = getattr(current_state, key, None)
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _current_int(current_state: Optional[Any], key: str) -> int:
    value = _current_value(current_state, key)
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return 0
