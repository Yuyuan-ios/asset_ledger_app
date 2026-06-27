from __future__ import annotations

import dataclasses
import json
import os
from typing import Any, Dict, Mapping, Optional


MAX_PAYLOAD_BYTES = 64 * 1024 * 1024
MAX_REQUEST_BYTES = 80 * 1024 * 1024
DEFAULT_PORT = 8008
SUPPORTED_FORMAT_VERSION = 1
KIND_VALUE = "cloud_backup"
ENCODING_PLAINTEXT = "plaintext"
ENCODING_AES_GCM = "aes-256-gcm"
VERSION_POLICY_PATH_ENV = "FLEET_BACKUP_VERSION_POLICY_PATH"
EXTERNAL_CLIENT_TOKEN_REQUIRED = False


def _env_name(*parts: str) -> str:
    return "".join(parts)


DEPRECATED_ENV_REPLACEMENTS = {
    _env_name("FLEET", "_BACKUP", "_AUTH", "_HS256", "_SECRET"): "USER_AUTH_HS256_SECRET",
    _env_name("FLEET", "_BACKUP", "_AUTH", "_JWT", "_ISSUER"): "USER_AUTH_JWT_ISSUER",
    _env_name("FLEET", "_BACKUP", "_AUTH", "_JWT", "_AUDIENCE"): "USER_AUTH_JWT_AUDIENCE",
    _env_name("FLEET", "_BACKUP", "_AUTH", "_INTROSPECTION", "_URL"): "USER_AUTH_INTROSPECTION_URL",
    _env_name("FLEET", "_BACKUP", "_AUTH", "_INTROSPECTION", "_BEARER", "_TOKEN"): "USER_AUTH_INTROSPECTION_SERVICE_TOKEN",
    _env_name("FLEET", "_BACKUP", "_ENTITLEMENT", "_VERIFICATION", "_URL"): "CLOUD_BACKUP_ENTITLEMENT_URL",
    _env_name("CLOUD", "_BACKUP", "_ENTITLEMENT", "_TOKEN"): "SERVICE_INTERNAL_TOKEN",
    _env_name("FLEET", "_BACKUP", "_ENTITLEMENT", "_BEARER", "_TOKEN"): "SERVICE_INTERNAL_TOKEN",
    _env_name("FLEET", "_BACKUP", "_ENTITLEMENT", "_TIMEOUT", "_SECONDS"): "CLOUD_BACKUP_ENTITLEMENT_TIMEOUT_SECONDS",
    _env_name("FLEET", "_BACKUP", "_MAX", "_ENTITLED", "_USERS", "_JSON"): "CLOUD_BACKUP_MAX_ENTITLED_USERS_JSON",
}
ENCRYPTION_META_FIELDS = (
    "algo",
    "kdf",
    "salt",
    "nonce",
    "key_id",
    "plaintext_sha256",
    "plaintext_bytes",
)


class ConfigMigrationError(RuntimeError):
    pass


def assert_no_deprecated_env_keys() -> None:
    configured = [
        name
        for name in sorted(DEPRECATED_ENV_REPLACEMENTS)
        if os.environ.get(name, "").strip()
    ]
    if not configured:
        return
    replacements = ", ".join(
        f"{name} -> {DEPRECATED_ENV_REPLACEMENTS[name]}" for name in configured
    )
    raise ConfigMigrationError(
        "Deprecated environment key(s) are not supported. "
        f"Migrate before startup: {replacements}"
    )


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


def non_empty_string(value: Any) -> Optional[str]:
    if not isinstance(value, str):
        return None
    stripped = value.strip()
    return stripped or None


def parse_semver(value: Any) -> Optional[tuple[int, int, int]]:
    raw = non_empty_string(value)
    if raw is None:
        return None
    core = raw.split("+", 1)[0].split("-", 1)[0]
    parts = core.split(".")
    if len(parts) != 3:
        return None
    if any(not part.isdigit() for part in parts):
        return None
    return (int(parts[0]), int(parts[1]), int(parts[2]))


def header_value(headers: Mapping[str, Any], name: str) -> Optional[str]:
    raw = headers.get(name)
    if raw is None:
        raw = headers.get(name.lower())
    if raw is None:
        target = name.lower()
        for key, value in headers.items():
            if str(key).lower() == target:
                raw = value
                break
    return non_empty_string(raw)


