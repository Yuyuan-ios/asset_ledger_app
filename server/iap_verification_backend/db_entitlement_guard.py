from __future__ import annotations

import contextlib
import contextvars
import sqlite3
from typing import Iterator, Optional

from http_helpers import utc_now_iso
from runtime_write_firewall import RBL_VIOLATION_LOG, RuntimeWriteContext


PROTECTED_TABLES = (
    "iap_entitlements",
    "iap_subscription_state",
    "subscription_state",
    "entitlement_table",
)

_ACTIVE_DB_WRITE_CONTEXT: contextvars.ContextVar[Optional[RuntimeWriteContext]] = (
    contextvars.ContextVar("fleet_ledger_active_db_write_context", default=None)
)


class DbEntitlementGuard:
    """Connection-local SQLite guard for entitlement/state table mutation."""

    @staticmethod
    def install(conn: sqlite3.Connection) -> None:
        DbEntitlementGuard.register_connection(conn)
        existing_tables = {
            str(row["name"])
            for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            ).fetchall()
        }
        if "iap_subscription_audit_log" not in existing_tables:
            return
        for table_name in PROTECTED_TABLES:
            if table_name in existing_tables:
                DbEntitlementGuard._install_table_triggers(conn, table_name)

    @staticmethod
    def register_connection(conn: sqlite3.Connection) -> None:
        conn.create_function("rbl_write_allowed", 2, DbEntitlementGuard._write_allowed)

    @staticmethod
    @contextlib.contextmanager
    def scoped_write(
        conn: sqlite3.Connection,
        context: RuntimeWriteContext,
        *,
        table_name: str,
        operation: str,
    ) -> Iterator[None]:
        token = _ACTIVE_DB_WRITE_CONTEXT.set(
            context.for_table(table_name)
        )
        try:
            yield
        finally:
            _ACTIVE_DB_WRITE_CONTEXT.reset(token)

    @staticmethod
    def log_block(
        conn: sqlite3.Connection,
        context: Optional[RuntimeWriteContext],
        *,
        table_name: str,
        operation: str,
        reason: str,
    ) -> None:
        if context is None:
            context = RuntimeWriteContext(
                source="unknown",
                operation=operation,
                table=table_name,
                actor="unknown",
            )
        with conn:
            conn.execute(
                """
                INSERT INTO iap_subscription_audit_log (
                  log_type, user_id, product_id, channel, authority_score,
                  previous_state, new_state, event_time, server_time,
                  transaction_id, reason, raw_payload_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    RBL_VIOLATION_LOG,
                    _audit_value(context.user_id, "rbl-unknown-user"),
                    _audit_value(context.product_id, "rbl-unknown-product"),
                    _audit_value(context.actor or context.source, "rbl"),
                    0,
                    None,
                    None,
                    None,
                    utc_now_iso(),
                    _audit_value(context.transaction_id, f"rbl:{table_name}:{operation}"),
                    reason,
                    context.for_table(table_name).to_json(),
                ),
            )

    @staticmethod
    def _install_table_triggers(conn: sqlite3.Connection, table_name: str) -> None:
        for operation in ("insert", "update", "delete"):
            trigger_name = f"rbl_guard_{table_name}_{operation}"
            row_prefix = "NEW" if operation in {"insert", "update"} else "OLD"
            conn.execute(f"DROP TRIGGER IF EXISTS {trigger_name}")
            conn.execute(
                f"""
                CREATE TRIGGER {trigger_name}
                BEFORE {operation.upper()} ON {table_name}
                WHEN rbl_write_allowed('{table_name}', '{operation}') != 1
                BEGIN
                  INSERT INTO iap_subscription_audit_log (
                    log_type, user_id, product_id, channel, authority_score,
                    previous_state, new_state, event_time, server_time,
                    transaction_id, reason, raw_payload_json
                  ) VALUES (
                    '{RBL_VIOLATION_LOG}',
                    {DbEntitlementGuard._trigger_user_expr(table_name, row_prefix)},
                    {DbEntitlementGuard._trigger_product_expr(table_name, row_prefix)},
                    'db_entitlement_guard',
                    0,
                    NULL,
                    NULL,
                    NULL,
                    strftime('%Y-%m-%dT%H:%M:%fZ', 'now'),
                    {DbEntitlementGuard._trigger_transaction_expr(table_name, row_prefix)},
                    'rbl_blocked_direct_{operation}_{table_name}',
                    '{{"rblViolation":"direct_{operation}","table":"{table_name}"}}'
                  );
                  SELECT RAISE(FAIL, 'RBL VIOLATION: direct DB write blocked');
                END
                """
            )

    @staticmethod
    def _write_allowed(table_name: str, operation: str) -> int:
        context = _ACTIVE_DB_WRITE_CONTEXT.get()
        if context is None:
            return 0
        if context.table != table_name:
            return 0
        if not isinstance(operation, str) or not operation.strip():
            return 0
        return 1

    @staticmethod
    def _trigger_user_expr(table_name: str, row_prefix: str) -> str:
        if table_name in {"iap_entitlements", "iap_subscription_state", "subscription_state"}:
            return f"COALESCE(NULLIF(TRIM({row_prefix}.user_id), ''), 'rbl-unknown-user')"
        return "'rbl-unknown-user'"

    @staticmethod
    def _trigger_product_expr(table_name: str, row_prefix: str) -> str:
        if table_name in {"iap_entitlements", "iap_subscription_state", "subscription_state"}:
            return f"COALESCE(NULLIF(TRIM({row_prefix}.product_id), ''), 'rbl-unknown-product')"
        return "'rbl-unknown-product'"

    @staticmethod
    def _trigger_transaction_expr(table_name: str, row_prefix: str) -> str:
        if table_name == "iap_entitlements":
            return (
                f"COALESCE(NULLIF(TRIM({row_prefix}.latest_transaction_id), ''), "
                f"NULLIF(TRIM({row_prefix}.original_transaction_id), ''), "
                f"NULLIF(TRIM({row_prefix}.app_account_token), ''), "
                f"'rbl:{table_name}')"
            )
        if table_name in {"iap_subscription_state", "subscription_state"}:
            return f"COALESCE(NULLIF(TRIM({row_prefix}.transaction_id), ''), 'rbl:{table_name}')"
        return f"'rbl:{table_name}'"


def _audit_value(value: Optional[str], fallback: str) -> str:
    if not isinstance(value, str):
        return fallback
    normalized = value.strip()
    return normalized or fallback
