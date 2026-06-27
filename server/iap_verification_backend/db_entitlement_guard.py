from __future__ import annotations

import contextlib
import sqlite3
from typing import Iterator, Optional

from http_helpers import utc_now_iso
from runtime_write_firewall import RBL_VIOLATION_LOG, RuntimeWriteContext


GUARD_TABLE = "iap_runtime_write_guard"
PROTECTED_TABLES = (
    "iap_entitlements",
    "iap_subscription_state",
    "subscription_state",
    "entitlement_table",
)


class DbEntitlementGuard:
    """SQLite soft guard for entitlement/state table mutation."""

    @staticmethod
    def install(conn: sqlite3.Connection) -> None:
        conn.execute(
            f"""
            CREATE TABLE IF NOT EXISTS {GUARD_TABLE} (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              active INTEGER NOT NULL DEFAULT 0,
              source TEXT,
              operation TEXT,
              table_name TEXT,
              actor TEXT,
              updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            f"""
            INSERT OR IGNORE INTO {GUARD_TABLE} (
              id, active, source, operation, table_name, actor, updated_at
            ) VALUES (1, 0, NULL, NULL, NULL, NULL, ?)
            """,
            (utc_now_iso(),),
        )
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
    @contextlib.contextmanager
    def scoped_write(
        conn: sqlite3.Connection,
        context: RuntimeWriteContext,
        *,
        table_name: str,
        operation: str,
    ) -> Iterator[None]:
        DbEntitlementGuard.enable(conn, context, table_name=table_name, operation=operation)
        try:
            yield
        finally:
            DbEntitlementGuard.disable(conn)

    @staticmethod
    def enable(
        conn: sqlite3.Connection,
        context: RuntimeWriteContext,
        *,
        table_name: str,
        operation: str,
    ) -> None:
        conn.execute(
            f"""
            UPDATE {GUARD_TABLE}
            SET active = 1,
                source = ?,
                operation = ?,
                table_name = ?,
                actor = ?,
                updated_at = ?
            WHERE id = 1
            """,
            (
                context.source,
                operation,
                table_name,
                context.actor,
                utc_now_iso(),
            ),
        )

    @staticmethod
    def disable(conn: sqlite3.Connection) -> None:
        conn.execute(
            f"""
            UPDATE {GUARD_TABLE}
            SET active = 0,
                source = NULL,
                operation = NULL,
                table_name = NULL,
                actor = NULL,
                updated_at = ?
            WHERE id = 1
            """,
            (utc_now_iso(),),
        )

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
                WHEN COALESCE((SELECT active FROM {GUARD_TABLE} WHERE id = 1), 0) != 1
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
                  SELECT RAISE(IGNORE);
                END
                """
            )

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