class VersionPolicySource:
    def __init__(self, env_name: str):
        self.env_name = env_name
        self._cached_path: Optional[str] = None
        self._cached_mtime: Optional[float] = None
        self._cached_policy: Optional[Dict[str, Any]] = None

    def load_policy(self) -> Optional[Dict[str, Any]]:
        path = non_empty_string(os.environ.get(self.env_name))
        if path is None:
            return None

        try:
            mtime = os.path.getmtime(path)
        except OSError:
            return None

        if self._cached_path == path and self._cached_mtime == mtime:
            return self._cached_policy

        try:
            with open(path, "r", encoding="utf-8") as policy_file:
                decoded = json.load(policy_file)
        except (OSError, json.JSONDecodeError, UnicodeDecodeError):
            decoded = None

        policy = decoded if isinstance(decoded, dict) else None
        self._cached_path = path
        self._cached_mtime = mtime
        self._cached_policy = policy
        return policy


class VersionUpgradeGate:
    def __init__(self, policy_source: VersionPolicySource):
        self.policy_source = policy_source

    def enforce(self, headers: Mapping[str, Any]) -> Optional[Dict[str, Any]]:
        current_version = header_value(headers, "X-App-Version")
        platform = header_value(headers, "X-Platform")
        if current_version is None or platform is None:
            return None

        policy = self.policy_source.load_policy()
        platform_policy = policy.get(platform) if isinstance(policy, dict) else None
        if not isinstance(platform_policy, dict):
            return None

        min_version = non_empty_string(platform_policy.get("minSupportedVersion"))
        current_semver = parse_semver(current_version)
        min_semver = parse_semver(min_version)
        if current_semver is None or min_semver is None:
            return None

        if current_semver >= min_semver:
            return None

        # The server does not know Android channel here, so 426 returns the
        # platform landing URL; channel-specific store URL selection stays client-side.
        return {
            "code": "upgrade_required",
            "updateUrl": non_empty_string(platform_policy.get("updateUrl")) or "",
            "title": non_empty_string(platform_policy.get("title")),
            "content": non_empty_string(platform_policy.get("content")),
        }


VERSION_UPGRADE_GATE = VersionUpgradeGate(VersionPolicySource(VERSION_POLICY_PATH_ENV))


@dataclasses.dataclass(frozen=True)
class AppConfig:
    host: str
    port: int
    database_path: str
    storage_mode: str
    file_storage_dir: str
    oss_endpoint: str
    oss_bucket: str
    oss_access_key_id: str
    oss_access_key_secret: str
    oss_prefix: str
    account_key_secret: str = ""
    max_payload_bytes: int = MAX_PAYLOAD_BYTES
    max_request_bytes: int = MAX_REQUEST_BYTES

    @classmethod
    def from_env(cls) -> "AppConfig":
        assert_no_deprecated_env_keys()
        max_payload_bytes = env_int("FLEET_BACKUP_MAX_PAYLOAD_BYTES", MAX_PAYLOAD_BYTES)
        max_request_bytes = env_int("FLEET_BACKUP_MAX_REQUEST_BYTES", MAX_REQUEST_BYTES)
        if max_request_bytes < max_payload_bytes:
            raise ValueError(
                "FLEET_BACKUP_MAX_REQUEST_BYTES must be greater than or equal to "
                "FLEET_BACKUP_MAX_PAYLOAD_BYTES"
            )
        return cls(
            host=os.environ.get("FLEET_BACKUP_HOST", "127.0.0.1"),
            port=env_int("FLEET_BACKUP_PORT", DEFAULT_PORT),
            database_path=os.environ.get("FLEET_BACKUP_DB_PATH", "./data/backups.sqlite3"),
            storage_mode=os.environ.get("FLEET_BACKUP_STORAGE", "oss").strip().lower(),
            file_storage_dir=os.environ.get("FLEET_BACKUP_FILE_STORAGE_DIR", "./data/objects"),
            oss_endpoint=os.environ.get("ALIYUN_OSS_ENDPOINT", "").strip(),
            oss_bucket=os.environ.get("ALIYUN_OSS_BUCKET", "").strip(),
            oss_access_key_id=(
                os.environ.get("ALIBABA_CLOUD_ACCESS_KEY_ID", "").strip()
                or os.environ.get("ALIYUN_ACCESS_KEY_ID", "").strip()
            ),
            oss_access_key_secret=(
                os.environ.get("ALIBABA_CLOUD_ACCESS_KEY_SECRET", "").strip()
                or os.environ.get("ALIYUN_ACCESS_KEY_SECRET", "").strip()
            ),
            oss_prefix=os.environ.get("ALIYUN_OSS_PREFIX", "fleet-ledger/backups").strip("/"),
            account_key_secret=os.environ.get("FLEET_BACKUP_ACCOUNT_KEY_SECRET", "").strip(),
            max_payload_bytes=max_payload_bytes,
            max_request_bytes=max_request_bytes,
        )
