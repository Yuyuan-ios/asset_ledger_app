from __future__ import annotations

import dataclasses
import datetime as dt
from typing import Any, Dict, Iterable, List, Mapping, Optional, Protocol, Sequence

from config import AppleCredentialConfig, MAX_YEARLY_PRODUCT_ID, PRO_YEARLY_PRODUCT_ID
from verifier import (
    AppleVerificationFailed,
    AppleVerificationUnavailable,
    EntitlementRecord,
    OUTCOME_TO_TIER,
    PurchaseVerificationRequest,
)


APPLE_STATUS_ACTIVE = 1
APPLE_STATUS_EXPIRED = 2
APPLE_STATUS_BILLING_RETRY = 3
APPLE_STATUS_BILLING_GRACE_PERIOD = 4
APPLE_STATUS_REVOKED = 5
ENVIRONMENT_PRODUCTION = "Production"
ENVIRONMENT_SANDBOX = "Sandbox"


@dataclasses.dataclass(frozen=True)
class DecodedAppleTransaction:
    original_transaction_id: str
    transaction_id: str
    product_id: str
    bundle_id: str
    app_account_token: Optional[str]
    environment: str
    expires_date_ms: Optional[int] = None
    revocation_date_ms: Optional[int] = None


@dataclasses.dataclass(frozen=True)
class DecodedAppleRenewalInfo:
    product_id: Optional[str] = None
    auto_renew_product_id: Optional[str] = None
    environment: Optional[str] = None
    is_in_billing_retry_period: Optional[bool] = None
    grace_period_expires_date_ms: Optional[int] = None


@dataclasses.dataclass(frozen=True)
class AppleSubscriptionStatusItem:
    status: Any
    original_transaction_id: Optional[str]
    signed_transaction_info: str
    signed_renewal_info: Optional[str] = None


class SignedApplePayloadVerifier(Protocol):
    def verify_transaction(self, signed_transaction: str) -> DecodedAppleTransaction:
        ...

    def verify_renewal_info(self, signed_renewal_info: str, environment: str) -> DecodedAppleRenewalInfo:
        ...


class AppleSubscriptionStatusClient(Protocol):
    def get_all_subscription_statuses(
        self,
        any_transaction_id: str,
        environment: str,
    ) -> Sequence[AppleSubscriptionStatusItem]:
        ...


