from __future__ import annotations

import dataclasses
from typing import Any, Optional, Sequence

from subscription_event_hash_chain import ChainVerificationResult, EventHashChain


LEDGER_STATUS_IMMUTABLE = "IMMUTABLE"
LEDGER_STATUS_COMPROMISED = "COMPROMISED"
REPLAY_STATUS_TRUSTED = "TRUSTED"
REPLAY_STATUS_UNTRUSTED = "UNTRUSTED"
FINAL_VERDICT_VERIFIED = "LEDGER IS CRYPTOGRAPHICALLY INTEGRITY-VERIFIED"
FINAL_VERDICT_COMPROMISED = "LEDGER INTEGRITY COMPROMISED"


@dataclasses.dataclass(frozen=True)
class VerificationResult:
    chain_valid: bool
    tamper_detected: bool
    broken_event_index: Optional[int] = None
    user_id: Optional[str] = None
    broken_event_id: Optional[int] = None
    reason: Optional[str] = None
    ledger_security_status: str = LEDGER_STATUS_IMMUTABLE
    replay_trust_status: str = REPLAY_STATUS_TRUSTED
    final_verdict: str = FINAL_VERDICT_VERIFIED

    @classmethod
    def from_chain_result(
        cls,
        result: ChainVerificationResult,
        *,
        user_id: Optional[str],
    ) -> "VerificationResult":
        valid = result.chain_valid
        return cls(
            chain_valid=valid,
            tamper_detected=result.tamper_detected,
            broken_event_index=result.broken_index,
            user_id=user_id,
            broken_event_id=result.broken_event_id,
            reason=result.reason,
            ledger_security_status=(
                LEDGER_STATUS_IMMUTABLE if valid else LEDGER_STATUS_COMPROMISED
            ),
            replay_trust_status=REPLAY_STATUS_TRUSTED if valid else REPLAY_STATUS_UNTRUSTED,
            final_verdict=FINAL_VERDICT_VERIFIED if valid else FINAL_VERDICT_COMPROMISED,
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "userId": self.user_id,
            "chain_valid": self.chain_valid,
            "tamper_detected": self.tamper_detected,
            "broken_event_index": self.broken_event_index,
            "brokenEventId": self.broken_event_id,
            "reason": self.reason,
            "ledgerSecurityStatus": self.ledger_security_status,
            "replayTrustStatus": self.replay_trust_status,
            "finalVerdict": self.final_verdict,
        }


@dataclasses.dataclass(frozen=True)
class LedgerIntegrityReport:
    chain_valid: bool
    tamper_detected: bool
    broken_event_index: Optional[int]
    user_results: list[VerificationResult]
    broken_user_id: Optional[str] = None
    broken_event_id: Optional[int] = None
    reason: Optional[str] = None

    @property
    def ledger_security_status(self) -> str:
        return LEDGER_STATUS_IMMUTABLE if self.chain_valid else LEDGER_STATUS_COMPROMISED

    @property
    def replay_trust_status(self) -> str:
        return REPLAY_STATUS_TRUSTED if self.chain_valid else REPLAY_STATUS_UNTRUSTED

    @property
    def final_verdict(self) -> str:
        return FINAL_VERDICT_VERIFIED if self.chain_valid else FINAL_VERDICT_COMPROMISED

    def to_dict(self) -> dict[str, Any]:
        return {
            "chain_valid": self.chain_valid,
            "tamper_detected": self.tamper_detected,
            "broken_event_index": self.broken_event_index,
            "brokenUserId": self.broken_user_id,
            "brokenEventId": self.broken_event_id,
            "reason": self.reason,
            "ledgerSecurityStatus": self.ledger_security_status,
            "replayTrustStatus": self.replay_trust_status,
            "finalVerdict": self.final_verdict,
            "users": [result.to_dict() for result in self.user_results],
        }


class IntegrityVerifier:
    """Verifies whether subscription ledger hash chains have been tampered."""

    def __init__(self, event_store: Any):
        self.event_store = event_store

    def verify_user_chain(self, user_id: str) -> VerificationResult:
        events = _unchecked_all_events(self.event_store)
        return self.verify_events(events, user_id=user_id)

    def verify_events(
        self,
        events: Sequence[Any],
        *,
        user_id: Optional[str] = None,
    ) -> VerificationResult:
        ordered_events = EventHashChain.chain_order(events)
        result = EventHashChain.verify_chain_detailed(ordered_events)
        return VerificationResult.from_chain_result(result, user_id=user_id)

    def verify_global_ledger(self) -> LedgerIntegrityReport:
        events = EventHashChain.chain_order(_unchecked_all_events(self.event_store))
        global_result = self.verify_events(events, user_id=None)
        user_results = [self.verify_user_chain(user_id) for user_id in _user_ids(self.event_store)]
        broken_user_id = None
        if (
            global_result.broken_event_index is not None
            and 0 <= global_result.broken_event_index < len(events)
        ):
            broken_user_id = str(getattr(events[global_result.broken_event_index], "user_id", ""))
        return LedgerIntegrityReport(
            chain_valid=global_result.chain_valid,
            tamper_detected=global_result.tamper_detected,
            broken_event_index=global_result.broken_event_index,
            broken_user_id=broken_user_id or None,
            broken_event_id=global_result.broken_event_id,
            reason=global_result.reason,
            user_results=user_results,
        )


def _unchecked_all_events(event_store: Any) -> list[Any]:
    getter = getattr(event_store, "get_all_events_unchecked", None)
    if getter is not None:
        return list(getter())
    return list(event_store.get_all_events())


def _user_ids(event_store: Any) -> list[str]:
    return list(event_store.list_user_ids())
