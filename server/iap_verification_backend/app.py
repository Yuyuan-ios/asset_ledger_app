#!/usr/bin/env python3
"""FleetLedger IAP verification backend bootstrap and compatibility facade.

IAP-S1 provides the HTTP contract, persistence, and a deterministic fake Apple
verifier seam. Real App Store Server API integration is intentionally deferred
to IAP-S2.
"""

from __future__ import annotations

from auth import REQUIRED_PURCHASE_FIELDS, RequestValidator, optional_text, require_text, validate_app_account_token
from config import (
    DEFAULT_ALLOWED_BUNDLE_ID,
    DEFAULT_ALLOWED_PRODUCTS,
    DEFAULT_APPLE_REQUEST_TIMEOUT_SECONDS,
    DEFAULT_HOST,
    DEFAULT_PORT,
    MAX_REQUEST_BYTES,
    MAX_YEARLY_PRODUCT_ID,
    PRO_YEARLY_PRODUCT_ID,
    AppleCredentialConfig,
    AppConfig,
    env_csv,
    env_int,
    non_empty_string,
    validate_allowed_products,
)
from handlers import (
    IapVerificationApp,
    IapVerificationHttpServer,
    IapVerificationRequestHandler,
    build_server_from_env,
    last_query_value,
)
from http_helpers import (
    LOGGER,
    HttpError,
    configure_logging,
    duration_ms_since,
    error_response,
    json_response,
    log_iap_event,
    log_internal_error,
    read_json_body,
    request_id_from_headers,
    utc_now_iso,
)
from storage import EntitlementStore
from verifier import (
    OUTCOME_TO_TIER,
    RESPONSE_FIELDS,
    VALID_ENTITLEMENT_TIERS,
    VALID_OUTCOMES,
    AppleServerApiVerifierPlaceholder,
    AppleVerificationFailed,
    AppleVerificationUnavailable,
    AppleVerifier,
    EntitlementRecord,
    PurchaseVerificationRequest,
    no_active_entitlement_record,
    verification_failed_record,
    verification_unavailable_record,
)

__all__ = [
    "AppleCredentialConfig",
    "AppleServerApiVerifierPlaceholder",
    "AppleVerificationFailed",
    "AppleVerificationUnavailable",
    "AppleVerifier",
    "AppConfig",
    "DEFAULT_ALLOWED_BUNDLE_ID",
    "DEFAULT_ALLOWED_PRODUCTS",
    "DEFAULT_APPLE_REQUEST_TIMEOUT_SECONDS",
    "DEFAULT_HOST",
    "DEFAULT_PORT",
    "EntitlementRecord",
    "EntitlementStore",
    "HttpError",
    "IapVerificationApp",
    "IapVerificationHttpServer",
    "IapVerificationRequestHandler",
    "LOGGER",
    "MAX_REQUEST_BYTES",
    "MAX_YEARLY_PRODUCT_ID",
    "OUTCOME_TO_TIER",
    "PRO_YEARLY_PRODUCT_ID",
    "PurchaseVerificationRequest",
    "REQUIRED_PURCHASE_FIELDS",
    "RESPONSE_FIELDS",
    "RequestValidator",
    "VALID_ENTITLEMENT_TIERS",
    "VALID_OUTCOMES",
    "build_server_from_env",
    "configure_logging",
    "duration_ms_since",
    "env_csv",
    "env_int",
    "error_response",
    "json_response",
    "last_query_value",
    "log_iap_event",
    "log_internal_error",
    "main",
    "no_active_entitlement_record",
    "non_empty_string",
    "optional_text",
    "read_json_body",
    "request_id_from_headers",
    "require_text",
    "utc_now_iso",
    "validate_app_account_token",
    "validate_allowed_products",
    "verification_failed_record",
    "verification_unavailable_record",
]


def main() -> None:
    configure_logging()
    server = build_server_from_env()
    host, port = server.server_address
    print(f"FleetLedger IAP verification backend listening on {host}:{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
