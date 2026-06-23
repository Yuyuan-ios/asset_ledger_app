from __future__ import annotations

import dataclasses
import os
from typing import Optional, Tuple


PRO_YEARLY_PRODUCT_ID = "com.yuyuan.assetledger.pro.yearly"
MAX_YEARLY_PRODUCT_ID = "com.yuyuan.assetledger.max.yearly"
DEFAULT_ALLOWED_PRODUCTS = (PRO_YEARLY_PRODUCT_ID, MAX_YEARLY_PRODUCT_ID)
DEFAULT_ALLOWED_BUNDLE_ID = "com.yuyuan.assetledger"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8010
MAX_REQUEST_BYTES = 1024 * 1024
DEFAULT_APPLE_REQUEST_TIMEOUT_SECONDS = 10


def env_int(name: str, default: int, *, minimum: int = 1) -> int:
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


def non_empty_string(value: object) -> Optional[str]:
    if not isinstance(value, str):
        return None
    stripped = value.strip()
    return stripped or None


def env_csv(name: str, default: Tuple[str, ...]) -> Tuple[str, ...]:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return default
    values = tuple(part.strip() for part in raw.split(",") if part.strip())
    if not values:
        raise ValueError(f"{name} must contain at least one value")
    return values


def validate_allowed_products(products: Tuple[str, ...]) -> Tuple[str, ...]:
    unknown = sorted(set(products) - set(DEFAULT_ALLOWED_PRODUCTS))
    if unknown:
        joined = ", ".join(unknown)
        raise ValueError(f"FLEET_IAP_ALLOWED_PRODUCTS contains unsupported product ids: {joined}")
    return products


@dataclasses.dataclass(frozen=True)
class AppleCredentialConfig:
    key_id: Optional[str]
    issuer_id: Optional[str]
    private_key_path: Optional[str]
    bundle_id: Optional[str]

    @classmethod
    def from_env(cls) -> "AppleCredentialConfig":
        return cls(
            key_id=non_empty_string(os.environ.get("FLEET_IAP_APPLE_KEY_ID")),
            issuer_id=non_empty_string(os.environ.get("FLEET_IAP_APPLE_ISSUER_ID")),
            private_key_path=non_empty_string(os.environ.get("FLEET_IAP_APPLE_PRIVATE_KEY_PATH")),
            bundle_id=non_empty_string(os.environ.get("FLEET_IAP_APPLE_BUNDLE_ID")),
        )

    @property
    def is_complete(self) -> bool:
        return (
            self.key_id is not None
            and self.issuer_id is not None
            and self.private_key_path is not None
            and self.bundle_id is not None
        )


@dataclasses.dataclass(frozen=True)
class AppConfig:
    host: str
    port: int
    database_path: str
    allowed_bundle_id: str
    allowed_products: Tuple[str, ...]
    max_request_bytes: int
    apple_request_timeout_seconds: int
    apple_credentials: AppleCredentialConfig

    @classmethod
    def from_env(cls) -> "AppConfig":
        allowed_products = validate_allowed_products(
            env_csv("FLEET_IAP_ALLOWED_PRODUCTS", DEFAULT_ALLOWED_PRODUCTS)
        )
        allowed_bundle_id = non_empty_string(os.environ.get("FLEET_IAP_ALLOWED_BUNDLE_ID")) or DEFAULT_ALLOWED_BUNDLE_ID
        return cls(
            host=os.environ.get("FLEET_IAP_HOST", DEFAULT_HOST),
            port=env_int("FLEET_IAP_PORT", DEFAULT_PORT),
            database_path=os.environ.get("FLEET_IAP_DB_PATH", "./data/iap_verification.sqlite3"),
            allowed_bundle_id=allowed_bundle_id,
            allowed_products=allowed_products,
            max_request_bytes=env_int("FLEET_IAP_MAX_REQUEST_BYTES", MAX_REQUEST_BYTES),
            apple_request_timeout_seconds=env_int(
                "FLEET_IAP_APPLE_REQUEST_TIMEOUT_SECONDS",
                DEFAULT_APPLE_REQUEST_TIMEOUT_SECONDS,
            ),
            apple_credentials=AppleCredentialConfig.from_env(),
        )
