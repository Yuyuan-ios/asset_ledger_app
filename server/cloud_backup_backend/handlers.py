from __future__ import annotations

import hashlib
import hmac
import http.server
import json
import urllib.parse
import uuid
from typing import Any, Dict, List, Mapping, Optional

from auth import Authenticator
from config import ENCODING_AES_GCM, ENCODING_PLAINTEXT, ENCRYPTION_META_FIELDS, KIND_VALUE, MAX_PAYLOAD_BYTES, MAX_REQUEST_BYTES, SUPPORTED_FORMAT_VERSION, VERSION_UPGRADE_GATE, AppConfig
from http_helpers import HttpError, error_response, json_response, log_internal_error, read_json_body, request_id_from_headers
from object_store import AliyunOssObjectStore, FileObjectStore, StorageError
from rate_limit import SlidingWindowRateLimiter
from storage import BackupMetadata, BackupMetadataStore


class BackupApp:
    def __init__(
        self,
        metadata_store: BackupMetadataStore,
        object_store: Any,
        authenticator: Authenticator,
        rate_limiter: Optional[SlidingWindowRateLimiter] = None,
        oss_prefix: str = "fleet-ledger/backups",
        account_key_secret: str = "",
        max_payload_bytes: int = MAX_PAYLOAD_BYTES,
        max_request_bytes: int = MAX_REQUEST_BYTES,
    ):
        self.metadata_store = metadata_store
        self.object_store = object_store
        self.authenticator = authenticator
        self.rate_limiter = rate_limiter or SlidingWindowRateLimiter()
        self.oss_prefix = oss_prefix.strip("/")
        # 客户端加密的账号绑定主密钥(高熵,env 注入)。派生 per-account 备份秘密,
        # 不持久化每用户密钥。未配置则账号密钥下发不可用 → App 生产拒绝上传明文。
        self.account_key_secret = account_key_secret
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
            account_key_secret=config.account_key_secret,
            max_payload_bytes=config.max_payload_bytes,
            max_request_bytes=config.max_request_bytes,
        )

    def authenticate(self, handler: http.server.BaseHTTPRequestHandler) -> str:
        user_id = self.authenticator.authenticate(handler.headers.get("authorization"))
        self.rate_limiter.check(user_id)
        return user_id

    def issue_account_backup_key(self, user_id: str) -> str:
        """派生 per-account 的稳定高熵备份秘密(账号绑定客户端加密的密钥材料)。

        backup_secret = HMAC-SHA256(master_key, "fleet-ledger-backup-key:v1:"+user_id)。
        - 稳定:只依赖 user_id 与主密钥,不随 access token 轮换 → 换机重登可解密旧包。
        - 高熵:256-bit HMAC 输出。
        - 不持久化每用户密钥(只持有一个 env 主密钥)。

        本模型为「账号绑定」(用户已选定):账号服务在信任链内,非完全零知识;
        但 OSS 桶只存密文,桶泄露(无主密钥)不致明文外泄。
        """
        master = self.account_key_secret
        if not master or len(master) < 32:
            raise HttpError(
                503,
                "backup_key_unavailable",
                "account backup key is not configured on the server",
            )
        digest = hmac.new(
            master.encode("utf-8"),
            f"fleet-ledger-backup-key:v1:{user_id}".encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
        return digest

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

    # 客户端加密(账号绑定 AES-256-GCM):payload_json 为 base64 密文,备份存储
    # 路径不解密、不解析为 JSON 对象,仅透传 encryption 元数据。明文备份(缺省/旧包)
    # 仍要求 payload_json 是 JSON 对象,保持原有防御。
    encoding = envelope.get("payload_encoding", ENCODING_PLAINTEXT)
    if encoding not in (ENCODING_PLAINTEXT, ENCODING_AES_GCM):
        raise HttpError(400, "invalid_envelope", "payload_encoding is not supported")

    stored: Dict[str, Any] = {
        "kind": KIND_VALUE,
        "format_version": SUPPORTED_FORMAT_VERSION,
        "created_at": created_at,
        "db_schema_version": db_schema_version,
        "payload_sha256": payload_sha256.lower(),
        "payload_bytes": payload_bytes,
        "payload_encoding": encoding,
        "payload_json": payload_json,
    }

    if encoding == ENCODING_AES_GCM:
        encryption = envelope.get("encryption")
        if not isinstance(encryption, dict):
            raise HttpError(400, "invalid_envelope", "encryption metadata is required")
        for field in ENCRYPTION_META_FIELDS:
            if field not in encryption:
                raise HttpError(400, "invalid_envelope", f"encryption.{field} is required")
        # 透传非秘密元数据;account secret 永不出现在信封或 OSS 对象。
        stored["encryption"] = {
            "algo": str(encryption["algo"]),
            "kdf": str(encryption["kdf"]),
            "salt": str(encryption["salt"]),
            "nonce": str(encryption["nonce"]),
            "key_id": str(encryption["key_id"]),
            "plaintext_sha256": str(encryption["plaintext_sha256"]),
            "plaintext_bytes": encryption["plaintext_bytes"],
        }
    else:
        try:
            decoded_payload = json.loads(payload_json)
        except json.JSONDecodeError as exc:
            raise HttpError(400, "invalid_payload_json", "payload_json must be valid JSON") from exc
        if not isinstance(decoded_payload, dict):
            raise HttpError(400, "invalid_payload_json", "payload_json must be a JSON object")

    return stored


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
        request_id = request_id_from_headers(self.headers)
        path: Optional[str] = None
        try:
            parsed = urllib.parse.urlparse(self.path)
            path = parsed.path.rstrip("/") or "/"
            if method == "GET" and path == "/healthz":
                json_response(self, 200, {"ok": True})
                return
            upgrade_body = VERSION_UPGRADE_GATE.enforce(self.headers)
            if upgrade_body is not None:
                json_response(self, 426, upgrade_body)
                return
            user_id = self.app.authenticate(self)
            if method == "GET" and path == "/v1/account/backup-key":
                json_response(
                    self,
                    200,
                    {"backup_secret": self.app.issue_account_backup_key(user_id)},
                )
                return
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
            log_internal_error(request_id, method, path)
            error_response(self, HttpError(500, "internal_error", "internal server error"))


class BackupHttpServer(http.server.ThreadingHTTPServer):
    def __init__(self, server_address: tuple[str, int], app: BackupApp):
        super().__init__(server_address, BackupRequestHandler)
        self.app = app


def build_server_from_env() -> BackupHttpServer:
    config = AppConfig.from_env()
    return BackupHttpServer((config.host, config.port), BackupApp.from_env())
