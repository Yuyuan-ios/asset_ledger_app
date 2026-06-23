from __future__ import annotations

import dataclasses
import json
import os
from typing import Any, Dict, Mapping, Optional


DEFAULT_PORT = 8009
MAX_REQUEST_BYTES = 4 * 1024 * 1024
MAX_BATCH_CHANGES = 100
DEFAULT_PULL_LIMIT = 100
MAX_PULL_LIMIT = 500
DEFAULT_RATE_LIMIT_MAX_REQUESTS = 120
DEFAULT_RATE_LIMIT_WINDOW_SECONDS = 60
VALID_OPERATIONS = {"create", "update", "delete"}
VERSION_POLICY_PATH_ENV = "FLEET_SYNC_VERSION_POLICY_PATH"


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
    max_request_bytes: int
    default_pull_limit: int
    max_pull_limit: int
    rate_limit_max_requests: int
    rate_limit_window_seconds: int

    @classmethod
    def from_env(cls) -> "AppConfig":
        default_pull_limit = env_int("FLEET_SYNC_DEFAULT_PULL_LIMIT", DEFAULT_PULL_LIMIT)
        max_pull_limit = env_int("FLEET_SYNC_MAX_PULL_LIMIT", MAX_PULL_LIMIT)
        if default_pull_limit > max_pull_limit:
            raise ValueError("FLEET_SYNC_DEFAULT_PULL_LIMIT must be <= FLEET_SYNC_MAX_PULL_LIMIT")
        return cls(
            host=os.environ.get("FLEET_SYNC_HOST", "127.0.0.1"),
            port=env_int("FLEET_SYNC_PORT", DEFAULT_PORT),
            database_path=os.environ.get("FLEET_SYNC_DB_PATH", "./data/sync.sqlite3"),
            max_request_bytes=env_int("FLEET_SYNC_MAX_REQUEST_BYTES", MAX_REQUEST_BYTES),
            default_pull_limit=default_pull_limit,
            max_pull_limit=max_pull_limit,
            rate_limit_max_requests=env_int(
                "FLEET_SYNC_RATE_LIMIT_MAX_REQUESTS",
                DEFAULT_RATE_LIMIT_MAX_REQUESTS,
            ),
            rate_limit_window_seconds=env_int(
                "FLEET_SYNC_RATE_LIMIT_WINDOW_SECONDS",
                DEFAULT_RATE_LIMIT_WINDOW_SECONDS,
            ),
        )
