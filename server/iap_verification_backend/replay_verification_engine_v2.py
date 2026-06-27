from __future__ import annotations

from subscription_replay_engine import (
    EntitlementState,
    ProductReplayState,
    ReplayDecision,
    SubscriptionProjectionDriftError,
    SubscriptionReplayEngine,
)


class ReplayVerificationEngineV2(SubscriptionReplayEngine):
    """SCP v3 replay engine entry point with mandatory integrity verification."""


__all__ = [
    "EntitlementState",
    "ProductReplayState",
    "ReplayDecision",
    "ReplayVerificationEngineV2",
    "SubscriptionProjectionDriftError",
]
