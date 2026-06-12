#!/usr/bin/env python3
"""FleetLedger cloud backup backend.

Minimal production path:
  Flutter App -> HTTPS /v1/backups -> this service -> private Aliyun OSS bucket

The service keeps backup metadata in SQLite and stores the full cloud backup
envelope as a private OSS object. It intentionally has no third-party runtime
dependencies so it can run on a small ECS or lightweight application server.
"""

from __future__ import annotations

import base64
import dataclasses
import datetime as dt
import email.utils
import hashlib
import hmac
import http.server
import json
import os
import sqlite3
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from typing import Any, Callable, Dict, Iterable, List, Mapping, Optional


MAX_PAYLOAD_BYTES = 64 * 1024 * 1024
MAX_REQUEST_BYTES = 80 * 1024 * 1024
DEFAULT_PORT = 8008
SUPPORTED_FORMAT_VERSION = 1
KIND_VALUE = "cloud_backup"


class HttpError(Exception):
    def __init__(self, status: int, code: str, message: str):
        super().__init__(message)
        self.status = status
        self.code = code
        self.message = message


class StorageError(Exception):
    pass


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
    """Validates app bearer tokens and returns a stable user id.

    Production can either validate HS256 JWTs issued by the account service, or
    call the account service's token introspection endpoint for opaque tokens.
    For a short smoke test, FLEET_BACKUP_DEV_TOKENS_JSON can map opaque tokens
    to user ids.
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
                "FLEET_BACKUP_DEV_TOKENS_JSON; cloud backup must not run "
                "without authentication."
            )

    @classmethod
    def from_env(cls) -> "Authenticator":
        raw_dev_tokens = os.environ.get("FLEET_BACKUP_DEV_TOKENS_JSON", "").strip()
        dev_tokens: Dict[str, str] = {}
        if raw_dev_tokens:
            decoded = json.loads(raw_dev_tokens)
            if not isinstance(decoded, dict):
                raise ValueError("FLEET_BACKUP_DEV_TOKENS_JSON must be an object")
            dev_tokens = {str(token): str(user_id) for token, user_id in decoded.items()}
        secret = os.environ.get("FLEET_BACKUP_AUTH_HS256_SECRET", "").strip() or None
        introspection_url = os.environ.get("FLEET_BACKUP_AUTH_INTROSPECTION_URL", "").strip()
        introspector = None
        if introspection_url:
            introspector = HttpTokenIntrospector(
                introspection_url,
                bearer_token=os.environ.get(
                    "FLEET_BACKUP_AUTH_INTROSPECTION_BEARER_TOKEN",
                    "",
                ).strip()
                or None,
            )
        return cls(
            hs256_secret=secret,
            introspector=introspector,
            dev_tokens=dev_tokens,
            jwt_issuer=os.environ.get("FLEET_BACKUP_AUTH_JWT_ISSUER", "").strip() or None,
            jwt_audience=os.environ.get("FLEET_BACKUP_AUTH_JWT_AUDIENCE", "").strip() or None,
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
        if self.jwt_audience is not None and not audience_matches(
            payload.get("aud"),
            self.jwt_audience,
        ):
            raise HttpError(401, "invalid_token", "token audience is invalid")
        user_id = payload.get("sub") or payload.get("user_id") or payload.get("phone")
        if not isinstance(user_id, str) or not user_id.strip():
            raise HttpError(401, "invalid_token", "token is missing user id")
        return user_id.strip()


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
            raise HttpError(
                503,
                "auth_service_unavailable",
                "auth service is temporarily unavailable",
            ) from exc
        except urllib.error.URLError as exc:
            raise HttpError(
                503,
                "auth_service_unavailable",
                "auth service is temporarily unavailable",
            ) from exc
        try:
            decoded = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise HttpError(
                503,
                "auth_service_unavailable",
                "auth service returned invalid JSON",
            ) from exc
        if not isinstance(decoded, dict):
            raise HttpError(503, "auth_service_unavailable", "auth service response must be an object")
        active = decoded.get("active")
        ok = decoded.get("ok")
        if active is False or ok is False:
            raise HttpError(401, "invalid_token", "token is not accepted")
        if active is not True and ok is not True:
            raise HttpError(401, "invalid_token", "auth service did not accept token")
        user_id = extract_user_id(decoded)
        if user_id is None:
            raise HttpError(401, "invalid_token", "auth service response is missing user id")
        return user_id


def audience_matches(raw_audience: Any, expected: str) -> bool:
    if isinstance(raw_audience, str):
        return raw_audience == expected
    if isinstance(raw_audience, list):
        return expected in [value for value in raw_audience if isinstance(value, str)]
    return False


def extract_user_id(body: Mapping[str, Any]) -> Optional[str]:
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


class SlidingWindowRateLimiter:
    def __init__(self, max_requests: int = 120, window_seconds: int = 60):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._lock = threading.Lock()
        self._requests: Dict[str, List[float]] = {}

    def check(self, user_id: str) -> None:
        now = time.time()
        cutoff = now - self.window_seconds
        with self._lock:
            recent = [value for value in self._requests.get(user_id, []) if value >= cutoff]
            if len(recent) >= self.max_requests:
                self._requests[user_id] = recent
                raise HttpError(429, "rate_limited", "too many backup requests")
            recent.append(now)
            self._requests[user_id] = recent


@dataclasses.dataclass(frozen=True)
class BackupMetadata:
    backup_id: str
    user_id: str
    object_key: str
    db_schema_version: int
    payload_sha256: str
    payload_bytes: int
    created_at: str

    def public_json(self) -> Dict[str, Any]:
        return {
            "backup_id": self.backup_id,
            "created_at": self.created_at,
            "db_schema_version": self.db_schema_version,
            "payload_bytes": self.payload_bytes,
        }


class BackupMetadataStore:
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
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS backups (
                  backup_id TEXT PRIMARY KEY,
                  user_id TEXT NOT NULL,
                  object_key TEXT NOT NULL,
                  db_schema_version INTEGER NOT NULL,
                  payload_sha256 TEXT NOT NULL,
                  payload_bytes INTEGER NOT NULL,
                  created_at TEXT NOT NULL
                )
                """
            )
            conn.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_backups_user_created
                ON backups(user_id, created_at DESC)
                """
            )
            conn.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_backups_user_id
                ON backups(user_id)
                """
            )
            conn.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_backups_created_at
                ON backups(created_at DESC)
                """
            )

    def insert(self, metadata: BackupMetadata) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO backups (
                  backup_id, user_id, object_key, db_schema_version,
                  payload_sha256, payload_bytes, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    metadata.backup_id,
                    metadata.user_id,
                    metadata.object_key,
                    metadata.db_schema_version,
                    metadata.payload_sha256,
                    metadata.payload_bytes,
                    metadata.created_at,
                ),
            )

    def list_for_user(self, user_id: str) -> List[BackupMetadata]:
        with self._connect() as conn:
            rows = conn.execute(
                """
                SELECT * FROM backups
                WHERE user_id = ?
                ORDER BY created_at DESC, backup_id DESC
                """,
                (user_id,),
            ).fetchall()
        return [metadata_from_row(row) for row in rows]

    def get_for_user(self, user_id: str, backup_id: str) -> BackupMetadata:
        with self._connect() as conn:
            row = conn.execute(
                "SELECT * FROM backups WHERE user_id = ? AND backup_id = ?",
                (user_id, backup_id),
            ).fetchone()
        if row is None:
            raise HttpError(404, "not_found", "backup not found")
        return metadata_from_row(row)


def metadata_from_row(row: sqlite3.Row) -> BackupMetadata:
    return BackupMetadata(
        backup_id=row["backup_id"],
        user_id=row["user_id"],
        object_key=row["object_key"],
        db_schema_version=int(row["db_schema_version"]),
        payload_sha256=row["payload_sha256"],
        payload_bytes=int(row["payload_bytes"]),
        created_at=row["created_at"],
    )


class FileObjectStore:
    """Local object store used by tests and one-machine smoke runs."""

    def __init__(self, root_dir: str):
        self.root_dir = root_dir
        os.makedirs(root_dir, exist_ok=True)

    def put_text(self, key: str, body: str, content_type: str = "application/json") -> None:
        path = self._path_for_key(key)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as file:
            file.write(body)

    def get_text(self, key: str) -> str:
        try:
            with open(self._path_for_key(key), "r", encoding="utf-8") as file:
                return file.read()
        except FileNotFoundError as exc:
            raise HttpError(404, "not_found", "backup object not found") from exc

    def delete_text(self, key: str) -> None:
        try:
            os.remove(self._path_for_key(key))
        except FileNotFoundError:
            return

    def _path_for_key(self, key: str) -> str:
        normalized = os.path.normpath(key).replace("\\", "/")
        if normalized.startswith("../") or normalized == ".." or normalized.startswith("/"):
            raise StorageError("invalid object key")
        return os.path.join(self.root_dir, normalized)


class AliyunOssObjectStore:
    """Tiny OSS REST client using Aliyun OSS Signature V1."""

    def __init__(self, endpoint: str, bucket: str, access_key_id: str, access_key_secret: str):
        if not endpoint or not bucket or not access_key_id or not access_key_secret:
            raise ValueError("OSS endpoint, bucket, access key id, and secret are required")
        self.bucket = bucket
        self.access_key_id = access_key_id
        self.access_key_secret = access_key_secret.encode("utf-8")
        self.scheme, self.host = self._resolve_host(endpoint, bucket)

    @staticmethod
    def _resolve_host(endpoint: str, bucket: str) -> tuple[str, str]:
        raw = endpoint.strip().rstrip("/")
        if "://" not in raw:
            raw = "https://" + raw
        parsed = urllib.parse.urlparse(raw)
        scheme = parsed.scheme or "https"
        host = parsed.netloc or parsed.path
        if not host.startswith(f"{bucket}."):
            host = f"{bucket}.{host}"
        return scheme, host

    def put_text(self, key: str, body: str, content_type: str = "application/json") -> None:
        self._request("PUT", key, body.encode("utf-8"), content_type=content_type)

    def get_text(self, key: str) -> str:
        return self._request("GET", key, None, content_type="").decode("utf-8")

    def delete_text(self, key: str) -> None:
        self._request("DELETE", key, None, content_type="")

    def _request(self, method: str, key: str, body: Optional[bytes], content_type: str) -> bytes:
        safe_key = urllib.parse.quote(key, safe="/")
        url = f"{self.scheme}://{self.host}/{safe_key}"
        date_header = email.utils.formatdate(usegmt=True)
        canonical_resource = f"/{self.bucket}/{key}"
        string_to_sign = f"{method}\n\n{content_type}\n{date_header}\n{canonical_resource}"
        digest = hmac.new(self.access_key_secret, string_to_sign.encode("utf-8"), hashlib.sha1).digest()
        signature = base64.b64encode(digest).decode("ascii")
        headers = {
            "Date": date_header,
            "Host": self.host,
            "Authorization": f"OSS {self.access_key_id}:{signature}",
        }
        if content_type:
            headers["Content-Type"] = content_type
        request = urllib.request.Request(url, data=body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.read()
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise StorageError(f"OSS {method} failed: {exc.code} {detail}") from exc
        except urllib.error.URLError as exc:
            raise StorageError(f"OSS {method} failed: {exc}") from exc


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
    max_payload_bytes: int = MAX_PAYLOAD_BYTES
    max_request_bytes: int = MAX_REQUEST_BYTES

    @classmethod
    def from_env(cls) -> "AppConfig":
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
            max_payload_bytes=max_payload_bytes,
            max_request_bytes=max_request_bytes,
        )


class BackupApp:
    def __init__(
        self,
        metadata_store: BackupMetadataStore,
        object_store: Any,
        authenticator: Authenticator,
        rate_limiter: Optional[SlidingWindowRateLimiter] = None,
        oss_prefix: str = "fleet-ledger/backups",
        max_payload_bytes: int = MAX_PAYLOAD_BYTES,
        max_request_bytes: int = MAX_REQUEST_BYTES,
    ):
        self.metadata_store = metadata_store
        self.object_store = object_store
        self.authenticator = authenticator
        self.rate_limiter = rate_limiter or SlidingWindowRateLimiter()
        self.oss_prefix = oss_prefix.strip("/")
        self.max_payload_bytes = max_payload_bytes
        self.max_request_bytes = max_request_bytes

    @classmethod
    def from_env(cls) -> "BackupApp":
        config = AppConfig.from_env()
        store = BackupMetadataStore(config.database_path)
        if config.storage_mode == "file":
            object_store = FileObjectStore(config.file_storage_dir)
        elif config.storage_mode == "oss":
            object_store = AliyunOssObjectStore(
                endpoint=config.oss_endpoint,
                bucket=config.oss_bucket,
                access_key_id=config.oss_access_key_id,
                access_key_secret=config.oss_access_key_secret,
            )
        else:
            raise ValueError("FLEET_BACKUP_STORAGE must be 'oss' or 'file'")
        return cls(
            metadata_store=store,
            object_store=object_store,
            authenticator=Authenticator.from_env(),
            oss_prefix=config.oss_prefix,
            max_payload_bytes=config.max_payload_bytes,
            max_request_bytes=config.max_request_bytes,
        )

    def authenticate(self, handler: http.server.BaseHTTPRequestHandler) -> str:
        user_id = self.authenticator.authenticate(handler.headers.get("authorization"))
        self.rate_limiter.check(user_id)
        return user_id

    def create_backup(self, user_id: str, envelope: Mapping[str, Any]) -> str:
        validated = validate_envelope(envelope, self.max_payload_bytes)
        backup_id = str(uuid.uuid4())
        object_key = self._object_key(user_id, backup_id)
        body = json.dumps(validated, ensure_ascii=False, separators=(",", ":"))
        try:
            self.object_store.put_text(object_key, body)
        except StorageError as exc:
            raise HttpError(502, "storage_error", "backup object storage failed") from exc
        metadata = BackupMetadata(
            backup_id=backup_id,
            user_id=user_id,
            object_key=object_key,
            db_schema_version=int(validated["db_schema_version"]),
            payload_sha256=str(validated["payload_sha256"]),
            payload_bytes=int(validated["payload_bytes"]),
            created_at=str(validated["created_at"]),
        )
        try:
            self.metadata_store.insert(metadata)
        except Exception as exc:
            self._cleanup_object_after_metadata_failure(object_key)
            raise HttpError(
                500,
                "metadata_write_failed",
                "backup metadata write failed",
            ) from exc
        return backup_id

    def list_backups(self, user_id: str) -> List[Dict[str, Any]]:
        return [metadata.public_json() for metadata in self.metadata_store.list_for_user(user_id)]

    def download_backup(self, user_id: str, backup_id: str) -> Dict[str, Any]:
        metadata = self.metadata_store.get_for_user(user_id, backup_id)
        try:
            raw = self.object_store.get_text(metadata.object_key)
        except StorageError as exc:
            raise HttpError(502, "storage_error", "backup object storage failed") from exc
        try:
            decoded = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise HttpError(502, "storage_corrupt", "stored backup object is invalid JSON") from exc
        if not isinstance(decoded, dict):
            raise HttpError(502, "storage_corrupt", "stored backup object must be a JSON object")
        return validate_envelope(decoded, self.max_payload_bytes)

    def _object_key(self, user_id: str, backup_id: str) -> str:
        user_hash = hashlib.sha256(user_id.encode("utf-8")).hexdigest()[:32]
        prefix = f"{self.oss_prefix}/" if self.oss_prefix else ""
        return f"{prefix}{user_hash}/{backup_id}.json"

    def _cleanup_object_after_metadata_failure(self, object_key: str) -> None:
        delete_text = getattr(self.object_store, "delete_text", None)
        if not callable(delete_text):
            return
        try:
            delete_text(object_key)
        except Exception:
            # Fail closed to the client. Operators can reconcile orphan objects
            # by scanning for objects without metadata; do not leak object keys.
            return


def validate_envelope(envelope: Mapping[str, Any], max_payload_bytes: int) -> Dict[str, Any]:
    if envelope.get("kind") != KIND_VALUE:
        raise HttpError(400, "invalid_envelope", "kind must be cloud_backup")
    format_version = envelope.get("format_version")
    if not is_plain_int(format_version) or format_version != SUPPORTED_FORMAT_VERSION:
        raise HttpError(400, "unsupported_format_version", "cloud backup format is not supported")
    payload_json = envelope.get("payload_json")
    payload_sha256 = envelope.get("payload_sha256")
    payload_bytes = envelope.get("payload_bytes")
    db_schema_version = envelope.get("db_schema_version")
    created_at = envelope.get("created_at")
    if not isinstance(payload_json, str) or not payload_json:
        raise HttpError(400, "invalid_envelope", "payload_json is required")
    if not isinstance(payload_sha256, str) or not is_sha256_hex(payload_sha256):
        raise HttpError(400, "invalid_envelope", "payload_sha256 must be a sha256 hex string")
    if not is_plain_int(payload_bytes):
        raise HttpError(400, "invalid_envelope", "payload_bytes is required")
    if not is_plain_int(db_schema_version):
        raise HttpError(400, "invalid_envelope", "db_schema_version is required")
    if db_schema_version <= 0 or db_schema_version > 100000:
        raise HttpError(400, "invalid_envelope", "db_schema_version is outside the allowed range")
    if not isinstance(created_at, str) or not created_at:
        raise HttpError(400, "invalid_envelope", "created_at is required")
    actual_bytes = len(payload_json.encode("utf-8"))
    if actual_bytes > max_payload_bytes:
        raise HttpError(413, "payload_too_large", "backup payload exceeds allowed size")
    if payload_bytes != actual_bytes:
        raise HttpError(400, "payload_size_mismatch", "payload_bytes does not match payload_json")
    actual_sha = hashlib.sha256(payload_json.encode("utf-8")).hexdigest()
    if actual_sha != payload_sha256.lower():
        raise HttpError(400, "payload_hash_mismatch", "payload_sha256 does not match payload_json")
    try:
        decoded_payload = json.loads(payload_json)
    except json.JSONDecodeError as exc:
        raise HttpError(400, "invalid_payload_json", "payload_json must be valid JSON") from exc
    if not isinstance(decoded_payload, dict):
        raise HttpError(400, "invalid_payload_json", "payload_json must be a JSON object")
    return {
        "kind": KIND_VALUE,
        "format_version": SUPPORTED_FORMAT_VERSION,
        "created_at": created_at,
        "db_schema_version": db_schema_version,
        "payload_sha256": payload_sha256.lower(),
        "payload_bytes": payload_bytes,
        "payload_json": payload_json,
    }


def is_plain_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def is_sha256_hex(value: str) -> bool:
    if len(value) != 64:
        return False
    return all(char in "0123456789abcdefABCDEF" for char in value)


class BackupRequestHandler(http.server.BaseHTTPRequestHandler):
    server_version = "FleetLedgerCloudBackup/1.0"

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
    def app(self) -> BackupApp:
        return self.server.app  # type: ignore[attr-defined]

    def _handle(self, method: str) -> None:
        try:
            parsed = urllib.parse.urlparse(self.path)
            path = parsed.path.rstrip("/") or "/"
            if method == "GET" and path == "/healthz":
                json_response(self, 200, {"ok": True})
                return
            user_id = self.app.authenticate(self)
            if method == "POST" and path == "/v1/backups":
                envelope = read_json_body(self, self.app.max_request_bytes)
                backup_id = self.app.create_backup(user_id, envelope)
                json_response(self, 200, {"backup_id": backup_id})
                return
            if method == "GET" and path == "/v1/backups":
                json_response(self, 200, {"backups": self.app.list_backups(user_id)})
                return
            if method == "GET" and path.startswith("/v1/backups/"):
                backup_id = urllib.parse.unquote(path[len("/v1/backups/") :])
                if not backup_id:
                    raise HttpError(404, "not_found", "backup not found")
                json_response(self, 200, self.app.download_backup(user_id, backup_id))
                return
            raise HttpError(404, "not_found", "endpoint not found")
        except HttpError as exc:
            error_response(self, exc)
        except Exception:
            print("internal_error while handling cloud backup request", flush=True)
            error_response(self, HttpError(500, "internal_error", "internal server error"))


class BackupHttpServer(http.server.ThreadingHTTPServer):
    def __init__(self, server_address: tuple[str, int], app: BackupApp):
        super().__init__(server_address, BackupRequestHandler)
        self.app = app


def build_server_from_env() -> BackupHttpServer:
    config = AppConfig.from_env()
    return BackupHttpServer((config.host, config.port), BackupApp.from_env())


def main() -> None:
    server = build_server_from_env()
    host, port = server.server_address
    print(f"FleetLedger cloud backup backend listening on {host}:{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
