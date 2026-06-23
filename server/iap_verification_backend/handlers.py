from __future__ import annotations

import http.server
import time
import urllib.parse
from typing import Any, Dict, List, Mapping, Optional

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
        request = self.validator.validate_purchase_body(body)
        result: EntitlementRecord
        try:
            result = self.verifier.verify_purchase(request)
        except AppleVerificationUnavailable:
            status = "unavailable"
            result = verification_unavailable_record(request)
        except AppleVerificationFailed:
            status = "failed"
            result = self.store.upsert_entitlement(verification_failed_record(request))
        else:
            result = self.store.upsert_entitlement(result)
        finally:
            log_iap_event(
                {
                    "op": "verify_purchase",
                    "app_account_token": request.app_account_token,
                    "product_id": request.product_id,
                    "duration_ms": duration_ms_since(started),
                    "status": status,
                }
            )
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


def build_verifier_from_config(config: AppConfig) -> AppleVerifier:
    # IAP-S2 owns the real Apple verifier wiring. Until then every production
    # environment must fail-closed, even if Apple credential placeholders exist.
    if config.apple_credentials.is_complete:
        return AppleServerApiVerifierPlaceholder()
    return AppleServerApiVerifierPlaceholder()


class IapVerificationRequestHandler(http.server.BaseHTTPRequestHandler):
    server_version = "FleetLedgerIAPVerification/1.0"

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
