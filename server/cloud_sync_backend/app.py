#!/usr/bin/env python3
"""FleetLedger cloud sync backend bootstrap and compatibility facade.

Minimal production path:
  Flutter App -> HTTPS /sync/changes -> this service -> SQLite change log

This service is intentionally independent from server/cloud_backup_backend/.
It shares the same app-login bearer-token trust model, but does not call the
backup service and does not expose any object-storage credentials to clients.
"""

from __future__ import annotations

import sys
from pathlib import Path

_SERVER_ROOT = Path(__file__).resolve().parents[1]
if str(_SERVER_ROOT) not in sys.path:
    sys.path.insert(0, str(_SERVER_ROOT))

from auth import (
    Authenticator,
    HttpTokenIntrospector,
    audience_matches,
    base64url_decode,
    base64url_encode,
    extract_account_id,
)
from config import (
    DEFAULT_PORT,
    DEFAULT_PULL_LIMIT,
    DEFAULT_RATE_LIMIT_MAX_REQUESTS,
    DEFAULT_RATE_LIMIT_WINDOW_SECONDS,
    MAX_BATCH_CHANGES,
    MAX_PULL_LIMIT,
    MAX_REQUEST_BYTES,
    VALID_OPERATIONS,
    VERSION_POLICY_PATH_ENV,
    VERSION_UPGRADE_GATE,
    AppConfig,
    VersionPolicySource,
    VersionUpgradeGate,
    env_int,
    header_value,
    non_empty_string,
    parse_semver,
)
from handlers import (
    CLOUD_SYNC_ENTITLEMENT_TIMEOUT_ENV,
    CLOUD_SYNC_ENTITLEMENT_URL_ENV,
    SERVICE_INTERNAL_TOKEN_ENV,
    SyncApp,
    SyncHttpServer,
    SyncRequestHandler,
    build_sync_entitlement_resolver_from_env,
    build_server_from_env,
    normalize_payload_json,
    parse_change,
    parse_changes_body,
    parse_query_int,
    reject_batch_too_large,
    require_int,
    require_text,
    sync_app_env,
    sync_entitlement_denied_error,
)
from common.entitlement_model import EntitlementAuthContext, EntitlementDecision, EntitlementTier, PaidEntitlementState
from common.entitlement_resolver import EntitlementResolver, HttpPaidEntitlementStateProvider, paid_state_from_response
from http_helpers import (
    LOGGER,
    HttpError,
    configure_logging,
    duration_ms_since,
    error_response,
    json_response,
    log_internal_error,
    log_sync_event,
    read_json_body,
    request_id_from_headers,
    utc_now_iso,
)
from rate_limit import SlidingWindowRateLimiter
from storage import IncomingChange, SyncStore, change_row_to_json

__all__ = [
    "AppConfig",
    "Authenticator",
    "CLOUD_SYNC_ENTITLEMENT_TIMEOUT_ENV",
    "CLOUD_SYNC_ENTITLEMENT_URL_ENV",
    "DEFAULT_PORT",
    "DEFAULT_PULL_LIMIT",
    "DEFAULT_RATE_LIMIT_MAX_REQUESTS",
    "DEFAULT_RATE_LIMIT_WINDOW_SECONDS",
    "EntitlementAuthContext",
    "EntitlementDecision",
    "EntitlementResolver",
    "EntitlementTier",
    "HttpError",
    "HttpTokenIntrospector",
    "HttpPaidEntitlementStateProvider",
    "IncomingChange",
    "LOGGER",
    "MAX_BATCH_CHANGES",
    "MAX_PULL_LIMIT",
    "MAX_REQUEST_BYTES",
    "SlidingWindowRateLimiter",
    "SyncApp",
    "SyncHttpServer",
    "SyncRequestHandler",
    "SyncStore",
    "VALID_OPERATIONS",
    "VERSION_POLICY_PATH_ENV",
    "VERSION_UPGRADE_GATE",
    "VersionPolicySource",
    "VersionUpgradeGate",
    "audience_matches",
    "base64url_decode",
    "base64url_encode",
    "build_server_from_env",
    "change_row_to_json",
    "configure_logging",
    "duration_ms_since",
    "env_int",
    "error_response",
    "extract_account_id",
    "header_value",
    "json_response",
    "log_internal_error",
    "log_sync_event",
    "main",
    "non_empty_string",
    "normalize_payload_json",
    "parse_change",
    "parse_changes_body",
    "parse_query_int",
    "parse_semver",
    "paid_state_from_response",
    "read_json_body",
    "reject_batch_too_large",
    "request_id_from_headers",
    "require_int",
    "require_text",
    "sync_app_env",
    "sync_entitlement_denied_error",
    "utc_now_iso",
]


def main() -> None:
    configure_logging()
    server = build_server_from_env()
    host, port = server.server_address
    print(f"FleetLedger cloud sync backend listening on {host}:{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
    "PaidEntitlementState",
    "SERVICE_INTERNAL_TOKEN_ENV",
    "build_sync_entitlement_resolver_from_env",
