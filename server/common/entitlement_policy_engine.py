from __future__ import annotations

from typing import Iterable

from common.entitlement_model import (
    EntitlementAuthContext,
    EntitlementDecision,
    EntitlementTier,
    PaidEntitlementState,
)


READ_OPERATIONS = {"read", "pull", "list", "download", "issue_key"}
WRITE_OPERATIONS = {"write", "push", "upload", "register", "mutate", "override"}
LOCAL_ENVS = {"test", "local", "development", "dev"}
PRODUCTION_ENVS = {"production", "prod", "staging", ""}


class EntitlementPolicyEngine:
    def decide(
        self,
        auth_context: EntitlementAuthContext,
        request_type: str,
        user_id: str,
        env: object,
    ) -> EntitlementDecision:
        normalized_request = _normalize_request_type(request_type)
        normalized_env = _normalize_env(env)
        operation = auth_context.operation

        if not isinstance(user_id, str) or not user_id.strip():
            return EntitlementDecision(
                allow=False,
                tier=EntitlementTier.PAID,
                reason="missing_user_id",
            )

        if auth_context.is_dev:
            if normalized_env in LOCAL_ENVS:
                return EntitlementDecision(
                    allow=True,
                    tier=EntitlementTier.DEV,
                    reason="dev_mode_bypass",
                    limits={"billing_bypass": True},
                )
            if normalized_request == "ledger_write" or operation in WRITE_OPERATIONS:
                return EntitlementDecision(
                    allow=False,
                    tier=EntitlementTier.DEV,
                    reason="dev_cannot_modify_production_ledger",
                )
            return EntitlementDecision(
                allow=True,
                tier=EntitlementTier.DEV,
                reason="dev_read_only_production_access",
                limits={"read_only": True, "billing_bypass": True},
            )

        if auth_context.is_internal:
            if normalized_request == "entitlement_override":
                return EntitlementDecision(
                    allow=False,
                    tier=EntitlementTier.INTERNAL,
                    reason="internal_cannot_override_entitlement_state",
                )
            return EntitlementDecision(
                allow=True,
                tier=EntitlementTier.INTERNAL,
                reason="internal_service_access",
                limits={"payment_check_bypass": True},
            )

        if normalized_request == "observability":
            return EntitlementDecision(
                allow=False,
                tier=EntitlementTier.PAID,
                reason="internal_required_for_observability",
            )

        state = auth_context.paid_state or PaidEntitlementState.NONE
        if state == PaidEntitlementState.ACTIVE:
            return EntitlementDecision(
                allow=True,
                tier=EntitlementTier.PAID,
                reason="paid_active",
            )

        if state == PaidEntitlementState.GRACE:
            if _is_read_only_request(normalized_request, operation):
                return EntitlementDecision(
                    allow=True,
                    tier=EntitlementTier.PAID,
                    reason="paid_grace_read_only",
                    limits={"read_only": True},
                )
            return EntitlementDecision(
                allow=False,
                tier=EntitlementTier.PAID,
                reason="paid_grace_read_only",
                limits={"read_only": True},
            )

        return EntitlementDecision(
            allow=False,
            tier=EntitlementTier.PAID,
            reason="paid_entitlement_required",
        )


def _normalize_request_type(value: object) -> str:
    if isinstance(value, str) and value.strip():
        return value.strip().lower()
    return "unknown"


def _normalize_env(value: object) -> str:
    if isinstance(value, str):
        return value.strip().lower()
    return ""


def _is_read_only_request(request_type: str, operation: str) -> bool:
    if request_type == "ledger_read":
        return True
    if request_type == "ledger_write":
        return False
    return operation in READ_OPERATIONS and operation not in WRITE_OPERATIONS


def includes_write_operation(values: Iterable[str]) -> bool:
    return any(value.lower() in WRITE_OPERATIONS for value in values)
