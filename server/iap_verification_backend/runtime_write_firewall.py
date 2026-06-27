from __future__ import annotations

import contextlib
import contextvars
import dataclasses
import hashlib
import hmac
import inspect
import json
import os
import secrets
from typing import Iterator, Optional

from gateway_single_writer_enforcer import GATEWAY_WRITER_SOURCE, SingleWriterEnforcer


RBL_VIOLATION_LOG = "rbl_violation_log"
RECONCILIATION_WRITER_SOURCE = "subscription_reconciliation_worker.py"
INTERNAL_ADMIN_WRITER_SOURCE = "internal_system_admin_job"


@dataclasses.dataclass(frozen=True)
class RuntimeWriteContext:
    source: str
    operation: str
    table: Optional[str] = None
    route: Optional[str] = None
    actor: Optional[str] = None
    user_id: Optional[str] = None
    product_id: Optional[str] = None
    transaction_id: Optional[str] = None
    system_job: bool = False
    explicit_admin: bool = False
    context_token: Optional[str] = dataclasses.field(default=None, repr=False)

    @classmethod
    def gateway(
        cls,
        *,
        operation: str,
        route: Optional[str] = None,
        user_id: Optional[str] = None,
        product_id: Optional[str] = None,
        transaction_id: Optional[str] = None,
    ) -> "RuntimeWriteContext":
        return RuntimeSystemContextSigner.seal(
            cls(
                source=GATEWAY_WRITER_SOURCE,
                operation=operation,
                route=route,
                actor="subscription_gateway",
                user_id=user_id,
                product_id=product_id,
                transaction_id=transaction_id,
            )
        )

    @classmethod
    def reconciliation_job(
        cls,
        *,
        operation: str,
        user_id: Optional[str] = None,
        product_id: Optional[str] = None,
        transaction_id: Optional[str] = None,
    ) -> "RuntimeWriteContext":
        return RuntimeSystemContextSigner.seal(
            cls(
                source=RECONCILIATION_WRITER_SOURCE,
                operation=operation,
                actor="reconciliation_worker",
                user_id=user_id,
                product_id=product_id,
                transaction_id=transaction_id,
                system_job=True,
            )
        )

    @classmethod
    def internal_admin_job(
        cls,
        *,
        operation: str,
        user_id: Optional[str] = None,
        product_id: Optional[str] = None,
        transaction_id: Optional[str] = None,
    ) -> "RuntimeWriteContext":
        return RuntimeSystemContextSigner.seal(
            cls(
                source=INTERNAL_ADMIN_WRITER_SOURCE,
                operation=operation,
                actor="internal_system_admin_job",
                user_id=user_id,
                product_id=product_id,
                transaction_id=transaction_id,
                system_job=True,
                explicit_admin=True,
            )
        )

    def for_table(self, table: str) -> "RuntimeWriteContext":
        return dataclasses.replace(self, table=table)

    def to_json(self) -> str:
        return json.dumps(
            dataclasses.asdict(self),
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=True,
        )


class RblViolation(RuntimeError):
    pass


class RuntimeSystemContextSigner:
    _secret = secrets.token_bytes(32)
    _allowed_callers = {
        GATEWAY_WRITER_SOURCE: {"subscription_gateway.py"},
        RECONCILIATION_WRITER_SOURCE: {"subscription_reconciliation_worker.py"},
        INTERNAL_ADMIN_WRITER_SOURCE: {"subscription_storage_gateway.py"},
    }

    @classmethod
    def seal(cls, context: RuntimeWriteContext) -> RuntimeWriteContext:
        caller = cls._external_caller_file()
        allowed_callers = cls._allowed_callers.get(context.source, set())
        if caller not in allowed_callers:
            raise RblViolation("RBL VIOLATION: unauthorized write context signer")
        return dataclasses.replace(context, context_token=cls._signature(context))

    @classmethod
    def verify(cls, context: RuntimeWriteContext) -> bool:
        token = context.context_token
        if not isinstance(token, str) or not token:
            return False
        expected = cls._signature(dataclasses.replace(context, context_token=None))
        return hmac.compare_digest(token, expected)

    @classmethod
    def _signature(cls, context: RuntimeWriteContext) -> str:
        signable_context = dataclasses.replace(context, table=None, context_token=None)
        payload = json.dumps(
            dataclasses.asdict(signable_context),
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=True,
        ).encode("utf-8")
        return hmac.new(cls._secret, payload, hashlib.sha256).hexdigest()

    @staticmethod
    def _external_caller_file() -> str:
        for frame_info in inspect.stack()[2:]:
            file_name = os.path.basename(frame_info.filename)
            if file_name == "runtime_write_firewall.py":
                continue
            return file_name
        return ""


_ACTIVE_CONTEXT: contextvars.ContextVar[Optional[RuntimeWriteContext]] = contextvars.ContextVar(
    "fleet_ledger_runtime_write_context",
    default=None,
)


class RuntimeWriteFirewall:
    @staticmethod
    def current_context() -> Optional[RuntimeWriteContext]:
        return _ACTIVE_CONTEXT.get()

    @staticmethod
    @contextlib.contextmanager
    def activate(context: RuntimeWriteContext) -> Iterator[None]:
        RuntimeWriteFirewall.enforce(context)
        token = _ACTIVE_CONTEXT.set(context)
        try:
            yield
        finally:
            _ACTIVE_CONTEXT.reset(token)

    @staticmethod
    def allow_write(context: Optional[RuntimeWriteContext]) -> bool:
        if context is None:
            return False
        if context.explicit_admin and context.system_job:
            return RuntimeSystemContextSigner.verify(context)
        if context.source == GATEWAY_WRITER_SOURCE:
            SingleWriterEnforcer.assert_writer(context)
            return RuntimeSystemContextSigner.verify(context)
        if context.source == RECONCILIATION_WRITER_SOURCE and context.system_job:
            return RuntimeSystemContextSigner.verify(context)
        return False

    @staticmethod
    def enforce(context: Optional[RuntimeWriteContext]) -> None:
        try:
            allowed = RuntimeWriteFirewall.allow_write(context)
        except RuntimeError as exc:
            raise RblViolation(str(exc)) from exc
        if not allowed:
            RuntimeWriteFirewall.log_block(context)
            raise RblViolation("RBL VIOLATION: unauthorized entitlement write attempt")

    @staticmethod
    def log_block(context: Optional[RuntimeWriteContext]) -> None:
        # DB-backed audit is written by DbEntitlementGuard. This hook exists so
        # enforcement can be centrally observed or instrumented without changing
        # callers.
        return None
