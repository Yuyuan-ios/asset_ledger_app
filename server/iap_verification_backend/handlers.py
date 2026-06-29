from __future__ import annotations

import http.server
import hmac
import os
import re
import sqlite3
import sys
import time
import urllib.parse
from pathlib import Path
from typing import Any, Dict, List, Mapping, Optional

_SERVER_ROOT = Path(__file__).resolve().parents[1]
if str(_SERVER_ROOT) not in sys.path:
    sys.path.insert(0, str(_SERVER_ROOT))

from apple_verifier import build_real_apple_verifier_from_config
from auth import Authenticator, RequestValidator, require_text
from common.auth_identity.auth_planes import AuthPlane
from common.auth_identity.resolver import ensure_auth_operation_allowed, require_stable_user_id
from common.entitlement_model import EntitlementAuthContext, EntitlementDecision
from common.entitlement_resolver import EntitlementResolver
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
from subscription_storage_gateway import EntitlementClaimConflict, EntitlementDBGateway
from payment_channel_adapters import (
    build_default_payment_channel_adapters,
    normalize_channel_name,
)
from subscription_audit_log import SubscriptionAuditLog
from subscription_authority_resolver import SubscriptionAuthorityResolver
from subscription_event_ordering import SubscriptionEventOrdering
from subscription_event_explainer import ExplanationIntegrityError
from subscription_gateway import EntitlementEngine, SubscriptionGatewayService
from subscription_state_machine import SubscriptionStateMachine
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
        store: EntitlementDBGateway,
        validator: RequestValidator,
        verifier: AppleVerifier,
        max_request_bytes: int = MAX_REQUEST_BYTES,
        authenticator: Optional[Authenticator] = None,
        internal_entitlement_token: Optional[str] = None,
        channel_signature_secrets: Optional[Mapping[str, str]] = None,
        gateway_service: Optional[SubscriptionGatewayService] = None,
        entitlement_resolver: Optional[EntitlementResolver] = None,
        app_env: Optional[str] = None,
    ):
        self.store = store
        self.validator = validator
        self.verifier = verifier
        self.max_request_bytes = max_request_bytes
        self.authenticator = authenticator
        self.internal_entitlement_token = internal_entitlement_token
        self.internal_entitlement_auth_plane = AuthPlane.SERVICE
        self.entitlement_resolver = entitlement_resolver or EntitlementResolver()
        self.app_env = app_env or iap_app_env()
        if gateway_service is not None:
            self.gateway_service = gateway_service
        elif hasattr(self.store, "db_path"):
            self.gateway_service = SubscriptionGatewayService(
                store=self.store,
                adapters=build_default_payment_channel_adapters(
                    self.validator,
                    self.verifier,
                    channel_signature_secrets,
                ),
                entitlement_engine=EntitlementEngine(
                    self.store,
                    self.validator.allowed_products,
                ),
                authority_resolver=SubscriptionAuthorityResolver(),
                ordering_layer=SubscriptionEventOrdering(self.store),
                state_machine=SubscriptionStateMachine(),
                audit_log=SubscriptionAuditLog(self.store),
            )
        else:
            self.gateway_service = None

    @classmethod
    def from_env(cls) -> "IapVerificationApp":
        config = AppConfig.from_env()
        verifier = build_verifier_from_config(config)
        return cls(
            store=EntitlementDBGateway(config.database_path),
            validator=RequestValidator(config.allowed_products, config.allowed_bundle_id),
            verifier=verifier,
            max_request_bytes=config.max_request_bytes,
            authenticator=Authenticator.from_env(),
            internal_entitlement_token=config.internal_entitlement_token,
            app_env=iap_app_env(),
        )

    def verify_purchase(
        self,
        body: Mapping[str, Any],
        authorization_header: Optional[str] = None,
    ) -> Dict[str, str]:
        started = time.monotonic()
        status = "ok"
        failure_reason: Optional[str] = None
        has_transaction_app_account_token: Optional[bool] = None
        apple_verification_status: Optional[str] = None
        apple_verification_statuses: Optional[str] = None
        request = self.validator.validate_purchase_body(body)
        user_id = self._authenticate_optional_bearer(authorization_header)
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
            result = self.gateway_service.commit_legacy_apple_record(
                request,
                verification_failed_record(request),
            )
        else:
            try:
                result = self.gateway_service.commit_legacy_apple_record(
                    request,
                    result,
                    server_user_id=user_id,
                )
            except EntitlementClaimConflict as exc:
                raise HttpError(
                    409,
                    "subscription_bound_to_other_user",
                    "subscription is already bound to another account",
                ) from exc
        finally:
            fields: Dict[str, object] = {
                "op": "verify_purchase",
                "has_app_account_token": bool(request.app_account_token),
                "has_user_binding": user_id is not None,
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

    def receive_purchase_event(
        self,
        channel: str,
        body: Mapping[str, Any],
        authorization_header: Optional[str] = None,
    ) -> Dict[str, object]:
        server_user_id = None
        if self.gateway_service is None:
            raise HttpError(
                503,
                "subscription_gateway_unavailable",
                "Subscription gateway is currently unavailable.",
            )
        if normalize_channel_name(channel) == "apple":
            server_user_id = self._authenticate_optional_bearer(authorization_header)
            if server_user_id is None:
                raise HttpError(401, "unauthorized", "Bearer token is required")
        return self.gateway_service.receive_purchase_event(
            normalize_channel_name(channel),
            body,
            server_user_id=server_user_id,
        )

    def internal_entitlement_verify(
        self,
        body: Mapping[str, Any],
        authorization_header: Optional[str],
    ) -> Dict[str, object]:
        ensure_auth_operation_allowed(self.internal_entitlement_auth_plane)
        self._authenticate_internal_entitlement_request(authorization_header)
        user_id = require_stable_user_id(
            body.get("user_id"),
            auth_plane=self.internal_entitlement_auth_plane,
        )
        required_capability = require_text(
            body.get("required_capability"),
            "required_capability",
            max_length=64,
        )
        if required_capability not in {"cloud_backup", "sync"}:
            raise HttpError(
                400,
                "invalid_required_capability",
                "required_capability must be cloud_backup or sync",
            )
        required_plan = require_text(body.get("required_plan"), "required_plan", max_length=32)
        if required_capability == "cloud_backup" and required_plan != "max":
            raise HttpError(400, "invalid_required_plan", "required_plan must be max")
        if required_capability == "sync" and required_plan not in {"paid", "pro", "max"}:
            raise HttpError(
                400,
                "invalid_required_plan",
                "required_plan must be paid, pro, or max",
            )
        try:
            if required_plan == "max":
                record = self.store.get_latest_max_entitlement_for_user(user_id)
                if record is None:
                    record = self.store.get_latest_entitlement_for_user(user_id)
            else:
                record = self.store.get_latest_entitlement_for_user(user_id)
        except sqlite3.Error as exc:
            raise HttpError(
                503,
                "subscription_verification_unavailable",
                "Subscription verification is currently unavailable.",
            ) from exc
        return internal_entitlement_response(record, required_plan=required_plan)

    def internal_ledger_replay(
        self,
        user_id: str,
        authorization_header: Optional[str],
    ) -> Dict[str, object]:
        ensure_auth_operation_allowed(self.internal_entitlement_auth_plane)
        auth_context = self._authenticate_internal_entitlement_request(authorization_header)
        stable_user_id = require_stable_user_id(
            user_id,
            auth_plane=self.internal_entitlement_auth_plane,
        )
        self._require_entitlement_decision(auth_context, "ledger_read", stable_user_id)
        if self.gateway_service is None:
            raise HttpError(
                503,
                "subscription_gateway_unavailable",
                "Subscription gateway is currently unavailable.",
            )
        replay_engine = self.gateway_service.replay_engine
        event_store = self.gateway_service.event_store
        before_state = replay_engine.replay(stable_user_id, update_projection=False)
        diff_before = replay_engine.projection_store.diff(stable_user_id, before_state)
        replayed = replay_engine.replay(stable_user_id, update_projection=True)
        diff_after = replay_engine.projection_store.diff(stable_user_id, replayed)
        return {
            "userId": stable_user_id,
            "events": [event.to_dict() for event in event_store.get_events(stable_user_id)],
            "reconstructedState": replayed.to_dict(),
            "projectionDiffBefore": diff_before,
            "projectionDiffAfter": diff_after,
        }

    def internal_billing_explain(
        self,
        user_id: str,
        authorization_header: Optional[str],
    ) -> Dict[str, object]:
        ensure_auth_operation_allowed(self.internal_entitlement_auth_plane)
        auth_context = self._authenticate_internal_entitlement_request(authorization_header)
        stable_user_id = require_stable_user_id(
            user_id,
            auth_plane=self.internal_entitlement_auth_plane,
        )
        self._require_entitlement_decision(auth_context, "observability", stable_user_id)
        if self.gateway_service is None:
            raise HttpError(
                503,
                "subscription_gateway_unavailable",
                "Subscription gateway is currently unavailable.",
            )
        return self.gateway_service.explain_user(stable_user_id)

    def internal_billing_explain_event(
        self,
        event_id: str,
        authorization_header: Optional[str],
    ) -> Dict[str, object]:
        ensure_auth_operation_allowed(self.internal_entitlement_auth_plane)
        auth_context = self._authenticate_internal_entitlement_request(authorization_header)
        try:
            normalized_event_id = int(event_id)
        except ValueError as exc:
            raise HttpError(400, "invalid_event_id", "event_id must be an integer") from exc
        if normalized_event_id <= 0:
            raise HttpError(400, "invalid_event_id", "event_id must be positive")
        self._require_entitlement_decision(auth_context, "observability", event_id)
        if self.gateway_service is None:
            raise HttpError(
                503,
                "subscription_gateway_unavailable",
                "Subscription gateway is currently unavailable.",
            )
        explanation = self.gateway_service.explain_event(normalized_event_id)
        if explanation is None:
            raise HttpError(404, "event_not_found", "subscription event was not found")
        return explanation

    def internal_billing_graph(
        self,
        user_id: str,
        authorization_header: Optional[str],
    ) -> Dict[str, object]:
        ensure_auth_operation_allowed(self.internal_entitlement_auth_plane)
        auth_context = self._authenticate_internal_entitlement_request(authorization_header)
        stable_user_id = require_stable_user_id(
            user_id,
            auth_plane=self.internal_entitlement_auth_plane,
        )
        self._require_entitlement_decision(auth_context, "observability", stable_user_id)
        if self.gateway_service is None:
            raise HttpError(
                503,
                "subscription_gateway_unavailable",
                "Subscription gateway is currently unavailable.",
            )
        return self.gateway_service.get_decision_graph(stable_user_id)

    def internal_billing_graph_event(
        self,
        event_id: str,
        authorization_header: Optional[str],
    ) -> Dict[str, object]:
        ensure_auth_operation_allowed(self.internal_entitlement_auth_plane)
        auth_context = self._authenticate_internal_entitlement_request(authorization_header)
        try:
            normalized_event_id = int(event_id)
        except ValueError as exc:
            raise HttpError(400, "invalid_event_id", "event_id must be an integer") from exc
        self._require_entitlement_decision(auth_context, "observability", event_id)
        if self.gateway_service is None:
            raise HttpError(
                503,
                "subscription_gateway_unavailable",
                "Subscription gateway is currently unavailable.",
            )
        graph = self.gateway_service.get_decision_graph_for_event(normalized_event_id)
        if graph is None:
            raise HttpError(404, "event_not_found", "subscription event was not found")
        return graph

    def internal_billing_graph_summary(
        self,
        user_id: str,
        authorization_header: Optional[str],
    ) -> Dict[str, object]:
        ensure_auth_operation_allowed(self.internal_entitlement_auth_plane)
        auth_context = self._authenticate_internal_entitlement_request(authorization_header)
        stable_user_id = require_stable_user_id(
            user_id,
            auth_plane=self.internal_entitlement_auth_plane,
        )
        self._require_entitlement_decision(auth_context, "observability", stable_user_id)
        if self.gateway_service is None:
            raise HttpError(
                503,
                "subscription_gateway_unavailable",
                "Subscription gateway is currently unavailable.",
            )
        return self.gateway_service.get_decision_graph_summary(stable_user_id)

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
        return refreshed.to_response_body()

    def _authenticate_optional_bearer(self, authorization_header: Optional[str]) -> Optional[str]:
        if authorization_header is None or not authorization_header.strip():
            return None
        authenticator = self.authenticator
        if authenticator is None:
            raise HttpError(401, "unauthorized", "token is not accepted")
        return authenticator.authenticate(authorization_header)

    def _authenticate_internal_entitlement_request(
        self,
        authorization_header: Optional[str],
    ) -> EntitlementAuthContext:
        ensure_auth_operation_allowed(self.internal_entitlement_auth_plane)
        expected = self.internal_entitlement_token
        if not expected:
            raise HttpError(
                503,
                "internal_entitlement_unconfigured",
                "internal entitlement verification is not configured",
            )
        if not authorization_header or not authorization_header.startswith("Bearer "):
            raise HttpError(401, "unauthorized", "Bearer token is required")
        token = authorization_header[len("Bearer ") :].strip()
        if not hmac.compare_digest(token, expected):
            raise HttpError(401, "unauthorized", "token is not accepted")
        return EntitlementAuthContext(is_internal=True, operation="read")

    def _require_entitlement_decision(
        self,
        auth_context: EntitlementAuthContext,
        request_type: str,
        user_id: str,
    ) -> EntitlementDecision:
        decision = self.entitlement_resolver.resolve(
            auth_context,
            request_type=request_type,
            user_id=user_id,
            env=self.app_env,
        )
        if not decision.allow:
            raise iap_entitlement_denied_error(decision)
        return decision


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


def internal_entitlement_response(
    record: Optional[EntitlementRecord],
    *,
    required_plan: str = "max",
) -> Dict[str, object]:
    if record is None:
        return {
            "allowed": False,
            "entitlementTier": "none",
            "entitlementActive": False,
            "status": "none",
            "reason": _required_plan_reason(required_plan),
        }

    tier = record.entitlement_tier
    if tier == "none":
        tier = tier_from_product_id(record.product_id) or "none"
    status = internal_status_for_outcome(record.outcome)
    if _record_matches_required_plan(record, required_plan) and status == "active":
        return {
            "allowed": True,
            "entitlementTier": tier,
            "entitlementActive": True,
            "status": "active",
        }
    if _record_matches_required_plan(record, required_plan) and status == "grace":
        return {
            "allowed": True,
            "entitlementTier": tier,
            "entitlementActive": False,
            "status": "grace",
            "limits": {"readOnly": True},
        }
    return {
        "allowed": False,
        "entitlementTier": tier,
        "entitlementActive": False,
        "status": status,
        "reason": _required_plan_reason(required_plan),
    }


def tier_from_product_id(product_id: Optional[str]) -> Optional[str]:
    if product_id is None:
        return None
    if product_id.endswith(".max.yearly"):
        return "max"
    if product_id.endswith(".pro.yearly"):
        return "pro"
    return None


def internal_status_for_outcome(outcome: str) -> str:
    if outcome in {"verifiedActivePro", "verifiedActiveMax"}:
        return "active"
    if outcome in {"verifiedGracePeriodPro", "verifiedGracePeriodMax"}:
        return "grace"
    if outcome == "billingRetry":
        return "billing_retry"
    if outcome == "noActiveEntitlement":
        return "none"
    return outcome


def _record_matches_required_plan(record: EntitlementRecord, required_plan: str) -> bool:
    normalized = required_plan.strip().lower()
    tier = record.entitlement_tier
    if tier == "none":
        tier = tier_from_product_id(record.product_id) or "none"
    if normalized == "paid":
        return tier in {"pro", "max"}
    return tier == normalized


def _required_plan_reason(required_plan: str) -> str:
    normalized = required_plan.strip().lower()
    if normalized == "paid":
        return "requires_paid"
    return f"requires_{normalized or 'paid'}"


def iap_entitlement_denied_error(decision: EntitlementDecision) -> HttpError:
    if decision.reason == "internal_cannot_override_entitlement_state":
        return HttpError(
            403,
            "entitlement_override_forbidden",
            "Internal token cannot override entitlement state.",
        )
    return HttpError(
        403,
        "entitlement_denied",
        "Entitlement decision denied the request.",
    )


def iap_app_env() -> str:
    return (
        os.environ.get("APP_ENV", "").strip()
        or os.environ.get("FLEET_APP_ENV", "").strip()
        or "production"
    ).lower()


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
                json_response(
                    self,
                    200,
                    self.app.verify_purchase(body, self.headers.get("Authorization")),
                )
                return
            if method == "GET" and path == "/iap/apple/current-entitlement":
                query = urllib.parse.parse_qs(parsed.query, keep_blank_values=True)
                json_response(self, 200, self.app.current_entitlement(query))
                return
            gateway_prefix = "/iap/gateway/"
            if method == "POST" and path.startswith(gateway_prefix):
                channel = path[len(gateway_prefix) :].split("/", 1)[0]
                body = read_json_body(self, self.app.max_request_bytes)
                json_response(
                    self,
                    200,
                    self.app.receive_purchase_event(
                        channel,
                        body,
                        self.headers.get("Authorization"),
                    ),
                )
                return
            webhook_prefix = "/iap/webhooks/"
            if method == "POST" and path.startswith(webhook_prefix):
                channel = path[len(webhook_prefix) :].split("/", 1)[0]
                body = read_json_body(self, self.app.max_request_bytes)
                json_response(
                    self,
                    200,
                    self.app.receive_purchase_event(channel, body),
                )
                return
            if method == "POST" and path == "/internal/v1/entitlements/verify":
                body = read_json_body(self, self.app.max_request_bytes)
                json_response(
                    self,
                    200,
                    self.app.internal_entitlement_verify(
                        body,
                        self.headers.get("Authorization"),
                    ),
                )
                return
            ledger_prefix = "/internal/v2/ledger/replay/"
            if method == "GET" and path.startswith(ledger_prefix):
                user_id = urllib.parse.unquote(path[len(ledger_prefix) :])
                json_response(
                    self,
                    200,
                    self.app.internal_ledger_replay(
                        user_id,
                        self.headers.get("Authorization"),
                    ),
                )
                return
            explain_event_prefix = "/internal/v3/billing/explain/event/"
            if method == "GET" and path.startswith(explain_event_prefix):
                event_id = urllib.parse.unquote(path[len(explain_event_prefix) :])
                json_response(
                    self,
                    200,
                    self.app.internal_billing_explain_event(
                        event_id,
                        self.headers.get("Authorization"),
                    ),
                )
                return
            explain_prefix = "/internal/v3/billing/explain/"
            if method == "GET" and path.startswith(explain_prefix):
                user_id = urllib.parse.unquote(path[len(explain_prefix) :])
                json_response(
                    self,
                    200,
                    self.app.internal_billing_explain(
                        user_id,
                        self.headers.get("Authorization"),
                    ),
                )
                return
            graph_event_prefix = "/internal/v3/billing/graph/event/"
            if method == "GET" and path.startswith(graph_event_prefix):
                event_id = urllib.parse.unquote(path[len(graph_event_prefix) :])
                json_response(
                    self,
                    200,
                    self.app.internal_billing_graph_event(
                        event_id,
                        self.headers.get("Authorization"),
                    ),
                )
                return
            graph_prefix = "/internal/v3/billing/graph/"
            if method == "GET" and path.startswith(graph_prefix):
                graph_path = urllib.parse.unquote(path[len(graph_prefix) :])
                summary_suffix = "/summary"
                if graph_path.endswith(summary_suffix):
                    user_id = graph_path[: -len(summary_suffix)]
                    json_response(
                        self,
                        200,
                        self.app.internal_billing_graph_summary(
                            user_id,
                            self.headers.get("Authorization"),
                        ),
                    )
                    return
                json_response(
                    self,
                    200,
                    self.app.internal_billing_graph(
                        graph_path,
                        self.headers.get("Authorization"),
                    ),
                )
                return
            raise HttpError(404, "not_found", "endpoint not found")
        except HttpError as exc:
            error_response(self, exc)
        except ExplanationIntegrityError:
            log_internal_error(request_id, method, path)
            error_response(
                self,
                HttpError(
                    500,
                    "explanation_integrity_failure",
                    "EXPLANATION INTEGRITY FAILURE",
                ),
            )
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