class AppStoreServerAppleVerifier:
    def __init__(
        self,
        *,
        allowed_products: Sequence[str],
        bundle_id: str,
        signed_payload_verifier: SignedApplePayloadVerifier,
        subscription_status_client: AppleSubscriptionStatusClient,
    ):
        self.allowed_products = set(allowed_products)
        self.bundle_id = bundle_id
        self.signed_payload_verifier = signed_payload_verifier
        self.subscription_status_client = subscription_status_client

    def verify_purchase(self, request: PurchaseVerificationRequest) -> EntitlementRecord:
        transaction = self._verify_request_transaction(request.server_verification_data)
        self._validate_transaction_matches_request(transaction, request)
        statuses = self._load_subscription_statuses(transaction.transaction_id, transaction.environment)
        mapped = self._map_best_status(
            statuses,
            app_account_token=request.app_account_token,
            requested_product_id=request.product_id,
            fallback_transaction=transaction,
        )
        if mapped is None:
            raise AppleVerificationFailed("verified transaction has no subscription status")
        return mapped

    def refresh_current_entitlement(self, record: EntitlementRecord) -> EntitlementRecord:
        lookup_id = record.original_transaction_id or record.latest_transaction_id
        if lookup_id is None or record.environment is None:
            return record
        statuses = self._load_subscription_statuses(lookup_id, record.environment)
        mapped = self._map_best_status(
            statuses,
            app_account_token=record.app_account_token,
            requested_product_id=record.product_id,
            fallback_transaction=None,
        )
        return mapped or record

    def _verify_request_transaction(self, signed_transaction: str) -> DecodedAppleTransaction:
        try:
            return self.signed_payload_verifier.verify_transaction(signed_transaction)
        except AppleVerificationUnavailable:
            raise
        except AppleVerificationFailed:
            raise
        except Exception as exc:
            raise AppleVerificationUnavailable("apple signed transaction verifier failed") from exc

    def _validate_transaction_matches_request(
        self,
        transaction: DecodedAppleTransaction,
        request: PurchaseVerificationRequest,
    ) -> None:
        if transaction.bundle_id != self.bundle_id:
            raise AppleVerificationFailed("transaction bundle id does not match")
        if transaction.product_id != request.product_id:
            raise AppleVerificationFailed("transaction product id does not match request")
        if transaction.product_id not in self.allowed_products:
            raise AppleVerificationFailed("transaction product id is not allowed")
        _validate_app_account_token_match(
            transaction.app_account_token,
            request.app_account_token,
            "transaction appAccountToken does not match request",
        )
        if not transaction.original_transaction_id or not transaction.transaction_id:
            raise AppleVerificationFailed("transaction identifiers are missing")

    def _load_subscription_statuses(
        self,
        any_transaction_id: str,
        environment: str,
    ) -> Sequence[AppleSubscriptionStatusItem]:
        try:
            return self.subscription_status_client.get_all_subscription_statuses(any_transaction_id, environment)
        except AppleVerificationUnavailable:
            raise
        except AppleVerificationFailed:
            raise
        except Exception as exc:
            raise AppleVerificationUnavailable("apple subscription status lookup failed") from exc

    def _map_best_status(
        self,
        statuses: Sequence[AppleSubscriptionStatusItem],
        *,
        app_account_token: str,
        requested_product_id: Optional[str],
        fallback_transaction: Optional[DecodedAppleTransaction],
    ) -> Optional[EntitlementRecord]:
        candidates: List[tuple[DecodedAppleTransaction, Optional[DecodedAppleRenewalInfo], int]] = []
        for item in statuses:
            status = normalize_apple_status(item.status)
            try:
                transaction = self.signed_payload_verifier.verify_transaction(item.signed_transaction_info)
                renewal = None
                if item.signed_renewal_info:
                    renewal = self.signed_payload_verifier.verify_renewal_info(
                        item.signed_renewal_info,
                        transaction.environment,
                    )
            except AppleVerificationUnavailable:
                raise
            except AppleVerificationFailed:
                raise
            except Exception as exc:
                raise AppleVerificationUnavailable("apple status payload verification failed") from exc
            if (
                fallback_transaction is not None
                and transaction.original_transaction_id != fallback_transaction.original_transaction_id
            ):
                continue
            if requested_product_id is not None and transaction.product_id != requested_product_id:
                continue
            self._validate_status_transaction(transaction, app_account_token)
            candidates.append((transaction, renewal, status))

        if not candidates:
            return None

        transaction, renewal, status = max(candidates, key=lambda candidate: transaction_sort_key(candidate[0]))
        return map_apple_subscription_state(status, transaction, renewal, app_account_token)

    def _validate_status_transaction(self, transaction: DecodedAppleTransaction, app_account_token: str) -> None:
        if transaction.bundle_id != self.bundle_id:
            raise AppleVerificationFailed("status transaction bundle id does not match")
        if transaction.product_id not in self.allowed_products:
            raise AppleVerificationFailed("status transaction product id is not allowed")
        _validate_app_account_token_match(
            transaction.app_account_token,
            app_account_token,
            "status transaction appAccountToken does not match",
        )


