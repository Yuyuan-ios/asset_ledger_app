from __future__ import annotations

import hashlib
import time
from typing import Callable, Dict, Optional, Tuple

from http_helpers import HttpError

from .auth_planes import AuthPlane


DEFAULT_IDENTITY_CACHE_TTL_SECONDS = 15 * 60


class SecurityViolation(RuntimeError):
    pass


def ensure_auth_operation_allowed(plane: AuthPlane) -> None:
    if plane == AuthPlane.CLIENT or str(plane) == AuthPlane.CLIENT.value:
        raise SecurityViolation("CLIENT token plane is not allowed for auth operations")


class AccountIdentityResolver:
    """Resolves login tokens to stable FleetLedger account user ids.

    Contract: user_id is the unique account identity. It is not a session id,
    device id, appAccountToken, or client-supplied fallback.
    """

    def __init__(
        self,
        token_user_id_resolver: Callable[[str], str],
        *,
        cache_ttl_seconds: int = DEFAULT_IDENTITY_CACHE_TTL_SECONDS,
        auth_plane: AuthPlane = AuthPlane.USER,
    ):
        ensure_auth_operation_allowed(auth_plane)
        self.token_user_id_resolver = token_user_id_resolver
        self.cache_ttl_seconds = max(0, cache_ttl_seconds)
        self.auth_plane = auth_plane
        self._cache: Dict[str, Tuple[str, float]] = {}

    def get_stable_user_id(
        self,
        token: str,
        *,
        auth_plane: Optional[AuthPlane] = None,
    ) -> str:
        ensure_auth_operation_allowed(auth_plane or self.auth_plane)
        token_digest = _token_digest(token)
        cached = self._cache.get(token_digest)
        if cached is not None:
            user_id, expires_at = cached
            if expires_at > time.monotonic():
                return user_id
            self._cache.pop(token_digest, None)

        user_id = require_stable_user_id(
            self.token_user_id_resolver(token),
            field_name="user_id",
            auth_plane=auth_plane or self.auth_plane,
        )
        if self.cache_ttl_seconds > 0:
            self._cache[token_digest] = (
                user_id,
                time.monotonic() + self.cache_ttl_seconds,
            )
        return user_id

    def getStableUserId(self, token: str) -> str:
        return self.get_stable_user_id(token)


def require_stable_user_id(
    value: object,
    *,
    field_name: str = "user_id",
    max_length: int = 256,
    auth_plane: Optional[AuthPlane] = None,
) -> str:
    if auth_plane is not None:
        ensure_auth_operation_allowed(auth_plane)
    if not isinstance(value, str) or not value.strip():
        raise HttpError(400, "invalid_request", f"{field_name} is required")
    user_id = value.strip()
    if len(user_id) > max_length:
        raise HttpError(400, "invalid_request", f"{field_name} is too long")
    return user_id


def _token_digest(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()
