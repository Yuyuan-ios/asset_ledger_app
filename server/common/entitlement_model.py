from __future__ import annotations

import dataclasses
from enum import Enum
from typing import Any, Mapping, Optional


class EntitlementTier(str, Enum):
    DEV = "DEV"
    INTERNAL = "INTERNAL"
    PAID = "PAID"


class PaidEntitlementState(str, Enum):
    ACTIVE = "ACTIVE"
    GRACE = "GRACE"
    NONE = "NONE"


@dataclasses.dataclass(frozen=True)
class EntitlementDecision:
    allow: bool
    tier: EntitlementTier
    reason: str
    limits: Optional[dict[str, Any]] = None


@dataclasses.dataclass(frozen=True)
class EntitlementAuthContext:
    is_dev: bool = False
    is_internal: bool = False
    paid_state: Optional[PaidEntitlementState] = None
    operation: str = "read"
    can_override_entitlement_state: bool = False

    @classmethod
    def from_value(cls, value: object) -> "EntitlementAuthContext":
        if isinstance(value, EntitlementAuthContext):
            return value
        if isinstance(value, Mapping):
            return cls(
                is_dev=bool(value.get("is_dev") or value.get("dev")),
                is_internal=bool(value.get("is_internal") or value.get("internal")),
                paid_state=_paid_state_from_value(value.get("paid_state") or value.get("entitlement_state")),
                operation=_operation_from_value(value.get("operation")),
                can_override_entitlement_state=bool(
                    value.get("can_override_entitlement_state")
                    or value.get("can_override")
                ),
            )
        return cls(
            is_dev=bool(getattr(value, "is_dev", False)),
            is_internal=bool(getattr(value, "is_internal", False)),
            paid_state=_paid_state_from_value(
                getattr(value, "paid_state", getattr(value, "entitlement_state", None))
            ),
            operation=_operation_from_value(getattr(value, "operation", None)),
            can_override_entitlement_state=bool(
                getattr(value, "can_override_entitlement_state", False)
            ),
        )


class EntitlementSourceUnavailable(RuntimeError):
    pass


def _operation_from_value(value: object) -> str:
    if isinstance(value, str) and value.strip():
        return value.strip().lower()
    return "read"


def _paid_state_from_value(value: object) -> Optional[PaidEntitlementState]:
    if value is None:
        return None
    if isinstance(value, PaidEntitlementState):
        return value
    if isinstance(value, str):
        normalized = value.strip().upper()
        if not normalized:
            return None
        aliases = {
            "ACTIVE": PaidEntitlementState.ACTIVE,
            "VERIFIEDACTIVE": PaidEntitlementState.ACTIVE,
            "GRACE": PaidEntitlementState.GRACE,
            "GRACE_PERIOD": PaidEntitlementState.GRACE,
            "NONE": PaidEntitlementState.NONE,
            "FREE": PaidEntitlementState.NONE,
            "EXPIRED": PaidEntitlementState.NONE,
            "REVOKED": PaidEntitlementState.NONE,
            "BILLING_RETRY": PaidEntitlementState.NONE,
        }
        if normalized in aliases:
            return aliases[normalized]
    return PaidEntitlementState.NONE
