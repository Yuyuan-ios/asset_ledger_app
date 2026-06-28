from __future__ import annotations

import re
from typing import Any, Mapping


_SENSITIVE_KEY_NAMES = {
    "authorization",
    "bearer",
    "jws",
    "jwt",
    "purchase_token",
    "purchasetoken",
    "raw_payload",
    "rawpayload",
    "secret",
    "signature",
    "token",
    "transaction_id",
    "transactionid",
}

_SENSITIVE_KEY_FRAGMENTS = (
    "authorization",
    "bearer",
    "jws",
    "jwt",
    "purchasetoken",
    "rawpayload",
    "secret",
    "signature",
    "token",
    "transactionid",
)

_SENSITIVE_VALUE_RE = re.compile(
    r"(?i)(bearer\s+[a-z0-9._~+/=-]+|eyj[a-z0-9._-]*\.[a-z0-9._-]+\.[a-z0-9._-]+)"
)


def sanitize_observability_payload(data: Any) -> Any:
    """Remove sensitive purchase/auth material from observability payloads."""

    if isinstance(data, Mapping):
        sanitized: dict[str, Any] = {}
        for key, value in data.items():
            normalized = _normalize_key(key)
            if _is_sensitive_key(normalized):
                continue
            sanitized[str(key)] = sanitize_observability_payload(value)
        return sanitized
    if isinstance(data, list):
        return [sanitize_observability_payload(item) for item in data]
    if isinstance(data, tuple):
        return [sanitize_observability_payload(item) for item in data]
    if isinstance(data, str):
        if _SENSITIVE_VALUE_RE.search(data):
            return "<redacted>"
        lowered = data.lower()
        if "bearer " in lowered or "secret" in lowered or "purchase token" in lowered:
            return "<redacted>"
        return data
    return data


def _normalize_key(key: Any) -> str:
    return re.sub(r"[^a-z0-9]", "", str(key).strip().lower())


def _is_sensitive_key(normalized_key: str) -> bool:
    if normalized_key in _SENSITIVE_KEY_NAMES:
        return True
    return any(fragment in normalized_key for fragment in _SENSITIVE_KEY_FRAGMENTS)
