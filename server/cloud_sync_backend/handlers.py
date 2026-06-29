from __future__ import annotations

import http.server
import json
import os
import sys
import time
import urllib.parse
from pathlib import Path
from typing import Any, Dict, List, Mapping, Optional

_SERVER_ROOT = Path(__file__).resolve().parents[1]
if str(_SERVER_ROOT) not in sys.path:
    sys.path.insert(0, str(_SERVER_ROOT))

from auth import Authenticator
from config import DEFAULT_PULL_LIMIT, MAX_BATCH_CHANGES, MAX_PULL_LIMIT, MAX_REQUEST_BYTES, VALID_OPERATIONS, AppConfig, VERSION_UPGRADE_GATE
from common.entitlement_model import EntitlementAuthContext, EntitlementDecision, EntitlementSourceUnavailable, PaidEntitlementState
from common.entitlement_policy_engine import LOCAL_ENVS
from common.entitlement_resolver import EntitlementResolver, HttpPaidEntitlementStateProvider
from http_helpers import HttpError, duration_ms_since, error_response, json_response, log_internal_error, log_sync_event, read_json_body, request_id_from_headers
from rate_limit import SlidingWindowRateLimiter
from storage import IncomingChange, SyncStore

SERVICE_INTERNAL_TOKEN_ENV = "SERVICE_INTERNAL_TOKEN"
CLOUD_SYNC_ENTITLEMENT_URL_ENV = "CLOUD_SYNC_ENTITLEMENT_URL"
CLOUD_SYNC_ENTITLEMENT_TIMEOUT_ENV = "CLOUD_SYNC_ENTITLEMENT_TIMEOUT_SECONDS"


class SyncApp:
    def __init__(
        self,
        store: SyncStore,
        authenticator: Authenticator,
        max_request_bytes: int = MAX_REQUEST_BYTES,
        default_pull_limit: int = DEFAULT_PULL_LIMIT,
        max_pull_limit: int = MAX_PULL_LIMIT,
        rate_limiter: Optional[SlidingWindowRateLimiter] = None,
        entitlement_resolver: Optional[EntitlementResolver] = None,
        app_env: Optional[str] = None,
    ):
        self.store = store
        self.authenticator = authenticator
        self.max_request_bytes = max_request_bytes
        self.default_pull_limit = default_pull_limit
        self.max_pull_limit = max_pull_limit
        self.rate_limiter = rate_limiter or SlidingWindowRateLimiter()
        self.entitlement_resolver = entitlement_resolver or EntitlementResolver(
            default_paid_state=PaidEntitlementState.ACTIVE,
        )
        self.app_env = app_env or sync_app_env()

    @classmethod
    def from_env(cls) -> "SyncApp":
        config = AppConfig.from_env()
        return cls(
            store=SyncStore(config.database_path),
            authenticator=Authenticator.from_env(),
            max_request_bytes=config.max_request_bytes,
            default_pull_limit=config.default_pull_limit,
            max_pull_limit=config.max_pull_limit,
            rate_limiter=SlidingWindowRateLimiter(
                max_requests=config.rate_limit_max_requests,
                window_seconds=config.rate_limit_window_seconds,
            ),
            entitlement_resolver=build_sync_entitlement_resolver_from_env(),
            app_env=sync_app_env(),
        )

    def authenticate(self, handler: http.server.BaseHTTPRequestHandler) -> str:
        return self.authenticator.authenticate(handler.headers.get("authorization"))

    def check_rate_limit(self, account_id: Optional[str]) -> None:
        self.rate_limiter.check(account_id)

    def require_sync_entitlement(self, account_id: str, operation: str) -> EntitlementDecision:
        context = EntitlementAuthContext(
            is_dev=self.app_env in LOCAL_ENVS,
            operation=operation,
        )
        try:
            decision = self.entitlement_resolver.resolve(
                context,
                request_type="sync",
                user_id=account_id,
                env=self.app_env,
            )
        except EntitlementSourceUnavailable as exc:
            raise HttpError(
                503,
                "sync_entitlement_unavailable",
                "Sync entitlement verification is currently unavailable.",
            ) from exc
        if not decision.allow:
            raise sync_entitlement_denied_error(decision)
        return decision

    def push_changes(self, account_id: str, body: Mapping[str, Any]) -> Dict[str, Any]:
        started = time.monotonic()
        accepted = 0
        conflicts = 0
        status = "ok"
        try:
            changes = parse_changes_body(body)
            result = self.store.push_changes(account_id, changes)
            accepted = len(result["accepted"])
            conflicts = len(result["conflicts"])
            return result
        except Exception:
            status = "error"
            raise
        finally:
            log_sync_event(
                {
                    "account_id": account_id,
                    "op": "push",
                    "accepted": accepted,
                    "conflicts": conflicts,
                    "duration_ms": duration_ms_since(started),
                    "status": status,
                }
            )

    def pull_changes(self, account_id: str, query: Mapping[str, List[str]]) -> Dict[str, Any]:
        started = time.monotonic()
        since = 0
        next_cursor = 0
        returned = 0
        status = "ok"
        try:
            since = parse_query_int(query, "since", 0, minimum=0)
            next_cursor = since
            limit = parse_query_int(query, "limit", self.default_pull_limit, minimum=1)
            limit = min(limit, self.max_pull_limit)
            result = self.store.pull_changes(account_id, since, limit)
            returned = len(result["changes"])
            next_cursor = int(result["next_cursor"])
            return result
        except Exception:
            status = "error"
            raise
        finally:
            log_sync_event(
                {
                    "account_id": account_id,
                    "op": "pull",
                    "applied": 0,
                    "returned": returned,
                    "since": since,
                    "next_cursor": next_cursor,
                    "duration_ms": duration_ms_since(started),
                    "status": status,
                }
            )

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


