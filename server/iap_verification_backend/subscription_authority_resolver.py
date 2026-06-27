from __future__ import annotations

import dataclasses
from typing import Any, Mapping, Optional


APPLE_CHANNEL = "apple"
GOOGLE_PLAY_CHANNEL = "google_play"
CHINA_CHANNELS = frozenset({"oppo", "xiaomi", "huawei", "vivo"})

APPLE_SERVER_NOTIFICATION_SCORE = 100
APPLE_VERIFY_SCORE = 80
GOOGLE_RTDN_SCORE = 100
GOOGLE_VERIFY_SCORE = 80
CHINA_WEBHOOK_SCORE = 90
CHINA_VERIFY_SCORE = 70


@dataclasses.dataclass(frozen=True)
class AuthorityResolution:
    authority_score: int
    accepted: bool
    reason: str
    source: str


class SubscriptionAuthorityResolver:
    """Resolves provider authority before an event can change ledger state."""

    def resolve(
        self,
        event: Any,
        current_state: Optional[Any],
    ) -> AuthorityResolution:
        source = _source_for_event(event)
        score = authority_score_for_event(event, source=source)
        current_score = _current_authority_score(current_state)
        if score < current_score:
            return AuthorityResolution(
                authority_score=score,
                accepted=False,
                reason="lower_authority_event_ignored",
                source=source,
            )
        return AuthorityResolution(
            authority_score=score,
            accepted=True,
            reason="authority_accepted",
            source=source,
        )


def authority_score_for_event(event: Any, *, source: Optional[str] = None) -> int:
    channel = str(getattr(event, "channel", "")).strip().lower()
    normalized_source = normalize_authority_source(source or _source_for_event(event))
    raw_payload = getattr(event, "raw_payload", {})

    if channel == APPLE_CHANNEL:
        if normalized_source in {
            "apple_server_notification",
            "app_store_server_notification",
            "server_notification",
            "server_notifications",
            "notification",
        } or _has_any(raw_payload, "notificationType", "subtype"):
            return APPLE_SERVER_NOTIFICATION_SCORE
        return APPLE_VERIFY_SCORE

    if channel == GOOGLE_PLAY_CHANNEL:
        if normalized_source in {
            "rtdn",
            "real_time_developer_notification",
            "server_notification",
            "webhook",
        } or _has_any(raw_payload, "subscriptionNotification", "voidedPurchaseNotification"):
            return GOOGLE_RTDN_SCORE
        return GOOGLE_VERIFY_SCORE

    if channel in CHINA_CHANNELS:
        if normalized_source in {"webhook", "server_notification", "callback"}:
            return CHINA_WEBHOOK_SCORE
        return CHINA_VERIFY_SCORE

    return 0


def normalize_authority_source(value: Optional[str]) -> str:
    if value is None:
        return "verify"
    normalized = str(value).strip().lower().replace("-", "_")
    return normalized or "verify"


def _source_for_event(event: Any) -> str:
    explicit = getattr(event, "source", None)
    if isinstance(explicit, str) and explicit.strip():
        return normalize_authority_source(explicit)
    raw_payload = getattr(event, "raw_payload", {})
    if isinstance(raw_payload, Mapping):
        for key in ("authoritySource", "eventSource", "source", "sourceType"):
            value = raw_payload.get(key)
            if isinstance(value, str) and value.strip():
                return normalize_authority_source(value)
    return "verify"


def _current_authority_score(current_state: Optional[Any]) -> int:
    if current_state is None:
        return 0
    if isinstance(current_state, Mapping):
        value = current_state.get("authority_score")
    else:
        value = getattr(current_state, "authority_score", 0)
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return 0


def _has_any(raw_payload: Any, *keys: str) -> bool:
    if not isinstance(raw_payload, Mapping):
        return False
    return any(key in raw_payload for key in keys)
