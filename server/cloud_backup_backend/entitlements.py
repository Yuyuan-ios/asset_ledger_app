from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
import time
from typing import Any, Dict, Iterable, Mapping, Optional, Protocol

from http_helpers import HttpError


CLOUD_BACKUP_ENTITLEMENT_URL_ENV = "CLOUD_BACKUP_ENTITLEMENT_URL"
CLOUD_BACKUP_ENTITLEMENT_TOKEN_ENV = "CLOUD_BACKUP_ENTITLEMENT_TOKEN"
CLOUD_BACKUP_ENTITLEMENT_TIMEOUT_ENV = "CLOUD_BACKUP_ENTITLEMENT_TIMEOUT_SECONDS"
CLOUD_BACKUP_ENTITLEMENT_CACHE_TTL_ENV = "CLOUD_BACKUP_ENTITLEMENT_CACHE_TTL_SECONDS"
CLOUD_BACKUP_MAX_ENTITLED_USERS_ENV = "CLOUD_BACKUP_MAX_ENTITLED_USERS_JSON"
LEGACY_ENTITLEMENT_URL_ENV = "FLEET_BACKUP_ENTITLEMENT_VERIFICATION_URL"
LEGACY_ENTITLEMENT_TOKEN_ENV = "FLEET_BACKUP_ENTITLEMENT_BEARER_TOKEN"
LEGACY_ENTITLEMENT_TIMEOUT_ENV = "FLEET_BACKUP_ENTITLEMENT_TIMEOUT_SECONDS"
LEGACY_MAX_ENTITLED_USERS_ENV = "FLEET_BACKUP_MAX_ENTITLED_USERS_JSON"
CLOUD_BACKUP_REQUIRES_MAX_CODE = "cloud_backup_requires_max"
CLOUD_BACKUP_REQUIRES_MAX_MESSAGE = "Cloud backup requires Max subscription."
SUBSCRIPTION_VERIFICATION_UNAVAILABLE_CODE = "subscription_verification_unavailable"
SUBSCRIPTION_VERIFICATION_UNAVAILABLE_MESSAGE = "Subscription verification is currently unavailable."
PRODUCTION_APP_ENVS = {"production", "prod", "staging"}
LOCAL_APP_ENVS = {"test", "local", "development", "dev"}


class CloudBackupEntitlementVerifier(Protocol):
    def require_max(self, user_id: str) -> None:
        ...


class FailClosedCloudBackupEntitlementVerifier:
    """Production-safe default until a server-side entitlement source is wired."""

    def require_max(self, user_id: str) -> None:
        raise cloud_backup_requires_max_error()


class StaticMaxUserEntitlementVerifier:
    """Local/test-only static verifier.

    This must not be used as a production entitlement source. It exists for
    smoke tests or local development where APP_ENV explicitly marks the process
    as non-production.
    """

    def __init__(self, max_user_ids: Iterable[str]):
        self.max_user_ids = {user_id.strip() for user_id in max_user_ids if user_id.strip()}

    def require_max(self, user_id: str) -> None:
        if user_id in self.max_user_ids:
            return
        raise cloud_backup_requires_max_error()