def reject_batch_too_large(body: Mapping[str, Any]) -> None:
    raw_changes = body.get("changes")
    if isinstance(raw_changes, list) and len(raw_changes) > MAX_BATCH_CHANGES:
        raise HttpError(413, "batch_too_large", "too many changes in one request")


def parse_change(raw: Mapping[str, Any], index: int, default_device_id: Any = None) -> IncomingChange:
    entity_type = require_text(raw.get("entity_type"), f"changes[{index}].entity_type", max_length=128)
    entity_id = require_text(raw.get("entity_id"), f"changes[{index}].entity_id", max_length=256)
    operation = require_text(raw.get("op"), f"changes[{index}].op", max_length=16)
    if operation not in VALID_OPERATIONS:
        raise HttpError(400, "invalid_change", f"changes[{index}].op is invalid")
    base_version = require_int(raw.get("base_version"), f"changes[{index}].base_version", minimum=0)
    payload_field = "payload_json" if "payload_json" in raw else "payload"
    payload_json = normalize_payload_json(raw.get(payload_field), f"changes[{index}].{payload_field}")
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
    # INVARIANT: payload_hash is the client's hash over the exact bytes the
    # client serialized. The server stores payload_hash verbatim (push_changes
    # never recomputes it), and clients do not re-verify the hash against pulled
    # payload_json. So the dict/list branch below MAY emit different bytes
    # (sort_keys re-serialization) than the client hashed -- that is safe ONLY
    # while no side recomputes the hash over payload_json. Before adding any such
    # verification, make client and server serialization byte-identical, or have
    # the client send payload_json as the exact string it hashed.
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

            account_id = self.app.authenticate(self)
            if method == "POST" and path == "/sync/changes":
                body = read_json_body(self, self.app.max_request_bytes)
                reject_batch_too_large(body)
                self.app.require_sync_entitlement(account_id, "write")
                self.app.check_rate_limit(account_id)
                json_response(self, 200, self.app.push_changes(account_id, body))
                return
            if method == "GET" and path == "/sync/changes":
                self.app.require_sync_entitlement(account_id, "read")
                self.app.check_rate_limit(account_id)
                query = urllib.parse.parse_qs(parsed.query, keep_blank_values=True)
                json_response(self, 200, self.app.pull_changes(account_id, query))
                return
            if method == "POST" and path == "/sync/devices":
                body = read_json_body(self, self.app.max_request_bytes)
                self.app.require_sync_entitlement(account_id, "write")
                self.app.check_rate_limit(account_id)
                json_response(self, 200, self.app.register_device(account_id, body))
                return
            raise HttpError(404, "not_found", "endpoint not found")
        except HttpError as exc:
            error_response(self, exc)
        except Exception:
            log_internal_error(request_id, method, path)
            error_response(self, HttpError(500, "internal_error", "internal server error"))


class SyncHttpServer(http.server.ThreadingHTTPServer):
    def __init__(self, server_address: tuple[str, int], app: SyncApp):
        super().__init__(server_address, SyncRequestHandler)
        self.app = app


def build_server_from_env() -> SyncHttpServer:
    config = AppConfig.from_env()
    return SyncHttpServer((config.host, config.port), SyncApp.from_env())


def sync_entitlement_denied_error(decision: EntitlementDecision) -> HttpError:
    if decision.reason == "paid_grace_read_only":
        return HttpError(
            403,
            "sync_read_only",
            "Sync access is read-only during grace period.",
        )
    return HttpError(
        403,
        "sync_entitlement_required",
        "Cloud sync requires an active subscription.",
    )


def build_sync_entitlement_resolver_from_env() -> EntitlementResolver:
    app_env = sync_app_env()
    url = os.environ.get(CLOUD_SYNC_ENTITLEMENT_URL_ENV, "").strip()
    if not url:
        if app_env in LOCAL_ENVS:
            return EntitlementResolver(default_paid_state=PaidEntitlementState.ACTIVE)
        return EntitlementResolver()
    provider = HttpPaidEntitlementStateProvider(
        url,
        service_internal_token=os.environ.get(SERVICE_INTERNAL_TOKEN_ENV, "").strip(),
        required_plans={"sync": "paid"},
        timeout_seconds=_env_int(CLOUD_SYNC_ENTITLEMENT_TIMEOUT_ENV, 5),
    )
    return EntitlementResolver(paid_state_provider=provider)


def sync_app_env() -> str:
    return (
        os.environ.get("APP_ENV", "").strip()
        or os.environ.get("FLEET_APP_ENV", "").strip()
        or "production"
    ).lower()


def _env_int(name: str, default: int, *, minimum: int = 1) -> int:
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
