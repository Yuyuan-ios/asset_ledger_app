from __future__ import annotations

import json
import os
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Dict, Iterable, Mapping, Optional, Protocol

from http_helpers import HttpError


CLOUD_BACKUP_REQUIRES_MAX_CODE = "cloud_backup_requires_max"
CLOUD_BACKUP_REQUIRES_MAX_MESSAGE = "Cloud backup requires Max subscription."
SUBSCRIPTION_VERIFICATION_UNAVAILABLE_CODE = "subscription_verification_unavailable"
SUBSCRIPTION_VERIFICATION_UNAVAILABLE_MESSAGE = "Subscription verification is currently unavailable."


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

    The endpoint is expected to be HTTPS and return JSON with either
    {"entitlementTier":"max"} or {"canUseCloudBackup":true}. User ids are sent
    as server-authenticated query parameters, never trusted from client headers.
    """

    def __init__(
        self,
        url: str,
        *,
        bearer_token: Optional[str] = None,
        timeout_seconds: int = 5,
    ):
        if not url.startswith("https://"):
            raise ValueError("FLEET_BACKUP_ENTITLEMENT_VERIFICATION_URL must be https")
        self.url = url
        self.bearer_token = bearer_token
        self.timeout_seconds = timeout_seconds

    def require_max(self, user_id: str) -> None:
        query = urllib.parse.urlencode({"userId": user_id})
        separator = "&" if "?" in self.url else "?"
        request = urllib.request.Request(
            f"{self.url}{separator}{query}",
            method="GET",
            headers={"Accept": "application/json"},
        )
        if self.bearer_token:
            request.add_header("Authorization", f"Bearer {self.bearer_token}")
        try:
            with urllib.request.urlopen(request, timeout=self.timeout_seconds) as response:
                raw = response.read()
        except urllib.error.HTTPError as exc:
            if exc.code in (401, 403, 404):
                raise cloud_backup_requires_max_error() from exc
            raise subscription_verification_unavailable_error() from exc
        except urllib.error.URLError as exc:
            raise subscription_verification_unavailable_error() from exc
        try:
            decoded = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise subscription_verification_unavailable_error() from exc
        if not isinstance(decoded, dict):
            raise subscription_verification_unavailable_error()
        if _body_allows_cloud_backup(decoded):
            return
        raise cloud_backup_requires_max_error()


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
    url = os.environ.get("FLEET_BACKUP_ENTITLEMENT_VERIFICATION_URL", "").strip()
    if url:
        timeout = _env_int("FLEET_BACKUP_ENTITLEMENT_TIMEOUT_SECONDS", 5)
        bearer_token = os.environ.get("FLEET_BACKUP_ENTITLEMENT_BEARER_TOKEN", "").strip() or None
        return HttpCloudBackupEntitlementVerifier(
            url,
            bearer_token=bearer_token,
            timeout_seconds=timeout,
        )

    raw_static_users = os.environ.get("FLEET_BACKUP_MAX_ENTITLED_USERS_JSON", "").strip()
    if raw_static_users:
        app_env = os.environ.get("APP_ENV", os.environ.get("FLEET_APP_ENV", "")).strip().lower()
        if app_env not in {"test", "local", "development"}:
            raise ValueError(
                "FLEET_BACKUP_MAX_ENTITLED_USERS_JSON is allowed only when "
                "APP_ENV is test, local, or development"
            )
        return StaticMaxUserEntitlementVerifier(_parse_static_users(raw_static_users))

    return FailClosedCloudBackupEntitlementVerifier()


def _body_allows_cloud_backup(body: Mapping[str, Any]) -> bool:
    if body.get("entitlementTier") == "max":
        return True
    if body.get("tier") == "max":
        return True
    return body.get("canUseCloudBackup") is True


def _parse_static_users(raw_value: str) -> Iterable[str]:
    decoded = json.loads(raw_value)
    if isinstance(decoded, list):
        return [str(item) for item in decoded]
    if isinstance(decoded, dict):
        return [str(user_id) for user_id, is_max in decoded.items() if is_max is True]
    raise ValueError("FLEET_BACKUP_MAX_ENTITLED_USERS_JSON must be a JSON list or object")


def _env_int(name: str, default: int) -> int:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return default
    try:
        value = int(raw)
    except ValueError as exc:
        raise ValueError(f"{name} must be an integer") from exc
    if value <= 0:
        raise ValueError(f"{name} must be > 0")
    return value