def _normalize_app_account_token(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    normalized = value.strip().lower()
    return normalized or None


def _validate_app_account_token_match(
    transaction_app_account_token: Optional[str],
    expected_app_account_token: str,
    failure_message: str,
) -> None:
    transaction_token = _normalize_app_account_token(transaction_app_account_token)
    if transaction_token is None:
        return
    expected_token = _normalize_app_account_token(expected_app_account_token)
    if transaction_token != expected_token:
        raise AppleVerificationFailed(
            failure_message,
            has_transaction_app_account_token=True,
        )


def normalize_apple_status(status: Any) -> int:
    raw = getattr(status, "value", status)
    if isinstance(raw, str):
        upper = raw.upper()
        names = {
            "ACTIVE": APPLE_STATUS_ACTIVE,
            "EXPIRED": APPLE_STATUS_EXPIRED,
            "BILLING_RETRY": APPLE_STATUS_BILLING_RETRY,
            "BILLING_GRACE_PERIOD": APPLE_STATUS_BILLING_GRACE_PERIOD,
            "REVOKED": APPLE_STATUS_REVOKED,
        }
        if upper in names:
            return names[upper]
        if raw.isdigit():
            return int(raw)
    if isinstance(raw, int) and not isinstance(raw, bool):
        return raw
    raise AppleVerificationFailed("unknown apple subscription status")


def transaction_sort_key(transaction: DecodedAppleTransaction) -> tuple[int, str]:
    return (transaction.expires_date_ms or 0, transaction.transaction_id)


def map_apple_subscription_state(
    status: int,
    transaction: DecodedAppleTransaction,
    renewal: Optional[DecodedAppleRenewalInfo],
    app_account_token: str,
) -> EntitlementRecord:
    product_id = transaction.product_id
    if product_id not in {PRO_YEARLY_PRODUCT_ID, MAX_YEARLY_PRODUCT_ID}:
        raise AppleVerificationFailed("cannot map unknown product")

    if transaction.revocation_date_ms is not None:
        outcome = "revoked"
    elif status == APPLE_STATUS_ACTIVE:
        outcome = "verifiedActiveMax" if product_id == MAX_YEARLY_PRODUCT_ID else "verifiedActivePro"
    elif status == APPLE_STATUS_BILLING_GRACE_PERIOD:
        outcome = "verifiedGracePeriodMax" if product_id == MAX_YEARLY_PRODUCT_ID else "verifiedGracePeriodPro"
    elif status == APPLE_STATUS_BILLING_RETRY:
        outcome = "billingRetry"
    elif status == APPLE_STATUS_EXPIRED:
        outcome = "expired"
    elif status == APPLE_STATUS_REVOKED:
        outcome = "revoked"
    else:
        raise AppleVerificationFailed("unknown apple subscription status")

    return EntitlementRecord(
        outcome=outcome,
        entitlement_tier=OUTCOME_TO_TIER[outcome],
        product_id=product_id,
        app_account_token=app_account_token,
        original_transaction_id=transaction.original_transaction_id,
        latest_transaction_id=transaction.transaction_id,
        environment=transaction.environment,
        expires_at=expires_at_for_status(status, transaction, renewal),
        revoked_at=millis_to_iso(transaction.revocation_date_ms),
    )


def expires_at_for_status(
    status: int,
    transaction: DecodedAppleTransaction,
    renewal: Optional[DecodedAppleRenewalInfo],
) -> Optional[str]:
    if status == APPLE_STATUS_BILLING_GRACE_PERIOD and renewal is not None:
        grace_end = renewal.grace_period_expires_date_ms
        if grace_end is not None:
            return millis_to_iso(grace_end)
    return millis_to_iso(transaction.expires_date_ms)


def millis_to_iso(value: Optional[int]) -> Optional[str]:
    if value is None:
        return None
    instant = dt.datetime.fromtimestamp(value / 1000, tz=dt.timezone.utc)
    return instant.isoformat(timespec="milliseconds").replace("+00:00", "Z")


class OfficialSignedDataVerifier:
    def __init__(
        self,
        *,
        root_certificates: Sequence[bytes],
        bundle_id: str,
        app_apple_id: Optional[int],
    ):
        self.root_certificates = list(root_certificates)
        self.bundle_id = bundle_id
        self.app_apple_id = app_apple_id
        self._verifiers: Dict[str, Any] = {}

    def verify_transaction(self, signed_transaction: str) -> DecodedAppleTransaction:
        return self._verify_with_any_environment(
            signed_transaction,
            lambda verifier, payload: verifier.verify_and_decode_signed_transaction(payload),
            _transaction_from_apple_payload,
        )

    def verify_renewal_info(self, signed_renewal_info: str, environment: str) -> DecodedAppleRenewalInfo:
        verifier = self._verifier_for_environment(environment)
        try:
            payload = verifier.verify_and_decode_renewal_info(signed_renewal_info)
        except self._verification_exception_type() as exc:
            self._raise_for_verification_exception(exc)
        except Exception as exc:
            raise AppleVerificationUnavailable("apple renewal info verification failed") from exc
        return _renewal_from_apple_payload(payload)

    def _verify_with_any_environment(self, signed_payload: str, verify_call, mapper):
        deterministic_errors = []
        retryable_errors = []
        for environment in (ENVIRONMENT_SANDBOX, ENVIRONMENT_PRODUCTION):
            verifier = self._verifier_for_environment(environment)
            try:
                return mapper(verify_call(verifier, signed_payload))
            except self._verification_exception_type() as exc:
                if self._is_retryable_verification_exception(exc):
                    retryable_errors.append((environment, exc, _verification_status_name(exc)))
                else:
                    deterministic_errors.append((environment, exc, _verification_status_name(exc)))
            except Exception as exc:
                raise AppleVerificationUnavailable("apple signed payload verification failed") from exc
        if retryable_errors:
            raise AppleVerificationUnavailable(
                "apple signed payload verification is temporarily unavailable"
            ) from retryable_errors[-1][1]
        cause = deterministic_errors[-1][1] if deterministic_errors else None
        raise AppleVerificationFailed(
            "apple signed payload verification failed",
            apple_verification_statuses=_format_verification_statuses(deterministic_errors),
        ) from cause

    def _verifier_for_environment(self, environment: str):
        if environment in self._verifiers:
            return self._verifiers[environment]

        try:
            from appstoreserverlibrary.models.Environment import Environment
            from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier
        except ModuleNotFoundError as exc:
            raise AppleVerificationUnavailable("app-store-server-library is not installed") from exc

        if environment == ENVIRONMENT_SANDBOX:
            apple_environment = Environment.SANDBOX
            app_apple_id = None
        elif environment == ENVIRONMENT_PRODUCTION:
            apple_environment = Environment.PRODUCTION
            app_apple_id = self.app_apple_id
        else:
            raise AppleVerificationFailed("unknown apple environment")

        self._verifiers[environment] = SignedDataVerifier(
            self.root_certificates,
            True,
            apple_environment,
            self.bundle_id,
            app_apple_id,
        )
        return self._verifiers[environment]

    def _verification_exception_type(self):
        try:
            from appstoreserverlibrary.signed_data_verifier import VerificationException
        except ModuleNotFoundError as exc:
            raise AppleVerificationUnavailable("app-store-server-library is not installed") from exc
        return VerificationException

    def _is_retryable_verification_exception(self, exc: Exception) -> bool:
        status = getattr(exc, "status", None)
        try:
            from appstoreserverlibrary.signed_data_verifier import VerificationStatus
        except ModuleNotFoundError as import_exc:
            raise AppleVerificationUnavailable("app-store-server-library is not installed") from import_exc
        return status == VerificationStatus.RETRYABLE_VERIFICATION_FAILURE

    def _raise_for_verification_exception(self, exc: Exception) -> None:
        if self._is_retryable_verification_exception(exc):
            raise AppleVerificationUnavailable("apple signed payload verification is temporarily unavailable") from exc
        raise AppleVerificationFailed(
            "apple signed payload verification failed",
            apple_verification_status=_verification_status_name(exc),
        ) from exc


class OfficialSubscriptionStatusClient:
    def __init__(
        self,
        *,
        private_key: bytes,
        key_id: str,
        issuer_id: str,
        bundle_id: str,
        request_timeout_seconds: int,
    ):
        self.private_key = private_key
        self.key_id = key_id
        self.issuer_id = issuer_id
        self.bundle_id = bundle_id
        self.request_timeout_seconds = request_timeout_seconds
        self._clients: Dict[str, Any] = {}

    def get_all_subscription_statuses(
        self,
        any_transaction_id: str,
        environment: str,
    ) -> Sequence[AppleSubscriptionStatusItem]:
        client = self._client_for_environment(environment)
        try:
            response = client.get_all_subscription_statuses(any_transaction_id)
        except Exception as exc:
            raise AppleVerificationUnavailable("apple subscription status API failed") from exc
        return list(_status_items_from_response(response))

    def _client_for_environment(self, environment: str):
        if environment in self._clients:
            return self._clients[environment]

        try:
            import requests
            from appstoreserverlibrary.api_client import AppStoreServerAPIClient
            from appstoreserverlibrary.models.Environment import Environment
        except ModuleNotFoundError as exc:
            raise AppleVerificationUnavailable("app-store-server-library is not installed") from exc

        request_timeout_seconds = self.request_timeout_seconds

        class TimeoutAppStoreServerAPIClient(AppStoreServerAPIClient):
            def _execute_request(self, method, url, params, headers, json, data):
                return requests.request(
                    method,
                    url,
                    params=params,
                    headers=headers,
                    json=json,
                    data=data,
                    timeout=request_timeout_seconds,
                )

        if environment == ENVIRONMENT_SANDBOX:
            apple_environment = Environment.SANDBOX
        elif environment == ENVIRONMENT_PRODUCTION:
            apple_environment = Environment.PRODUCTION
        else:
            raise AppleVerificationFailed("unknown apple environment")

        self._clients[environment] = TimeoutAppStoreServerAPIClient(
            self.private_key,
            self.key_id,
            self.issuer_id,
            self.bundle_id,
            apple_environment,
        )
        return self._clients[environment]


def build_real_apple_verifier_from_config(
    config: AppleCredentialConfig,
    *,
    allowed_products: Sequence[str],
    request_timeout_seconds: int,
) -> AppStoreServerAppleVerifier:
    if not config.is_complete:
        raise ValueError("Apple credentials are incomplete")
    private_key = read_binary_file(config.private_key_path)
    root_certificates = [read_binary_file(path) for path in config.root_certificate_paths]
    signed_payload_verifier = OfficialSignedDataVerifier(
        root_certificates=root_certificates,
        bundle_id=config.bundle_id,
        app_apple_id=config.app_apple_id,
    )
    subscription_status_client = OfficialSubscriptionStatusClient(
        private_key=private_key,
        key_id=config.key_id,
        issuer_id=config.issuer_id,
        bundle_id=config.bundle_id,
        request_timeout_seconds=request_timeout_seconds,
    )
    return AppStoreServerAppleVerifier(
        allowed_products=allowed_products,
        bundle_id=config.bundle_id,
        signed_payload_verifier=signed_payload_verifier,
        subscription_status_client=subscription_status_client,
    )


def read_binary_file(path: Optional[str]) -> bytes:
    if path is None:
        raise ValueError("path is required")
    with open(path, "rb") as handle:
        return handle.read()


def _verification_status_name(exc: Exception) -> Optional[str]:
    status = getattr(exc, "status", None)
    if status is None:
        return None
    name = getattr(status, "name", None)
    if isinstance(name, str) and name:
        return name
    value = getattr(status, "value", None)
    if value is not None:
        return str(value)
    return str(status)


def _format_verification_statuses(
    errors: Sequence[tuple[str, Exception, Optional[str]]],
) -> Optional[str]:
    if not errors:
        return None
    return ",".join(f"{environment}:{status or 'UNKNOWN'}" for environment, _, status in errors)


def _transaction_from_apple_payload(payload: Any) -> DecodedAppleTransaction:
    return DecodedAppleTransaction(
        original_transaction_id=_required_text(payload, "originalTransactionId"),
        transaction_id=_required_text(payload, "transactionId"),
        product_id=_required_text(payload, "productId"),
        bundle_id=_required_text(payload, "bundleId"),
        app_account_token=_optional_text(payload, "appAccountToken"),
        environment=normalize_environment(_read_attr(payload, "environment")),
        expires_date_ms=_optional_int(payload, "expiresDate"),
        revocation_date_ms=_optional_int(payload, "revocationDate"),
    )


def _renewal_from_apple_payload(payload: Any) -> DecodedAppleRenewalInfo:
    environment = _read_attr(payload, "environment")
    return DecodedAppleRenewalInfo(
        product_id=_optional_text(payload, "productId"),
        auto_renew_product_id=_optional_text(payload, "autoRenewProductId"),
        environment=normalize_environment(environment) if environment is not None else None,
        is_in_billing_retry_period=_optional_bool(payload, "isInBillingRetryPeriod"),
        grace_period_expires_date_ms=_optional_int(payload, "gracePeriodExpiresDate"),
    )


def _status_items_from_response(response: Any) -> Iterable[AppleSubscriptionStatusItem]:
    for group in _read_attr(response, "data") or []:
        for item in _read_attr(group, "lastTransactions") or []:
            yield AppleSubscriptionStatusItem(
                status=_read_attr(item, "status"),
                original_transaction_id=_optional_text(item, "originalTransactionId"),
                signed_transaction_info=_required_text(item, "signedTransactionInfo"),
                signed_renewal_info=_optional_text(item, "signedRenewalInfo"),
            )


def normalize_environment(value: Any) -> str:
    raw = getattr(value, "value", value)
    if raw in {ENVIRONMENT_SANDBOX, "Sandbox"}:
        return ENVIRONMENT_SANDBOX
    if raw in {ENVIRONMENT_PRODUCTION, "Production"}:
        return ENVIRONMENT_PRODUCTION
    raise AppleVerificationFailed("unknown apple environment")


def _read_attr(payload: Any, name: str) -> Any:
    return getattr(payload, name, None)


def _required_text(payload: Any, name: str) -> str:
    value = _optional_text(payload, name)
    if value is None:
        raise AppleVerificationFailed(f"apple payload missing {name}")
    return value


def _optional_text(payload: Any, name: str) -> Optional[str]:
    value = _read_attr(payload, name)
    if value is None:
        return None
    return str(value)


def _optional_int(payload: Any, name: str) -> Optional[int]:
    value = _read_attr(payload, name)
    if value is None:
        return None
    if isinstance(value, int) and not isinstance(value, bool):
        return value
    raise AppleVerificationFailed(f"apple payload {name} must be an integer")


def _optional_bool(payload: Any, name: str) -> Optional[bool]:
    value = _read_attr(payload, name)
    if value is None:
        return None
    if isinstance(value, bool):
        return value
    raise AppleVerificationFailed(f"apple payload {name} must be a boolean")
