from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Callable, Dict, Mapping, Optional

_SERVER_ROOT = Path(__file__).resolve().parents[1]
if str(_SERVER_ROOT) not in sys.path:
    sys.path.insert(0, str(_SERVER_ROOT))

from common.auth_identity.auth_planes import AuthPlane
from common.auth_identity.resolver import AccountIdentityResolver, ensure_auth_operation_allowed
from config import assert_no_deprecated_env_keys
from http_helpers import HttpError


USER_AUTH_HS256_SECRET_ENV = "USER_AUTH_HS256_SECRET"
USER_AUTH_JWT_ISSUER_ENV = "USER_AUTH_JWT_ISSUER"
USER_AUTH_JWT_AUDIENCE_ENV = "USER_AUTH_JWT_AUDIENCE"
USER_AUTH_INTROSPECTION_URL_ENV = "USER_AUTH_INTROSPECTION_URL"
USER_AUTH_INTROSPECTION_SERVICE_TOKEN_ENV = "USER_AUTH_INTROSPECTION_SERVICE_TOKEN"
USER_AUTH_IDENTITY_CACHE_TTL_ENV = "USER_AUTH_IDENTITY_CACHE_TTL_SECONDS"


def base64url_decode(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode((value + padding).encode("ascii"))


def base64url_encode(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode("ascii").rstrip("=")


class Authenticator:
    """Validates app bearer tokens and returns a stable user id.

    Production can either validate HS256 JWTs issued by the account service, or
    call the account service's token introspection endpoint for opaque tokens.
    For a short smoke test, FLEET_BACKUP_DEV_TOKENS_JSON can map opaque tokens
    to user ids.
    """

    def __init__(
        self,
        hs256_secret: Optional[str] = None,
        introspector: Optional[Callable[[str], str]] = None,
        dev_tokens: Optional[Mapping[str, str]] = None,
        jwt_issuer: Optional[str] = None,
        jwt_audience: Optional[str] = None,
        leeway_seconds: int = 60,
    ):
        self.auth_plane = AuthPlane.USER
        self.hs256_secret = hs256_secret
        self.introspector = introspector
        self.dev_tokens = dict(dev_tokens or {})
        self.jwt_issuer = jwt_issuer
        self.jwt_audience = jwt_audience
        self.leeway_seconds = leeway_seconds
        self.identity_resolver = AccountIdentityResolver(
            self._resolve_token_user_id,
            cache_ttl_seconds=_env_int(USER_AUTH_IDENTITY_CACHE_TTL_ENV, 15 * 60, minimum=0),
            auth_plane=self.auth_plane,
        )
        if not self.hs256_secret and not self.introspector and not self.dev_tokens:
            raise ValueError(
                "Configure USER_AUTH_HS256_SECRET, "
                "USER_AUTH_INTROSPECTION_URL, or "
                "FLEET_BACKUP_DEV_TOKENS_JSON; cloud backup must not run "
                "without authentication."
            )

    @classmethod
    def from_env(cls) -> "Authenticator":
        assert_no_deprecated_env_keys()
        raw_dev_tokens = os.environ.get("FLEET_BACKUP_DEV_TOKENS_JSON", "").strip()
        dev_tokens: Dict[str, str] = {}
        if raw_dev_tokens:
            decoded = json.loads(raw_dev_tokens)
            if not isinstance(decoded, dict):
                raise ValueError("FLEET_BACKUP_DEV_TOKENS_JSON must be an object")
            dev_tokens = {str(token): str(user_id) for token, user_id in decoded.items()}
        secret = os.environ.get(USER_AUTH_HS256_SECRET_ENV, "").strip() or None
        introspection_url = os.environ.get(USER_AUTH_INTROSPECTION_URL_ENV, "").strip()
        introspector = None
        if introspection_url:
            introspector = HttpTokenIntrospector(
                introspection_url,
                bearer_token=os.environ.get(
                    USER_AUTH_INTROSPECTION_SERVICE_TOKEN_ENV,
                    "",
                ).strip()
                or None,
            )
        return cls(
            hs256_secret=secret,
            introspector=introspector,
            dev_tokens=dev_tokens,
            jwt_issuer=os.environ.get(USER_AUTH_JWT_ISSUER_ENV, "").strip() or None,
            jwt_audience=os.environ.get(USER_AUTH_JWT_AUDIENCE_ENV, "").strip() or None,
        )

    def authenticate(self, authorization_header: Optional[str]) -> str:
        ensure_auth_operation_allowed(self.auth_plane)
        if not authorization_header or not authorization_header.startswith("Bearer "):
            raise HttpError(401, "unauthorized", "Bearer token is required")
        token = authorization_header[len("Bearer ") :].strip()
        if not token:
            raise HttpError(401, "unauthorized", "Bearer token is required")
        return self.identity_resolver.get_stable_user_id(token)

    def _resolve_token_user_id(self, token: str) -> str:
        if token in self.dev_tokens:
            return self.dev_tokens[token]
        if self.hs256_secret and len(token.split(".")) == 3:
            try:
                return self._authenticate_hs256_jwt(token)
            except HttpError:
                if self.introspector is None:
                    raise
        if self.introspector is not None:
            return self.introspector(token)
        if self.hs256_secret:
            return self._authenticate_hs256_jwt(token)
        raise HttpError(401, "unauthorized", "token is not accepted")

    def _authenticate_hs256_jwt(self, token: str) -> str:
        parts = token.split(".")
        if len(parts) != 3:
            raise HttpError(401, "invalid_token", "token must be an HS256 JWT")
        try:
            header_bytes = base64url_decode(parts[0])
            payload_bytes = base64url_decode(parts[1])
            signature = base64url_decode(parts[2])
            header = json.loads(header_bytes.decode("utf-8"))
            payload = json.loads(payload_bytes.decode("utf-8"))
        except (ValueError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise HttpError(401, "invalid_token", "token payload is invalid") from exc
        if header.get("alg") != "HS256":
            raise HttpError(401, "invalid_token", "token alg must be HS256")
        signing_input = f"{parts[0]}.{parts[1]}".encode("ascii")
        expected = hmac.new(
            self.hs256_secret.encode("utf-8"),
            signing_input,
            hashlib.sha256,
        ).digest()
        if not hmac.compare_digest(signature, expected):
            raise HttpError(401, "invalid_token", "token signature is invalid")
        now = int(time.time())
        exp = payload.get("exp")
        if isinstance(exp, int) and exp + self.leeway_seconds < now:
            raise HttpError(401, "token_expired", "token is expired")
        if self.jwt_issuer is not None and payload.get("iss") != self.jwt_issuer:
            raise HttpError(401, "invalid_token", "token issuer is invalid")
        if self.jwt_audience is not None and not audience_matches(
            payload.get("aud"),
            self.jwt_audience,
        ):
            raise HttpError(401, "invalid_token", "token audience is invalid")
        user_id = payload.get("sub") or payload.get("user_id") or payload.get("phone")
        if not isinstance(user_id, str) or not user_id.strip():
            raise HttpError(401, "invalid_token", "token is missing user id")
        return user_id.strip()


class HttpTokenIntrospector:
    """Validates opaque login tokens through the account service."""

    def __init__(self, url: str, bearer_token: Optional[str] = None, timeout: int = 5):
        if not url.startswith("https://"):
            raise ValueError(f"{USER_AUTH_INTROSPECTION_URL_ENV} must be https")
        self.url = url
        self.bearer_token = bearer_token
        self.auth_plane = AuthPlane.SERVICE if bearer_token else AuthPlane.USER
        self.timeout = timeout

    def __call__(self, token: str) -> str:
        body = json.dumps({"token": token}, separators=(",", ":")).encode("utf-8")
        request = urllib.request.Request(
            self.url,
            data=body,
            method="POST",
            headers={
                "Accept": "application/json",
                "Content-Type": "application/json",
            },
        )
        if self.bearer_token:
            request.add_header("Authorization", f"Bearer {self.bearer_token}")
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                raw = response.read()
        except urllib.error.HTTPError as exc:
            if exc.code in (401, 403):
                raise HttpError(401, "invalid_token", "token is not accepted") from exc
            raise HttpError(
                503,
                "auth_service_unavailable",
                "auth service is temporarily unavailable",
            ) from exc
        except urllib.error.URLError as exc:
            raise HttpError(
                503,
                "auth_service_unavailable",
                "auth service is temporarily unavailable",
            ) from exc
        try:
            decoded = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise HttpError(
                503,
                "auth_service_unavailable",
                "auth service returned invalid JSON",
            ) from exc
        if not isinstance(decoded, dict):
            raise HttpError(503, "auth_service_unavailable", "auth service response must be an object")
        active = decoded.get("active")
        ok = decoded.get("ok")
        if active is False or ok is False:
            raise HttpError(401, "invalid_token", "token is not accepted")
        if active is not True and ok is not True:
            raise HttpError(401, "invalid_token", "auth service did not accept token")
        user_id = extract_user_id(decoded)
        if user_id is None:
            raise HttpError(401, "invalid_token", "auth service response is missing user id")
        return user_id


def audience_matches(raw_audience: Any, expected: str) -> bool:
    if isinstance(raw_audience, str):
        return raw_audience == expected
    if isinstance(raw_audience, list):
        return expected in [value for value in raw_audience if isinstance(value, str)]
    return False


def extract_user_id(body: Mapping[str, Any]) -> Optional[str]:
    for key in ("sub", "user_id", "phone"):
        value = body.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    user = body.get("user")
    if isinstance(user, Mapping):
        for key in ("id", "user_id", "phone"):
            value = user.get(key)
            if isinstance(value, str) and value.strip():
                return value.strip()
    return None

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
