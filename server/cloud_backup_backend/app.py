#!/usr/bin/env python3
"""FleetLedger cloud backup backend bootstrap and compatibility facade.

Minimal production path:
  Flutter App -> HTTPS /v1/backups -> this service -> private Aliyun OSS bucket

The service keeps backup metadata in SQLite and stores the full cloud backup
envelope as a private OSS object. It intentionally has no third-party runtime
dependencies so it can run on a small ECS or lightweight application server.
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
    extract_user_id,
)
from common.auth_identity.auth_planes import AuthPlane
from common.auth_identity.resolver import (
    AccountIdentityResolver,
    SecurityViolation,
    require_stable_user_id,
)
from config import (
    EXTERNAL_CLIENT_TOKEN_REQUIRED,
    DEFAULT_PORT,
    ENCODING_AES_GCM,
    ENCODING_PLAINTEXT,
    ENCRYPTION_META_FIELDS,
    KIND_VALUE,
    MAX_PAYLOAD_BYTES,
    MAX_REQUEST_BYTES,
    SUPPORTED_FORMAT_VERSION,
    VERSION_POLICY_PATH_ENV,
    VERSION_UPGRADE_GATE,
    AppConfig,
    ConfigMigrationError,
    VersionPolicySource,
    VersionUpgradeGate,
    env_int,
    header_value,
    non_empty_string,
    parse_semver,
)
from handlers import (
    BackupApp,
    BackupHttpServer,
    BackupRequestHandler,
    build_server_from_env,
    is_plain_int,
    is_sha256_hex,
    validate_envelope,
)
from entitlements import (
    CLOUD_BACKUP_REQUIRES_MAX_CODE,
    CLOUD_BACKUP_REQUIRES_MAX_MESSAGE,
    SUBSCRIPTION_VERIFICATION_UNAVAILABLE_CODE,
    SUBSCRIPTION_VERIFICATION_UNAVAILABLE_MESSAGE,
    CloudBackupEntitlementVerifier,
    FailClosedCloudBackupEntitlementVerifier,
    HttpCloudBackupEntitlementVerifier,
    StaticMaxUserEntitlementVerifier,
    build_cloud_backup_entitlement_verifier_from_env,
    cloud_backup_requires_max_error,
    subscription_verification_unavailable_error,
)
from http_helpers import (
    LOGGER,
    HttpError,
    configure_logging,
    duration_ms_since,
    error_response,
    json_response,
    log_backup_event,
    log_internal_error,
    read_json_body,
    request_id_from_headers,
)
from object_store import AliyunOssObjectStore, FileObjectStore, StorageError
from rate_limit import SlidingWindowRateLimiter
from storage import BackupMetadata, BackupMetadataStore, ClosingSQLiteConnection, metadata_from_row

__all__ = [
    "AliyunOssObjectStore",
    "AppConfig",
    "AccountIdentityResolver",
    "AuthPlane",
    "Authenticator",
    "BackupApp",
    "BackupHttpServer",
    "BackupMetadata",
    "BackupMetadataStore",
    "BackupRequestHandler",
    "ClosingSQLiteConnection",
    "CLOUD_BACKUP_REQUIRES_MAX_CODE",
    "CLOUD_BACKUP_REQUIRES_MAX_MESSAGE",
    "CloudBackupEntitlementVerifier",
    "DEFAULT_PORT",
    "ENCODING_AES_GCM",
    "ENCODING_PLAINTEXT",
    "ENCRYPTION_META_FIELDS",
    "FailClosedCloudBackupEntitlementVerifier",
    "FileObjectStore",
    "HttpCloudBackupEntitlementVerifier",
    "HttpError",
    "HttpTokenIntrospector",
    "KIND_VALUE",
    "LOGGER",
    "MAX_PAYLOAD_BYTES",
    "MAX_REQUEST_BYTES",
    "SUPPORTED_FORMAT_VERSION",
    "SlidingWindowRateLimiter",
    "StaticMaxUserEntitlementVerifier",
    "StorageError",
    "SUBSCRIPTION_VERIFICATION_UNAVAILABLE_CODE",
    "SUBSCRIPTION_VERIFICATION_UNAVAILABLE_MESSAGE",
    "VERSION_POLICY_PATH_ENV",
    "VERSION_UPGRADE_GATE",
    "VersionPolicySource",
    "VersionUpgradeGate",
    "ConfigMigrationError",
    "EXTERNAL_CLIENT_TOKEN_REQUIRED",
    "SecurityViolation",
    "audience_matches",
    "base64url_decode",
    "base64url_encode",
    "build_cloud_backup_entitlement_verifier_from_env",
    "build_server_from_env",
    "cloud_backup_requires_max_error",
    "configure_logging",
    "duration_ms_since",
    "env_int",
    "error_response",
    "extract_user_id",
    "header_value",
    "is_plain_int",
    "is_sha256_hex",
    "json_response",
    "log_backup_event",
    "log_internal_error",
    "main",
    "metadata_from_row",
    "non_empty_string",
    "parse_semver",
    "read_json_body",
    "request_id_from_headers",
    "require_stable_user_id",
    "subscription_verification_unavailable_error",
    "validate_envelope",
]


def main() -> None:
    configure_logging()
    server = build_server_from_env()
    host, port = server.server_address
    print(f"FleetLedger cloud backup backend listening on {host}:{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
