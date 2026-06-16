#!/usr/bin/env python3
"""FleetLedger cloud sync backend.

Minimal production path:
  Flutter App -> HTTPS /sync/changes -> this service -> SQLite change log

This service is intentionally independent from server/cloud_backup_backend/.
It shares the same app-login bearer-token trust model, but does not call the
backup service and does not expose any object-storage credentials to clients.
"""

from __future__ import annotations

import base64
import dataclasses
import datetime as dt
import hashlib
import hmac
import http.server
import json
import os
import sqlite3
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Callable, Dict, List, Mapping, Optional


DEFAULT_PORT = 8009
MAX_REQUEST_BYTES = 4 * 1024 * 1024
MAX_BATCH_CHANGES = 100
DEFAULT_PULL_LIMIT = 100
MAX_PULL_LIMIT = 500
VALID_OPERATIONS = {"create", "update", "delete"}


class HttpError(Exception):
    def __init__(self, status: int, code: str, message: str):
        super().__init__(message)
        self.status = status
        self.code = code
        self.message = message


def json_response(handler: http.server.BaseHTTPRequestHandler, status: int, body: Mapping[str, Any]) -> None:
    payload = json.dumps(body, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    handler.send_response(status)
    handler.send_header("content-type", "application/json; charset=utf-8")
    handler.send_header("content-length", str(len(payload)))
    handler.end_headers()
    handler.wfile.write(payload)


def error_response(handler: http.server.BaseHTTPRequestHandler, error: HttpError) -> None:
    json_response(
        handler,
        error.status,
        {"error": {"code": error.code, "message": error.message}},
    )


def read_json_body(handler: http.server.BaseHTTPRequestHandler, max_bytes: int) -> Dict[str, Any]:
    raw_length = handler.headers.get("content-length")
    if not raw_length:
        raise HttpError(411, "content_length_required", "Content-Length is required")
    try:
        length = int(raw_length)
    except ValueError as exc:
        raise HttpError(400, "invalid_content_length", "Content-Length is invalid") from exc
    if length < 0:
        raise HttpError(400, "invalid_content_length", "Content-Length is invalid")
    if length > max_bytes:
        raise HttpError(413, "request_too_large", "request body exceeds allowed size")
    body = handler.rfile.read(length)
    if len(body) > max_bytes:
        raise HttpError(413, "request_too_large", "request body exceeds allowed size")
    try:
        decoded = json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise HttpError(400, "invalid_json", "request body must be valid JSON") from exc
    if not isinstance(decoded, dict):
        raise HttpError(400, "invalid_json", "request body must be a JSON object")
    return decoded


def base64url_decode(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode((value + padding).encode("ascii"))


def base64url_encode(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode("ascii").rstrip("=")


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


class Authenticator:
    """Validates app bearer tokens and returns the account id.

    The sync service intentionally reuses the cloud-backup auth environment
    names so operators can point both services at the same app-login token
    issuer. Production should use HS256 JWT validation or HTTPS token
    introspection. Dev tokens are for local smoke tests only.
    """

    def __init__(
        self,
        hs256_secret: Optional[str] = None,
        introspector: Optional[Callable[[str], str]] = None,
        dev_tokens: Optional[Mapping[str, str]] = None,
        jwt_issuer: Optional[str] = None,
        jwt_audience: Optional[str] = None,
        leeway_seconds: int = 60,
    ):
        self.hs256_secret = hs256_secret
        self.introspector = introspector
        self.dev_tokens = dict(dev_tokens or {})
        self.jwt_issuer = jwt_issuer
        self.jwt_audience = jwt_audience
        self.leeway_seconds = leeway_seconds
        if not self.hs256_secret and not self.introspector and not self.dev_tokens:
            raise ValueError(
                "Configure FLEET_BACKUP_AUTH_HS256_SECRET, "
                "FLEET_BACKUP_AUTH_INTROSPECTION_URL, or "
                "FLEET_BACKUP_DEV_TOKENS_JSON; cloud sync must not run "
                "without authentication."
            )

    @classmethod
    def from_env(cls) -> "Authenticator":
        raw_dev_tokens = (
            os.environ.get("FLEET_SYNC_DEV_TOKENS_JSON", "").strip()
            or os.environ.get("FLEET_BACKUP_DEV_TOKENS_JSON", "").strip()
        )
        dev_tokens: Dict[str, str] = {}
        if raw_dev_tokens:
            decoded = json.loads(raw_dev_tokens)
            if not isinstance(decoded, dict):
                raise ValueError("FLEET_BACKUP_DEV_TOKENS_JSON must be an object")
            dev_tokens = {str(token): str(account_id) for token, account_id in decoded.items()}
        secret = (
            os.environ.get("FLEET_BACKUP_AUTH_HS256_SECRET", "").strip()
            or os.environ.get("FLEET_SYNC_AUTH_HS256_SECRET", "").strip()
            or None
        )
        introspection_url = (
            os.environ.get("FLEET_BACKUP_AUTH_INTROSPECTION_URL", "").strip()
            or os.environ.get("FLEET_SYNC_AUTH_INTROSPECTION_URL", "").strip()
        )
        bearer_token = (
            os.environ.get("FLEET_BACKUP_AUTH_INTROSPECTION_BEARER_TOKEN", "").strip()
            or os.environ.get("FLEET_SYNC_AUTH_INTROSPECTION_BEARER_TOKEN", "").strip()
            or None
        )
        introspector = None
        if introspection_url:
            introspector = HttpTokenIntrospector(introspection_url, bearer_token=bearer_token)
        return cls(
            hs256_secret=secret,
            introspector=introspector,
            dev_tokens=dev_tokens,
            jwt_issuer=os.environ.get("FLEET_BACKUP_AUTH_JWT_ISSUER", "").strip()
            or os.environ.get("FLEET_SYNC_AUTH_JWT_ISSUER", "").strip()
            or None,
            jwt_audience=os.environ.get("FLEET_BACKUP_AUTH_JWT_AUDIENCE", "").strip()
            or os.environ.get("FLEET_SYNC_AUTH_JWT_AUDIENCE", "").strip()
            or None,
        )

    def authenticate(self, authorization_header: Optional[str]) -> str:
        if not authorization_header or not authorization_header.startswith("Bearer "):
            raise HttpError(401, "unauthorized", "Bearer token is required")
        token = authorization_header[len("Bearer ") :].strip()
        if not token:
            raise HttpError(401, "unauthorized", "Bearer token is required")
        if token in self.dev_tokens:
            return self.dev_tokens[token]
        if self.hs256_secret and len(token.split(".")) == 3:
            try:
                return self._authenticate_hs256_jwt(token)
            except HttpError:
                if self.introspector is None:
                    raise
        if self.introspector is not None:
            return self.introspector(token)
        if self.hs256_secret:
            return self._authenticate_hs256_jwt(token)
        raise HttpError(401, "unauthorized", "token is not accepted")

    def _authenticate_hs256_jwt(self, token: str) -> str:
        parts = token.split(".")
        if len(parts) != 3:
            raise HttpError(401, "invalid_token", "token must be an HS256 JWT")
        try:
            header_bytes = base64url_decode(parts[0])
            payload_bytes = base64url_decode(parts[1])
            signature = base64url_decode(parts[2])
            header = json.loads(header_bytes.decode("utf-8"))
            payload = json.loads(payload_bytes.decode("utf-8"))
        except (ValueError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise HttpError(401, "invalid_token", "token payload is invalid") from exc
        if header.get("alg") != "HS256":
            raise HttpError(401, "invalid_token", "token alg must be HS256")
        signing_input = f"{parts[0]}.{parts[1]}".encode("ascii")
        expected = hmac.new(
            self.hs256_secret.encode("utf-8"),
            signing_input,
            hashlib.sha256,
        ).digest()
        if not hmac.compare_digest(signature, expected):
            raise HttpError(401, "invalid_token", "token signature is invalid")
        now = int(time.time())
        exp = payload.get("exp")
        if isinstance(exp, int) and exp + self.leeway_seconds < now:
            raise HttpError(401, "token_expired", "token is expired")
        if self.jwt_issuer is not None and payload.get("iss") != self.jwt_issuer:
            raise HttpError(401, "invalid_token", "token issuer is invalid")
        if self.jwt_audience is not None and not audience_matches(payload.get("aud"), self.jwt_audience):
            raise HttpError(401, "invalid_token", "token audience is invalid")
        account_id = payload.get("sub") or payload.get("user_id") or payload.get("phone")
        if not isinstance(account_id, str) or not account_id.strip():
            raise HttpError(401, "invalid_token", "token is missing account id")
        return account_id.strip()


class HttpTokenIntrospector:
    """Validates opaque login tokens through the account service."""

    def __init__(self, url: str, bearer_token: Optional[str] = None, timeout: int = 5):
        if not url.startswith("https://"):
            raise ValueError("FLEET_BACKUP_AUTH_INTROSPECTION_URL must be https")
        self.url = url
        self.bearer_token = bearer_token
        self.timeout = timeout

    def __call__(self, token: str) -> str:
        body = json.dumps({"token": token}, separators=(",", ":")).encode("utf-8")
        request = urllib.request.Request(
            self.url,
            data=body,
            method="POST",
            headers={
                "Accept": "application/json",
                "Content-Type": "application/json",
            },
        )
        if self.bearer_token:
            request.add_header("Authorization", f"Bearer {self.bearer_token}")
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                raw = response.read()
        except urllib.error.HTTPError as exc:
            if exc.code in (401, 403):
                raise HttpError(401, "invalid_token", "token is not accepted") from exc
            raise HttpError(503, "auth_service_unavailable", "auth service is temporarily unavailable") from exc
        except urllib.error.URLError as exc:
            raise HttpError(503, "auth_service_unavailable", "auth service is temporarily unavailable") from exc
        try:
            decoded = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise HttpError(503, "auth_service_unavailable", "auth service returned invalid JSON") from exc
        if not isinstance(decoded, dict):
            raise HttpError(503, "auth_service_unavailable", "auth service response must be an object")
        active = decoded.get("active")
        ok = decoded.get("ok")
        if active is False or ok is False:
            raise HttpError(401, "invalid_token", "token is not accepted")
        if active is not True and ok is not True:
            raise HttpError(401, "invalid_token", "auth service did not accept token")
        account_id = extract_account_id(decoded)
        if account_id is None:
            raise HttpError(401, "invalid_token", "auth service response is missing account id")
        return account_id


def audience_matches(raw_audience: Any, expected: str) -> bool:
    if isinstance(raw_audience, str):
        return raw_audience == expected
    if isinstance(raw_audience, list):
        return expected in [value for value in raw_audience if isinstance(value, str)]
    return False


def extract_account_id(body: Mapping[str, Any]) -> Optional[str]:
    for key in ("sub", "user_id", "phone"):
        value = body.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    user = body.get("user")
    if isinstance(user, Mapping):
        for key in ("id", "user_id", "phone"):
            value = user.get(key)
            if isinstance(value, str) and value.strip():
                return value.strip()
    return None


@dataclasses.dataclass(frozen=True)
class IncomingChange:
    entity_type: str
    entity_id: str
    operation: str
    base_version: int
    payload_json: str
    payload_hash: str
    origin_device_id: Optional[str] = None

    @property
    def deleted(self) -> int:
        return 1 if self.operation == "delete" else 0

    @property
    def entity(self) -> Dict[str, str]:
        return {"entity_type": self.entity_type, "entity_id": self.entity_id}


class SyncStore:
    def __init__(self, db_path: str):
        self.db_path = db_path
        parent = os.path.dirname(os.path.abspath(db_path))
        if parent:
            os.makedirs(parent, exist_ok=True)
        self._init_schema()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_schema(self) -> None:
        with self._connect() as conn:
            conn.execute("PRAGMA foreign_keys = ON")
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS sync_changes (
                  account_id TEXT NOT NULL,
                  server_seq INTEGER NOT NULL,
                  entity_type TEXT NOT NULL,
                  entity_id TEXT NOT NULL,
                  base_version INTEGER NOT NULL,
                  new_version INTEGER NOT NULL,
                  payload_json TEXT NOT NULL,
                  payload_hash TEXT NOT NULL,
                  deleted INTEGER NOT NULL,
                  origin_device_id TEXT,
                  server_ts TEXT NOT NULL,
                  PRIMARY KEY(account_id, server_seq)
                )
                """
            )
            conn.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_sync_changes_entity_head
                ON sync_changes(account_id, entity_type, entity_id, new_version DESC)
                """
            )
            conn.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_sync_changes_pull
                ON sync_changes(account_id, server_seq)
                """
            )
            conn.execute(
                """
                CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_changes_idempotency
                ON sync_changes(account_id, entity_type, entity_id, payload_hash)
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS sync_devices (
                  account_id TEXT NOT NULL,
                  device_id TEXT NOT NULL,
                  name TEXT NOT NULL,
                  last_seen TEXT NOT NULL,
                  PRIMARY KEY(account_id, device_id)
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS sync_entity_heads (
                  account_id TEXT NOT NULL,
                  entity_type TEXT NOT NULL,
                  entity_id TEXT NOT NULL,
                  version INTEGER NOT NULL,
                  deleted INTEGER NOT NULL,
                  payload_hash TEXT NOT NULL,
                  server_seq INTEGER NOT NULL,
                  updated_at TEXT NOT NULL,
                  PRIMARY KEY(account_id, entity_type, entity_id),
                  FOREIGN KEY(account_id, server_seq)
                    REFERENCES sync_changes(account_id, server_seq)
                )
                """
            )
            conn.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_sync_entity_heads_account
                ON sync_entity_heads(account_id, entity_type, entity_id)
                """
            )

    def push_changes(self, account_id: str, changes: List[IncomingChange]) -> Dict[str, List[Dict[str, Any]]]:
        accepted: List[Dict[str, Any]] = []
        conflicts: List[Dict[str, Any]] = []
        conn = self._connect()
        try:
            conn.execute("PRAGMA foreign_keys = ON")
            conn.execute("BEGIN IMMEDIATE")
            for change in changes:
                existing = conn.execute(
                    """
                    SELECT server_seq, new_version
                    FROM sync_changes
                    WHERE account_id = ?
                      AND entity_type = ?
                      AND entity_id = ?
                      AND payload_hash = ?
                    """,
                    (account_id, change.entity_type, change.entity_id, change.payload_hash),
                ).fetchone()
                if existing is not None:
                    accepted.append(
                        {
                            "entity": change.entity,
                            "server_seq": int(existing["server_seq"]),
                            "new_version": int(existing["new_version"]),
                        }
                    )
                    continue

                head = conn.execute(
                    """
                    SELECT version
                    FROM sync_entity_heads
                    WHERE account_id = ? AND entity_type = ? AND entity_id = ?
                    """,
                    (account_id, change.entity_type, change.entity_id),
                ).fetchone()
                current_version = int(head["version"]) if head is not None else 0
                if change.base_version != current_version:
                    conflicts.append(
                        {
                            "entity": change.entity,
                            "server_version": current_version,
                        }
                    )
                    continue

                server_seq = int(
                    conn.execute(
                        "SELECT COALESCE(MAX(server_seq), 0) + 1 AS next_seq FROM sync_changes WHERE account_id = ?",
                        (account_id,),
                    ).fetchone()["next_seq"]
                )
                new_version = current_version + 1
                server_ts = utc_now_iso()
                conn.execute(
                    """
                    INSERT INTO sync_changes (
                      account_id, server_seq, entity_type, entity_id, base_version,
                      new_version, payload_json, payload_hash, deleted,
                      origin_device_id, server_ts
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        account_id,
                        server_seq,
                        change.entity_type,
                        change.entity_id,
                        change.base_version,
                        new_version,
                        change.payload_json,
                        change.payload_hash,
                        change.deleted,
                        change.origin_device_id,
                        server_ts,
                    ),
                )
                conn.execute(
                    """
                    INSERT INTO sync_entity_heads (
                      account_id, entity_type, entity_id, version, deleted,
                      payload_hash, server_seq, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(account_id, entity_type, entity_id) DO UPDATE SET
                      version = excluded.version,
                      deleted = excluded.deleted,
                      payload_hash = excluded.payload_hash,
                      server_seq = excluded.server_seq,
                      updated_at = excluded.updated_at
                    """,
                    (
                        account_id,
                        change.entity_type,
                        change.entity_id,
                        new_version,
                        change.deleted,
                        change.payload_hash,
                        server_seq,
                        server_ts,
                    ),
                )
                accepted.append(
                    {
                        "entity": change.entity,
                        "server_seq": server_seq,
                        "new_version": new_version,
                    }
                )
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
        return {"accepted": accepted, "conflicts": conflicts}

    def pull_changes(self, account_id: str, since: int, limit: int) -> Dict[str, Any]:
        with self._connect() as conn:
            rows = conn.execute(
                """
                SELECT *
                FROM sync_changes
                WHERE account_id = ? AND server_seq > ?
                ORDER BY server_seq ASC
                LIMIT ?
                """,
                (account_id, since, limit),
            ).fetchall()
        changes = [change_row_to_json(row) for row in rows]
        next_cursor = max((int(row["server_seq"]) for row in rows), default=since)
        return {"changes": changes, "next_cursor": next_cursor}

    def register_device(self, account_id: str, device_id: str, name: str) -> Dict[str, str]:
        last_seen = utc_now_iso()
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO sync_devices (account_id, device_id, name, last_seen)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(account_id, device_id) DO UPDATE SET
                  name = excluded.name,
                  last_seen = excluded.last_seen
                """,
                (account_id, device_id, name, last_seen),
            )
        return {"device_id": device_id, "name": name, "last_seen": last_seen}

    def get_head(self, account_id: str, entity_type: str, entity_id: str) -> Optional[Dict[str, Any]]:
        with self._connect() as conn:
            row = conn.execute(
                """
                SELECT *
                FROM sync_entity_heads
                WHERE account_id = ? AND entity_type = ? AND entity_id = ?
                """,
                (account_id, entity_type, entity_id),
            ).fetchone()
        return dict(row) if row is not None else None

    def get_device(self, account_id: str, device_id: str) -> Optional[Dict[str, Any]]:
        with self._connect() as conn:
            row = conn.execute(
                """
                SELECT *
                FROM sync_devices
                WHERE account_id = ? AND device_id = ?
                """,
                (account_id, device_id),
            ).fetchone()
        return dict(row) if row is not None else None

    def count_changes(self, account_id: str) -> int:
        with self._connect() as conn:
            row = conn.execute(
                "SELECT COUNT(*) AS count FROM sync_changes WHERE account_id = ?",
                (account_id,),
            ).fetchone()
        return int(row["count"])


def change_row_to_json(row: sqlite3.Row) -> Dict[str, Any]:
    return {
        "server_seq": int(row["server_seq"]),
        "entity_type": row["entity_type"],
        "entity_id": row["entity_id"],
        "base_version": int(row["base_version"]),
        "new_version": int(row["new_version"]),
        "payload_json": row["payload_json"],
        "payload_hash": row["payload_hash"],
        "deleted": bool(row["deleted"]),
        "origin_device_id": row["origin_device_id"],
        "server_ts": row["server_ts"],
    }


@dataclasses.dataclass(frozen=True)
class AppConfig:
    host: str
    port: int
    database_path: str
    max_request_bytes: int
    default_pull_limit: int
    max_pull_limit: int

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
        )


class SyncApp:
    def __init__(
        self,
        store: SyncStore,
        authenticator: Authenticator,
        max_request_bytes: int = MAX_REQUEST_BYTES,
        default_pull_limit: int = DEFAULT_PULL_LIMIT,
        max_pull_limit: int = MAX_PULL_LIMIT,
    ):
        self.store = store
        self.authenticator = authenticator
        self.max_request_bytes = max_request_bytes
        self.default_pull_limit = default_pull_limit
        self.max_pull_limit = max_pull_limit

    @classmethod
    def from_env(cls) -> "SyncApp":
        config = AppConfig.from_env()
        return cls(
            store=SyncStore(config.database_path),
            authenticator=Authenticator.from_env(),
            max_request_bytes=config.max_request_bytes,
            default_pull_limit=config.default_pull_limit,
            max_pull_limit=config.max_pull_limit,
        )

    def authenticate(self, handler: http.server.BaseHTTPRequestHandler) -> str:
        return self.authenticator.authenticate(handler.headers.get("authorization"))

    def push_changes(self, account_id: str, body: Mapping[str, Any]) -> Dict[str, Any]:
        changes = parse_changes_body(body)
        return self.store.push_changes(account_id, changes)

    def pull_changes(self, account_id: str, query: Mapping[str, List[str]]) -> Dict[str, Any]:
        since = parse_query_int(query, "since", 0, minimum=0)
        limit = parse_query_int(query, "limit", self.default_pull_limit, minimum=1)
        limit = min(limit, self.max_pull_limit)
        return self.store.pull_changes(account_id, since, limit)

    def register_device(self, account_id: str, body: Mapping[str, Any]) -> Dict[str, str]:
        device_id = require_text(body.get("device_id"), "device_id", max_length=128)
        name = require_text(body.get("name"), "name", max_length=128)
        return self.store.register_device(account_id, device_id, name)


def parse_changes_body(body: Mapping[str, Any]) -> List[IncomingChange]:
    raw_changes = body.get("changes")
    if not isinstance(raw_changes, list):
        raise HttpError(400, "invalid_request", "changes must be an array")
    if len(raw_changes) > MAX_BATCH_CHANGES:
        raise HttpError(413, "batch_too_large", "too many changes in one request")
    changes = []
    for index, raw in enumerate(raw_changes):
        if not isinstance(raw, dict):
            raise HttpError(400, "invalid_change", f"changes[{index}] must be an object")
        changes.append(parse_change(raw, index, body.get("device_id")))
    return changes


def parse_change(raw: Mapping[str, Any], index: int, default_device_id: Any = None) -> IncomingChange:
    entity_type = require_text(raw.get("entity_type"), f"changes[{index}].entity_type", max_length=128)
    entity_id = require_text(raw.get("entity_id"), f"changes[{index}].entity_id", max_length=256)
    operation = require_text(raw.get("op"), f"changes[{index}].op", max_length=16)
    if operation not in VALID_OPERATIONS:
        raise HttpError(400, "invalid_change", f"changes[{index}].op is invalid")
    base_version = require_int(raw.get("base_version"), f"changes[{index}].base_version", minimum=0)
    payload_json = normalize_payload_json(raw.get("payload_json"), f"changes[{index}].payload_json")
    payload_hash = require_text(raw.get("payload_hash"), f"changes[{index}].payload_hash", max_length=256)
    origin_device_id = raw.get("origin_device_id", default_device_id)
    if origin_device_id is not None:
        origin_device_id = require_text(origin_device_id, f"changes[{index}].origin_device_id", max_length=128)
    return IncomingChange(
        entity_type=entity_type,
        entity_id=entity_id,
        operation=operation,
        base_version=base_version,
        payload_json=payload_json,
        payload_hash=payload_hash,
        origin_device_id=origin_device_id,
    )


def require_text(value: Any, name: str, *, max_length: int) -> str:
    if not isinstance(value, str) or not value.strip():
        raise HttpError(400, "invalid_request", f"{name} is required")
    result = value.strip()
    if len(result) > max_length:
        raise HttpError(400, "invalid_request", f"{name} is too long")
    return result


def require_int(value: Any, name: str, *, minimum: int) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        raise HttpError(400, "invalid_request", f"{name} must be an integer")
    if value < minimum:
        raise HttpError(400, "invalid_request", f"{name} must be >= {minimum}")
    return value


def normalize_payload_json(value: Any, name: str) -> str:
    if isinstance(value, str):
        if not value:
            raise HttpError(400, "invalid_request", f"{name} is required")
        try:
            json.loads(value)
        except json.JSONDecodeError as exc:
            raise HttpError(400, "invalid_payload_json", f"{name} must be valid JSON") from exc
        return value
    if isinstance(value, (dict, list)):
        return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    raise HttpError(400, "invalid_request", f"{name} is required")


def parse_query_int(query: Mapping[str, List[str]], key: str, default: int, *, minimum: int) -> int:
    values = query.get(key)
    if not values:
        return default
    try:
        value = int(values[-1])
    except ValueError as exc:
        raise HttpError(400, "invalid_query", f"{key} must be an integer") from exc
    if value < minimum:
        raise HttpError(400, "invalid_query", f"{key} must be >= {minimum}")
    return value


def utc_now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


class SyncRequestHandler(http.server.BaseHTTPRequestHandler):
    server_version = "FleetLedgerCloudSync/1.0"

    def do_GET(self) -> None:
        self._handle("GET")

    def do_POST(self) -> None:
        self._handle("POST")

    def log_message(self, format: str, *args: Any) -> None:
        print(
            "%s - - [%s] %s"
            % (self.address_string(), self.log_date_time_string(), format % args),
            flush=True,
        )

    @property
    def app(self) -> SyncApp:
        return self.server.app  # type: ignore[attr-defined]

    def _handle(self, method: str) -> None:
        try:
            parsed = urllib.parse.urlparse(self.path)
            path = parsed.path.rstrip("/") or "/"
            if method == "GET" and path == "/healthz":
                json_response(self, 200, {"ok": True})
                return

            account_id = self.app.authenticate(self)
            if method == "POST" and path == "/sync/changes":
                body = read_json_body(self, self.app.max_request_bytes)
                json_response(self, 200, self.app.push_changes(account_id, body))
                return
            if method == "GET" and path == "/sync/changes":
                query = urllib.parse.parse_qs(parsed.query, keep_blank_values=True)
                json_response(self, 200, self.app.pull_changes(account_id, query))
                return
            if method == "POST" and path == "/sync/devices":
                body = read_json_body(self, self.app.max_request_bytes)
                json_response(self, 200, self.app.register_device(account_id, body))
                return
            raise HttpError(404, "not_found", "endpoint not found")
        except HttpError as exc:
            error_response(self, exc)
        except Exception:
            print("internal_error while handling cloud sync request", flush=True)
            error_response(self, HttpError(500, "internal_error", "internal server error"))


class SyncHttpServer(http.server.ThreadingHTTPServer):
    def __init__(self, server_address: tuple[str, int], app: SyncApp):
        super().__init__(server_address, SyncRequestHandler)
        self.app = app


def build_server_from_env() -> SyncHttpServer:
    config = AppConfig.from_env()
    return SyncHttpServer((config.host, config.port), SyncApp.from_env())


def main() -> None:
    server = build_server_from_env()
    host, port = server.server_address
    print(f"FleetLedger cloud sync backend listening on {host}:{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
