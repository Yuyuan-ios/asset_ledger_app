from __future__ import annotations

import json
import urllib.error
import urllib.request
from typing import Any, Callable, Mapping, Optional

from common.entitlement_model import (
    EntitlementAuthContext,
    EntitlementDecision,
    EntitlementSourceUnavailable,
    PaidEntitlementState,
)
from common.entitlement_policy_engine import EntitlementPolicyEngine


PaidStateProvider = Callable[[str, str], PaidEntitlementState]


class EntitlementResolver:
    def __init__(
        self,
        *,
        policy_engine: Optional[EntitlementPolicyEngine] = None,
        paid_state_provider: Optional[PaidStateProvider] = None,
        default_paid_state: PaidEntitlementState = PaidEntitlementState.NONE,
    ):
        self.policy_engine = policy_engine or EntitlementPolicyEngine()
        self.paid_state_provider = paid_state_provider
        self.default_paid_state = default_paid_state

    def resolve(
        self,
        auth_context: object,
        request_type: str,
        user_id: str,
        env: object,
    ) -> EntitlementDecision:
        context = EntitlementAuthContext.from_value(auth_context)
        if not context.is_dev and not context.is_internal and context.paid_state is None:
            context = EntitlementAuthContext(
                is_dev=context.is_dev,
                is_internal=context.is_internal,
                paid_state=self._paid_state(user_id, request_type),
                operation=context.operation,
                can_override_entitlement_state=context.can_override_entitlement_state,
            )
        return self.policy_engine.decide(context, request_type, user_id, env)

    def _paid_state(self, user_id: str, request_type: str) -> PaidEntitlementState:
        if self.paid_state_provider is None:
            return self.default_paid_state
        return self.paid_state_provider(user_id, request_type)


class HttpPaidEntitlementStateProvider:
    def __init__(
        self,
        url: str,
        *,
        service_internal_token: str,
        required_plans: Optional[Mapping[str, str]] = None,
        timeout_seconds: int = 5,
    ):
        if not url.startswith("https://"):
            raise ValueError("entitlement URL must be https")
        token = service_internal_token.strip()
        if not token:
            raise ValueError("SERVICE_INTERNAL_TOKEN is required")
        self.url = url
        self.service_internal_token = token
        self.required_plans = dict(required_plans or {})
        self.timeout_seconds = timeout_seconds

    def __call__(self, user_id: str, request_type: str) -> PaidEntitlementState:
        body = json.dumps(
            {
                "user_id": user_id,
                "required_capability": _capability_for_request_type(request_type),
                "required_plan": self.required_plans.get(request_type, "paid"),
            },
            separators=(",", ":"),
        ).encode("utf-8")
        request = urllib.request.Request(
            self.url,
            data=body,
            method="POST",
            headers={
                "Accept": "application/json",
                "Authorization": f"Bearer {self.service_internal_token}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=self.timeout_seconds) as response:
                raw = response.read()
        except urllib.error.HTTPError as exc:
            _close_http_error(exc)
            if exc.code in (401, 403, 404):
                return PaidEntitlementState.NONE
            raise EntitlementSourceUnavailable("entitlement service unavailable") from exc
        except (TimeoutError, urllib.error.URLError) as exc:
            raise EntitlementSourceUnavailable("entitlement service unavailable") from exc

        try:
            decoded = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise EntitlementSourceUnavailable("entitlement service returned invalid JSON") from exc
        if not isinstance(decoded, dict):
            raise EntitlementSourceUnavailable("entitlement service response must be an object")
        return paid_state_from_response(decoded, required_plan=self.required_plans.get(request_type))


def paid_state_from_response(
    body: Mapping[str, Any],
    *,
    required_plan: Optional[str] = None,
) -> PaidEntitlementState:
    for candidate in _candidate_entitlement_bodies(body):
        tier = _first_lower_string(
            candidate,
            "entitlementTier",
            "tier",
            "plan",
            "subscriptionTier",
        )
        if _required_plan_misses(tier, required_plan):
            continue
        status = _first_lower_string(candidate, "status", "entitlementStatus", "state")
        if status == "grace":
            return PaidEntitlementState.GRACE
        if _is_active_entitlement(candidate) or status == "active":
            return PaidEntitlementState.ACTIVE
    return PaidEntitlementState.NONE


def _required_plan_misses(tier: Optional[str], required_plan: Optional[str]) -> bool:
    required = (required_plan or "paid").strip().lower()
    if required in {"", "paid", "any"}:
        return tier in {None, "", "none", "free"}
    return tier != required


def _capability_for_request_type(request_type: str) -> str:
    normalized = request_type.strip().lower()
    if normalized == "backup":
        return "cloud_backup"
    if normalized == "sync":
        return "sync"
    return normalized


def _candidate_entitlement_bodies(body: Mapping[str, Any]):
    yield body
    for key in ("entitlement", "subscription", "result"):
        value = body.get(key)
        if isinstance(value, Mapping):
            yield value


def _first_lower_string(body: Mapping[str, Any], *keys: str) -> Optional[str]:
    for key in keys:
        value = body.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip().lower()
    return None


def _is_active_entitlement(body: Mapping[str, Any]) -> bool:
    return body.get("active") is True or body.get("entitlementActive") is True


def _close_http_error(exc: urllib.error.HTTPError) -> None:
    try:
        exc.close()
    except Exception:
        return
