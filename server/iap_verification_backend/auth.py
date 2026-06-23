from __future__ import annotations

import uuid
from typing import Any, Mapping, Optional, Sequence

from http_helpers import HttpError
from verifier import PurchaseVerificationRequest


REQUIRED_PURCHASE_FIELDS = (
    "platform",
    "productId",
    "serverVerificationData",
    "localVerificationData",
    "source",
    "status",
    "appAccountToken",
)


class RequestValidator:
    def __init__(self, allowed_products: Sequence[str], allowed_bundle_id: str):
        self.allowed_products = tuple(allowed_products)
        self.allowed_bundle_id = allowed_bundle_id

    def validate_purchase_body(self, body: Mapping[str, Any]) -> PurchaseVerificationRequest:
        for field in REQUIRED_PURCHASE_FIELDS:
            require_present(body.get(field), field)

        platform = require_text(body.get("platform"), "platform", max_length=16)
        if platform != "ios":
            raise HttpError(400, "invalid_platform", "platform must be ios")

        source = require_text(body.get("source"), "source", max_length=64)
        if source != "app_store":
            raise HttpError(400, "invalid_source", "source must be app_store")

        status = require_text(body.get("status"), "status", max_length=64)
        product_id = require_text(body.get("productId"), "productId", max_length=256)
        if product_id not in self.allowed_products:
            raise HttpError(400, "unknown_product", "productId is not allowed")

        bundle_id = optional_text(body.get("bundleId"), "bundleId", max_length=256)
        if bundle_id is not None and bundle_id != self.allowed_bundle_id:
            raise HttpError(400, "invalid_bundle_id", "bundleId is not allowed")

        return PurchaseVerificationRequest(
            platform=platform,
            product_id=product_id,
            server_verification_data=require_text(
                body.get("serverVerificationData"),
                "serverVerificationData",
                max_length=65536,
            ),
            local_verification_data=require_text(
                body.get("localVerificationData"),
                "localVerificationData",
                max_length=65536,
            ),
            source=source,
            status=status,
            app_account_token=validate_app_account_token(body.get("appAccountToken")),
            purchase_id=optional_text(body.get("purchaseId"), "purchaseId", max_length=256),
            transaction_date=optional_text(body.get("transactionDate"), "transactionDate", max_length=64),
            bundle_id=bundle_id,
        )

    def validate_current_entitlement_query(self, raw_value: Optional[str]) -> str:
        if raw_value is None:
            raise HttpError(400, "missing_app_account_token", "appAccountToken is required")
        return validate_app_account_token(raw_value)


def validate_app_account_token(value: Any) -> str:
    token = require_text(value, "appAccountToken", max_length=64)
    try:
        uuid.UUID(token)
    except (TypeError, ValueError) as exc:
        raise HttpError(400, "invalid_app_account_token", "appAccountToken must be a UUID") from exc
    return token


def require_text(value: Any, name: str, *, max_length: int) -> str:
    if not isinstance(value, str) or not value.strip():
        raise HttpError(400, "invalid_request", f"{name} is required")
    result = value.strip()
    if len(result) > max_length:
        raise HttpError(400, "invalid_request", f"{name} is too long")
    return result


def require_present(value: Any, name: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise HttpError(400, "invalid_request", f"{name} is required")


def optional_text(value: Any, name: str, *, max_length: int) -> Optional[str]:
    if value is None:
        return None
    return require_text(value, name, max_length=max_length)