class HttpCloudBackupEntitlementVerifier:
    """Server-to-server verifier for a real account/subscription service.

    The endpoint is expected to be HTTPS and return JSON that explicitly proves
    active Max entitlement. User ids are sent server-to-server and never trusted
    from client headers.
    """

    def __init__(
        self,
        url: str,
        *,
        bearer_token: str,
        timeout_seconds: int = 5,
        cache_ttl_seconds: int = 0,
    ):
        if not url.startswith("https://"):
            raise ValueError(f"{CLOUD_BACKUP_ENTITLEMENT_URL_ENV} must be https")
        if not bearer_token.strip():
            raise ValueError(f"{CLOUD_BACKUP_ENTITLEMENT_TOKEN_ENV} is required")
        self.url = url
        self.bearer_token = bearer_token.strip()
        self.timeout_seconds = timeout_seconds
        self.cache_ttl_seconds = cache_ttl_seconds
        self._allow_cache: Dict[str, float] = {}

    def require_max(self, user_id: str) -> None:
        if self._has_cached_allow(user_id):
            return
        body = json.dumps(
            {
                "user_id": user_id,
                "required_capability": "cloud_backup",
                "required_plan": "max",
            },
            separators=(",", ":"),
        ).encode("utf-8")
        request = urllib.request.Request(
            self.url,
            data=body,
            method="POST",
            headers={
                "Accept": "application/json",
                "Authorization": f"Bearer {self.bearer_token}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=self.timeout_seconds) as response:
                raw = response.read()
        except urllib.error.HTTPError as exc:
            if exc.code in (401, 403, 404):
                raise cloud_backup_requires_max_error() from exc
            raise subscription_verification_unavailable_error() from exc
        except (TimeoutError, urllib.error.URLError) as exc:
            raise subscription_verification_unavailable_error() from exc
        try:
            decoded = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise subscription_verification_unavailable_error() from exc
        if not isinstance(decoded, dict):
            raise subscription_verification_unavailable_error()
        if _body_allows_cloud_backup(decoded):
            self._cache_allow(user_id)
            return
        raise cloud_backup_requires_max_error()

    def _has_cached_allow(self, user_id: str) -> bool:
        if self.cache_ttl_seconds <= 0:
            return False
        expires_at = self._allow_cache.get(user_id)
        if expires_at is None:
            return False
        if expires_at <= time.monotonic():
            self._allow_cache.pop(user_id, None)
            return False
        return True

    def _cache_allow(self, user_id: str) -> None:
        if self.cache_ttl_seconds <= 0:
            return
        self._allow_cache[user_id] = time.monotonic() + self.cache_ttl_seconds


def cloud_backup_requires_max_error() -> HttpError:
    return HttpError(
        403,
        CLOUD_BACKUP_REQUIRES_MAX_CODE,
        CLOUD_BACKUP_REQUIRES_MAX_MESSAGE,
    )


def subscription_verification_unavailable_error() -> HttpError:
    return HttpError(
        503,
        SUBSCRIPTION_VERIFICATION_UNAVAILABLE_CODE,
        SUBSCRIPTION_VERIFICATION_UNAVAILABLE_MESSAGE,
    )


def build_cloud_backup_entitlement_verifier_from_env() -> CloudBackupEntitlementVerifier:
    app_env = cloud_backup_app_env()
    url = _env_first(CLOUD_BACKUP_ENTITLEMENT_URL_ENV, LEGACY_ENTITLEMENT_URL_ENV)
    bearer_token = _env_first(CLOUD_BACKUP_ENTITLEMENT_TOKEN_ENV, LEGACY_ENTITLEMENT_TOKEN_ENV)
    raw_static_users = _env_first(
        CLOUD_BACKUP_MAX_ENTITLED_USERS_ENV,
        LEGACY_MAX_ENTITLED_USERS_ENV,
    )

    if app_env in PRODUCTION_APP_ENVS:
        if raw_static_users:
            raise ValueError(
                f"{CLOUD_BACKUP_MAX_ENTITLED_USERS_ENV} is not allowed when "
                "APP_ENV is production, prod, or staging"
            )
        if not url:
            raise ValueError(
                f"{CLOUD_BACKUP_ENTITLEMENT_URL_ENV} is required when APP_ENV "
                "is production, prod, staging, or unset"
            )
        if not bearer_token:
            raise ValueError(
                f"{CLOUD_BACKUP_ENTITLEMENT_TOKEN_ENV} is required when APP_ENV "
                "is production, prod, staging, or unset"
            )

    if url:
        if not bearer_token:
            raise ValueError(f"{CLOUD_BACKUP_ENTITLEMENT_TOKEN_ENV} is required")
        timeout = _env_int_first(
            [CLOUD_BACKUP_ENTITLEMENT_TIMEOUT_ENV, LEGACY_ENTITLEMENT_TIMEOUT_ENV],
            5,
        )
        cache_ttl = _env_int_first([CLOUD_BACKUP_ENTITLEMENT_CACHE_TTL_ENV], 0, minimum=0)
        return HttpCloudBackupEntitlementVerifier(
            url,
            bearer_token=bearer_token,
            timeout_seconds=timeout,
            cache_ttl_seconds=cache_ttl,
        )

    if raw_static_users:
        if app_env not in LOCAL_APP_ENVS:
            raise ValueError(
                f"{CLOUD_BACKUP_MAX_ENTITLED_USERS_ENV} is allowed only when "
                "APP_ENV is test, local, development, or dev"
            )
        return StaticMaxUserEntitlementVerifier(_parse_static_users(raw_static_users))

    return FailClosedCloudBackupEntitlementVerifier()


def _body_allows_cloud_backup(body: Mapping[str, Any]) -> bool:
    for candidate in _candidate_entitlement_bodies(body):
        tier = _first_lower_string(
            candidate,
            "entitlementTier",
            "tier",
            "plan",
            "subscriptionTier",
        )
        if tier != "max":
            continue
        if _is_active_entitlement(candidate):
            return True
    return False


def _candidate_entitlement_bodies(body: Mapping[str, Any]) -> Iterable[Mapping[str, Any]]:
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
    if body.get("active") is True or body.get("entitlementActive") is True:
        return True
    status = _first_lower_string(body, "status", "entitlementStatus", "state")
    return status == "active"


def _parse_static_users(raw_value: str) -> Iterable[str]:
    decoded = json.loads(raw_value)
    if isinstance(decoded, list):
        return [str(item) for item in decoded]
    if isinstance(decoded, dict):
        return [str(user_id) for user_id, is_max in decoded.items() if is_max is True]
    raise ValueError(f"{CLOUD_BACKUP_MAX_ENTITLED_USERS_ENV} must be a JSON list or object")


def cloud_backup_app_env() -> str:
    return _env_first("APP_ENV", "FLEET_APP_ENV").lower() or "production"


def cloud_backup_entitlement_diagnostic_state(
    verifier: CloudBackupEntitlementVerifier,
) -> str:
    if isinstance(verifier, HttpCloudBackupEntitlementVerifier):
        return "configured"
    if isinstance(verifier, StaticMaxUserEntitlementVerifier):
        return "disabled_for_test"
    if isinstance(verifier, FailClosedCloudBackupEntitlementVerifier):
        return "missing"
    return "configured"


def _env_first(*names: str) -> str:
    for name in names:
        raw = os.environ.get(name, "").strip()
        if raw:
            return raw
    return ""


def _env_int_first(names: Iterable[str], default: int, *, minimum: int = 1) -> int:
    for name in names:
        raw = os.environ.get(name, "").strip()
        if raw:
            return _env_int(name, default, minimum=minimum)
    return default


def _env_int(name: str, default: int, *, minimum: int = 1) -> int:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return default
    try:
        value = int(raw)
    except ValueError as exc:
        raise ValueError(f"{name} must be an integer") from exc
    if value < minimum:
        raise ValueError(f"{name} must be >= {minimum}")
    return value
