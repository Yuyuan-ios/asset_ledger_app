#!/usr/bin/env python3
"""FleetLedger IAP verification backend bootstrap and compatibility facade.

IAP-S1 provides the HTTP contract, persistence, and a deterministic fake Apple
verifier seam. Real App Store Server API integration is intentionally deferred
to IAP-S2.
"""

from __future__ import annotations

import sys
from pathlib import Path

_SERVER_ROOT = Path(__file__).resolve().parents[1]
if str(_SERVER_ROOT) not in sys.path:
    sys.path.insert(0, str(_SERVER_ROOT))

from common.auth_identity.auth_planes import AuthPlane
from common.auth_identity.resolver import (
    AccountIdentityResolver,
    SecurityViolation,
    require_stable_user_id,
)
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
from auth import (
    REQUIRED_PURCHASE_FIELDS,
    Authenticator,
    HttpTokenIntrospector,
    RequestValidator,
    base64url_encode,
    optional_text,
    require_text,
    validate_app_account_token,
)
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
    ConfigMigrationError,
    EXTERNAL_CLIENT_TOKEN_REQUIRED,
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
from runtime_write_firewall import (
    RBL_VIOLATION_LOG,
    RblViolation,
    RuntimeSystemContextSigner,
    RuntimeWriteContext,
    RuntimeWriteFirewall,
)
from payment_channel_adapters import (
    APPLE_CHANNEL,
    GOOGLE_PLAY_CHANNEL,
    HUAWEI_CHANNEL,
    OPPO_CHANNEL,
    VIVO_CHANNEL,
    XIAOMI_CHANNEL,
    AppleAdapter,
    SignedWebhookAdapter,
    build_default_payment_channel_adapters,
    normalize_channel_name,
    signature_for_payload,
)
from subscription_storage_gateway import (
    ENTITLEMENT_BINDING_POLICIES,
    EntitlementBindingPolicy,
    EntitlementDBGateway,
    EntitlementStore,
)
from subscription_audit_log import (
    ENTITLEMENT_CHANGE_LOG,
    PROCESSED_EVENT_LOG,
    RAW_EVENT_LOG,
    SubscriptionAuditLog,
)
from integrity_audit_trail import INTEGRITY_AUDIT_LOG, IntegrityAuditTrail
from subscription_authority_resolver import SubscriptionAuthorityResolver
from subscription_event_ordering import SubscriptionEventOrdering
from subscription_event_hash_chain import (
    GENESIS_EVENT_HASH,
    ChainVerificationResult,
    EventHashChain,
)
from subscription_event_model import (
    EVENT_EXPIRE,
    EVENT_PURCHASE,
    EVENT_REFUND,
    EVENT_RENEW,
    EVENT_REVOKE,
    SUBSCRIPTION_EVENT_TYPES,
    Event,
    SubscriptionEvent,
)
from subscription_event_explainer import (
    EventExplanation,
    ExplanationIntegrityError,
    SubscriptionEventExplainer,
)
from subscription_event_explanation_store import (
    SubscriptionEventExplanationStore,
    SubscriptionExplanationConflict,
)
from subscription_decision_graph import (
    DecisionEdge,
    DecisionGraph,
    DecisionNode,
)
from subscription_decision_graph_builder import SubscriptionDecisionGraphBuilder
from subscription_decision_graph_store import SubscriptionDecisionGraphStore
from subscription_observability_sanitizer import sanitize_observability_payload
from subscription_event_store import (
    SubscriptionEventAppendResult,
    SubscriptionEventReplay,
    SubscriptionEventStore,
    SubscriptionLedgerIntegrityError,
    TamperEvidentEventStore,
)
from entitlement_projection_store import EntitlementProjectionStore, PROJECTION_CACHE_ONLY_NOTICE
from subscription_integrity_verifier import (
    FINAL_VERDICT_COMPROMISED,
    FINAL_VERDICT_VERIFIED,
    LEDGER_STATUS_COMPROMISED,
    LEDGER_STATUS_IMMUTABLE,
    REPLAY_STATUS_TRUSTED,
    REPLAY_STATUS_UNTRUSTED,
    IntegrityVerifier,
    LedgerIntegrityReport,
    VerificationResult,
)
from replay_verification_engine_v2 import ReplayVerificationEngineV2
from subscription_replay_engine import (
    EntitlementState,
    ProductReplayState,
    ReplayDecision,
    SubscriptionProjectionDriftError,
    SubscriptionReplayEngine,
)
from subscription_gateway import (
    ChannelVerificationResult,
    EntitlementEngine,
    PaymentChannelAdapter,
    PurchaseEvent,
    SubscriptionGatewayService,
)
from subscription_reconciliation_worker import (
    ProviderSubscriptionState,
    SubscriptionReconciliationWorker,
)
from subscription_state_machine import (
    STATE_ACTIVE,
    STATE_EXPIRED,
    STATE_GRACE,
    STATE_NONE,
    STATE_REVOKED,
    SubscriptionStateMachine,
)
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
    "APPLE_CHANNEL",
    "AppleSubscriptionStatusClient",
    "AppleSubscriptionStatusItem",
    "AppleCredentialConfig",
    "AppleServerApiVerifierPlaceholder",
    "AppleVerificationFailed",
    "AppleVerificationUnavailable",
    "AppleVerifier",
    "AppConfig",
    "AppStoreServerAppleVerifier",
    "AccountIdentityResolver",
    "AuthPlane",
    "Authenticator",
    "AppleAdapter",
    "ChannelVerificationResult",
    "ChainVerificationResult",
    "ConfigMigrationError",
    "DEFAULT_ALLOWED_BUNDLE_ID",
    "DEFAULT_ALLOWED_PRODUCTS",
    "DEFAULT_APPLE_REQUEST_TIMEOUT_SECONDS",
    "DEFAULT_HOST",
    "DEFAULT_PORT",
    "DecodedAppleRenewalInfo",
    "DecodedAppleTransaction",
    "DecisionEdge",
    "DecisionGraph",
    "DecisionNode",
    "EntitlementRecord",
    "EntitlementEngine",
    "EntitlementProjectionStore",
    "EventExplanation",
    "ENTITLEMENT_CHANGE_LOG",
    "EntitlementBindingPolicy",
    "ENTITLEMENT_BINDING_POLICIES",
    "EntitlementDBGateway",
    "EntitlementStore",
    "EntitlementState",
    "ENVIRONMENT_PRODUCTION",
    "ENVIRONMENT_SANDBOX",
    "ExplanationIntegrityError",
    "HttpError",
    "HttpTokenIntrospector",
    "IapVerificationApp",
    "IapVerificationHttpServer",
    "IapVerificationRequestHandler",
    "LOGGER",
    "MAX_REQUEST_BYTES",
    "MAX_YEARLY_PRODUCT_ID",
    "GOOGLE_PLAY_CHANNEL",
    "HUAWEI_CHANNEL",
    "OUTCOME_TO_TIER",
    "OfficialSignedDataVerifier",
    "OfficialSubscriptionStatusClient",
    "OPPO_CHANNEL",
    "PaymentChannelAdapter",
    "ProductReplayState",
    "PROJECTION_CACHE_ONLY_NOTICE",
    "PROCESSED_EVENT_LOG",
    "PRO_YEARLY_PRODUCT_ID",
    "ProviderSubscriptionState",
    "PurchaseEvent",
    "PurchaseVerificationRequest",
    "RAW_EVENT_LOG",
    "RBL_VIOLATION_LOG",
    "REQUIRED_PURCHASE_FIELDS",
    "RESPONSE_FIELDS",
    "RequestValidator",
    "ReplayDecision",
    "ReplayVerificationEngineV2",
    "REPLAY_STATUS_TRUSTED",
    "REPLAY_STATUS_UNTRUSTED",
    "RblViolation",
    "RuntimeSystemContextSigner",
    "RuntimeWriteContext",
    "RuntimeWriteFirewall",
    "SecurityViolation",
    "SignedApplePayloadVerifier",
    "SignedWebhookAdapter",
    "STATE_ACTIVE",
    "STATE_EXPIRED",
    "STATE_GRACE",
    "STATE_NONE",
    "STATE_REVOKED",
    "SUBSCRIPTION_EVENT_TYPES",
    "SubscriptionAuditLog",
    "SubscriptionAuthorityResolver",
    "SubscriptionDecisionGraphBuilder",
    "SubscriptionDecisionGraphStore",
    "SubscriptionEvent",
    "SubscriptionEventAppendResult",
    "SubscriptionEventExplainer",
    "SubscriptionEventExplanationStore",
    "SubscriptionEventOrdering",
    "SubscriptionEventReplay",
    "SubscriptionEventStore",
    "SubscriptionExplanationConflict",
    "SubscriptionLedgerIntegrityError",
    "SubscriptionProjectionDriftError",
    "SubscriptionGatewayService",
    "SubscriptionReconciliationWorker",
    "SubscriptionReplayEngine",
    "SubscriptionStateMachine",
    "TamperEvidentEventStore",
    "VALID_ENTITLEMENT_TIERS",
    "VALID_OUTCOMES",
    "VerificationResult",
    "VIVO_CHANNEL",
    "XIAOMI_CHANNEL",
    "EVENT_EXPIRE",
    "EVENT_PURCHASE",
    "EVENT_REFUND",
    "EVENT_RENEW",
    "EVENT_REVOKE",
    "Event",
    "base64url_encode",
    "build_default_payment_channel_adapters",
    "build_real_apple_verifier_from_config",
    "build_server_from_env",
    "build_verifier_from_config",
    "configure_logging",
    "duration_ms_since",
    "env_csv",
    "env_int",
    "env_optional_int",
    "error_response",
    "EXTERNAL_CLIENT_TOKEN_REQUIRED",
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
    "require_stable_user_id",
    "require_text",
    "normalize_channel_name",
    "sanitize_observability_payload",
    "signature_for_payload",
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
    "EventHashChain",
    "FINAL_VERDICT_COMPROMISED",
    "FINAL_VERDICT_VERIFIED",
    "GENESIS_EVENT_HASH",
    "INTEGRITY_AUDIT_LOG",
    "IntegrityAuditTrail",
    "IntegrityVerifier",
    "LEDGER_STATUS_COMPROMISED",
    "LEDGER_STATUS_IMMUTABLE",
    "LedgerIntegrityReport",
