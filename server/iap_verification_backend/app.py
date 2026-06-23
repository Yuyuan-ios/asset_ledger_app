#!/usr/bin/env python3
"""FleetLedger IAP verification backend bootstrap and compatibility facade.

IAP-S1 provides the HTTP contract, persistence, and a deterministic fake Apple
verifier seam. Real App Store Server API integration is intentionally deferred
to IAP-S2.
"""

from __future__ import annotations

from apple_verifier import (
    APPLE_STATUS_ACTIVE,
    APPLE_STATUS_BILLING_GRACE_PERIOD,
    APPLE_STATUS_BILLING_RETRY,
    APPLE_STATUS_EXPIRED,
    APPLE_STATUS_REVOKED,
    ENVIRONMENT_PRODUCTION,
    ENVIRONMENT_SANDBOX,
    AppleSubscriptionStatusClient,
    AppleSubscriptionStatusItem,
    AppStoreServerAppleVerifier,
    DecodedAppleRenewalInfo,
    DecodedAppleTransaction,
    OfficialSignedDataVerifier,
    OfficialSubscriptionStatusClient,
    SignedApplePayloadVerifier,
    build_real_apple_verifier_from_config,
    map_apple_subscription_state,
)
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
    env_optional_int,
    non_empty_string,
    validate_allowed_products,
)
from handlers import (
    build_verifier_from_config,
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
    "APPLE_STATUS_ACTIVE",
    "APPLE_STATUS_BILLING_GRACE_PERIOD",
    "APPLE_STATUS_BILLING_RETRY",
    "APPLE_STATUS_EXPIRED",
    "APPLE_STATUS_REVOKED",
    "AppleSubscriptionStatusClient",
    "AppleSubscriptionStatusItem",
    "AppleCredentialConfig",
    "AppleServerApiVerifierPlaceholder",
    "AppleVerificationFailed",
    "AppleVerificationUnavailable",
    "AppleVerifier",
    "AppConfig",
    "AppStoreServerAppleVerifier",
    "DEFAULT_ALLOWED_BUNDLE_ID",
    "DEFAULT_ALLOWED_PRODUCTS",
    "DEFAULT_APPLE_REQUEST_TIMEOUT_SECONDS",
    "DEFAULT_HOST",
    "DEFAULT_PORT",
    "DecodedAppleRenewalInfo",
    "DecodedAppleTransaction",
    "EntitlementRecord",
    "EntitlementStore",
    "ENVIRONMENT_PRODUCTION",
    "ENVIRONMENT_SANDBOX",
    "HttpError",
    "IapVerificationApp",
    "IapVerificationHttpServer",
    "IapVerificationRequestHandler",
    "LOGGER",
    "MAX_REQUEST_BYTES",
    "MAX_YEARLY_PRODUCT_ID",
    "OUTCOME_TO_TIER",
    "OfficialSignedDataVerifier",
    "OfficialSubscriptionStatusClient",
    "PRO_YEARLY_PRODUCT_ID",
    "PurchaseVerificationRequest",
    "REQUIRED_PURCHASE_FIELDS",
    "RESPONSE_FIELDS",
    "RequestValidator",
    "SignedApplePayloadVerifier",
    "VALID_ENTITLEMENT_TIERS",
    "VALID_OUTCOMES",
    "build_real_apple_verifier_from_config",
    "build_server_from_env",
    "build_verifier_from_config",
    "configure_logging",
    "duration_ms_since",
    "env_csv",
    "env_int",
    "env_optional_int",
    "error_response",
    "json_response",
    "last_query_value",
    "log_iap_event",
    "log_internal_error",
    "map_apple_subscription_state",
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
