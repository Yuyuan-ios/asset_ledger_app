from __future__ import annotations

import http.server
import re
import time
import urllib.parse
from typing import Any, Dict, List, Mapping, Optional

from apple_verifier import build_real_apple_verifier_from_config
from auth import RequestValidator
from config import MAX_REQUEST_BYTES, AppConfig
from http_helpers import (
    HttpError,
    duration_ms_since,
    error_response,
    json_response,
    log_iap_event,
    log_internal_error,
    read_json_body,
    request_id_from_headers,
)
from storage import EntitlementStore
from verifier import (
    AppleServerApiVerifierPlaceholder,
    AppleVerificationFailed,
    AppleVerificationUnavailable,
    AppleVerifier,
    EntitlementRecord,
    no_active_entitlement_record,
    verification_failed_record,
    verification_unavailable_record,
)


APP_ACCOUNT_TOKEN_QUERY_RE = re.compile(r"(?i)(appAccountToken=)[^&\s\"]+")


def redact_app_account_token_values(message: str) -> str:
    return APP_ACCOUNT_TOKEN_QUERY_RE.sub(r"\1<redacted>", message)


class IapVerificationApp:
    def __init__(
        self,
        store: EntitlementStore,
        validator: RequestValidator,
        verifier: AppleVerifier,
        max_request_bytes: int = MAX_REQUEST_BYTES,
    ):
        self.store = store
        self.validator = validator
        self.verifier = verifier
        self.max_request_bytes = max_request_bytes

    @classmethod
    def from_env(cls) -> "IapVerificationApp":
        config = AppConfig.from_env()
        verifier = build_verifier_from_config(config)
        return cls(
            store=EntitlementStore(config.database_path),
            validator=RequestValidator(config.allowed_products, config.allowed_bundle_id),
            verifier=verifier,
            max_request_bytes=config.max_request_bytes,
        )

    def verify_purchase(self, body: Mapping[str, Any]) -> Dict[str, str]:
        started = time.monotonic()
        status = "ok"
        failure_reason: Optional[str] = None
        has_transaction_app_account_token: Optional[bool] = None
        apple_verification_status: Optional[str] = None
        apple_verification_statuses: Optional[str] = None
        request = self.validator.validate_purchase_body(body)
        result: EntitlementRecord
        try:
            result = self.verifier.verify_purchase(request)
        except AppleVerificationUnavailable:
            status = "unavailable"
            result = verification_unavailable_record(request)
        except AppleVerificationFailed as exc:
            status = "failed"
            failure_reason = str(exc)
            has_transaction_app_account_token = exc.has_transaction_app_account_token
            apple_verification_status = exc.apple_verification_status
            apple_verification_statuses = exc.apple_verification_statuses
            result = self.store.upsert_entitlement(verification_failed_record(request))
        else:
            result = self.store.upsert_entitlement(result)
        finally:
            fields: Dict[str, object] = {
                "op": "verify_purchase",
                "has_app_account_token": bool(request.app_account_token),
                "product_id": request.product_id,
                "server_verification_data_format": classify_verification_data(
                    request.server_verification_data
                ),
                "duration_ms": duration_ms_since(started),
                "status": status,
            }
            if failure_reason is not None:
                fields["reason"] = failure_reason
                if has_transaction_app_account_token is not None:
                    fields["has_transaction_app_account_token"] = has_transaction_app_account_token
                if apple_verification_status is not None:
                    fields["apple_verification_status"] = apple_verification_status
                if apple_verification_statuses is not None:
                    fields["apple_verification_statuses"] = apple_verification_statuses
            log_iap_event(fields)
        return result.to_response_body()

    def current_entitlement(self, query: Mapping[str, List[str]]) -> Dict[str, str]:
        raw_token = last_query_value(query, "appAccountToken")
        app_account_token = self.validator.validate_current_entitlement_query(raw_token)
        record = self.store.get_entitlement(app_account_token)
        if record is None:
            return no_active_entitlement_record(app_account_token).to_response_body()
        try:
            refreshed = self.verifier.refresh_current_entitlement(record)
        except AppleVerificationUnavailable:
            return EntitlementRecord(
                outcome="verificationUnavailable",
                entitlement_tier="none",
                product_id=record.product_id,
                app_account_token=app_account_token,
                original_transaction_id=record.original_transaction_id,
                environment=record.environment,
            ).to_response_body()
        if refreshed != record:
            refreshed = self.store.upsert_entitlement(refreshed)
        return refreshed.to_response_body()


def last_query_value(query: Mapping[str, List[str]], key: str) -> Optional[str]:
    values = query.get(key)
    if not values:
        return None
    return values[-1]


def classify_verification_data(value: str) -> str:
    stripped = value.strip()
    if not stripped:
        return "empty"
    if stripped.count(".") == 2:
        return "jws"
    return "non_jws"


def build_verifier_from_config(config: AppConfig) -> AppleVerifier:
    if config.apple_credentials.is_complete:
        return build_real_apple_verifier_from_config(
            config.apple_credentials,
            allowed_products=config.allowed_products,
            request_timeout_seconds=config.apple_request_timeout_seconds,
        )
    return AppleServerApiVerifierPlaceholder()


class IapVerificationRequestHandler(http.server.BaseHTTPRequestHandler):
    server_version = "FleetLedgerIAPVerification/1.0"

    def do_GET(self) -> None:
        self._handle("GET")

    def do_POST(self) -> None:
        self._handle("POST")

    def log_message(self, format: str, *args: Any) -> None:
        message = redact_app_account_token_values(format % args)
        print(
            "%s - - [%s] %s"
            % (self.address_string(), self.log_date_time_string(), message),
            flush=True,
        )

    @property
    def app(self) -> IapVerificationApp:
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
            if method == "POST" and path == "/iap/apple/verify-purchase":
                body = read_json_body(self, self.app.max_request_bytes)
                json_response(self, 200, self.app.verify_purchase(body))
                return
            if method == "GET" and path == "/iap/apple/current-entitlement":
                query = urllib.parse.parse_qs(parsed.query, keep_blank_values=True)
                json_response(self, 200, self.app.current_entitlement(query))
                return
            raise HttpError(404, "not_found", "endpoint not found")
        except HttpError as exc:
            error_response(self, exc)
        except Exception:
            log_internal_error(request_id, method, path)
            error_response(self, HttpError(500, "internal_error", "internal server error"))


class IapVerificationHttpServer(http.server.ThreadingHTTPServer):
    def __init__(self, server_address: tuple[str, int], app: IapVerificationApp):
        super().__init__(server_address, IapVerificationRequestHandler)
        self.app = app


def build_server_from_env() -> IapVerificationHttpServer:
    config = AppConfig.from_env()
    return IapVerificationHttpServer((config.host, config.port), IapVerificationApp.from_env())
