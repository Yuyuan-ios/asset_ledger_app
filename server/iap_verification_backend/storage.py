from __future__ import annotations

import dataclasses
import os
import sqlite3
from contextlib import closing
from enum import Enum
from typing import Any, Optional

from db_entitlement_guard import DbEntitlementGuard
from http_helpers import utc_now_iso
from runtime_write_firewall import RblViolation, RuntimeWriteContext, RuntimeWriteFirewall
from verifier import EntitlementRecord


class EntitlementClaimConflict(Exception):
    pass


class PurchaseTransactionReplay(Exception):
    pass


@dataclasses.dataclass(frozen=True)
class SubscriptionStateRecord:
    user_id: str
    product_id: str
    state: str
    authority_score: int
    event_time: Optional[str]
    event_version: int
    channel: str
    transaction_id: str
    updated_at: str

    @classmethod
    def from_row(cls, row: sqlite3.Row) -> "SubscriptionStateRecord":
        return cls(
            user_id=str(row["user_id"]),
            product_id=str(row["product_id"]),
            state=str(row["state"]),
            authority_score=int(row["authority_score"]),
            event_time=row["event_time"],
            event_version=int(row["event_version"]),
            channel=str(row["channel"]),
            transaction_id=str(row["transaction_id"]),
            updated_at=str(row["updated_at"]),
        )


class EntitlementBindingPolicy(str, Enum):
    BIND_ONLY_IF_UNBOUND = "BIND_ONLY_IF_UNBOUND"
    NEVER_OVERWRITE_DIFFERENT_USER = "NEVER_OVERWRITE_DIFFERENT_USER"
    TRANSACTION_IS_VERIFICATION_ONLY = "TRANSACTION_IS_VERIFICATION_ONLY"


ENTITLEMENT_BINDING_POLICIES = (
    EntitlementBindingPolicy.BIND_ONLY_IF_UNBOUND,
    EntitlementBindingPolicy.NEVER_OVERWRITE_DIFFERENT_USER,
    EntitlementBindingPolicy.TRANSACTION_IS_VERIFICATION_ONLY,
)


class EntitlementStore:
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
        with closing(self._connect()) as conn:
            with conn:
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS iap_entitlements (
                      app_account_token TEXT PRIMARY KEY,
                      entitlement_tier TEXT NOT NULL,
                      original_transaction_id TEXT,
                      latest_transaction_id TEXT,
                      product_id TEXT,
                      environment TEXT,
                      expires_at TEXT,
                      revoked_at TEXT,
                      outcome TEXT NOT NULL,
                      updated_at TEXT NOT NULL,
                      user_id TEXT
                    )
                    """
                )
                columns = {
                    row["name"]
                    for row in conn.execute("PRAGMA table_info(iap_entitlements)").fetchall()
                }
                if "user_id" not in columns:
                    conn.execute("ALTER TABLE iap_entitlements ADD COLUMN user_id TEXT")
                conn.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_iap_entitlements_updated_at
                    ON iap_entitlements(updated_at)
                    """
                )
                conn.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_iap_entitlements_user_id
                    ON iap_entitlements(user_id)
                    """
                )
                conn.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_iap_entitlements_user_id_updated_at
                    ON iap_entitlements(user_id, updated_at)
                    """
                )
                conn.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_iap_entitlements_original_transaction_id
                    ON iap_entitlements(original_transaction_id)
                    """
                )
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS iap_purchase_transactions (
                      transaction_id TEXT PRIMARY KEY,
                      channel TEXT NOT NULL,
                      user_id TEXT NOT NULL,
                      product_id TEXT NOT NULL,
                      payload_hash TEXT NOT NULL,
                      entitlement_tier TEXT NOT NULL,
                      processed_at TEXT NOT NULL
                    )
                    """
                )
                conn.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_iap_purchase_transactions_user_id
                    ON iap_purchase_transactions(user_id)
                    """
                )
                conn.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_iap_purchase_transactions_channel
                    ON iap_purchase_transactions(channel)
                    """
                )
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS iap_subscription_state (
                      user_id TEXT NOT NULL,
                      product_id TEXT NOT NULL,
                      state TEXT NOT NULL,
                      authority_score INTEGER NOT NULL,
                      event_time TEXT,
                      event_version INTEGER NOT NULL,
                      channel TEXT NOT NULL,
                      transaction_id TEXT NOT NULL,
                      updated_at TEXT NOT NULL,
                      PRIMARY KEY (user_id, product_id)
                    )
                    """
                )
                conn.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_iap_subscription_state_updated_at
                    ON iap_subscription_state(updated_at)
                    """
                )
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS iap_subscription_event_versions (
                      user_id TEXT PRIMARY KEY,
                      version INTEGER NOT NULL
                    )
                    """
                )
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS iap_subscription_audit_log (
                      id INTEGER PRIMARY KEY AUTOINCREMENT,
                      log_type TEXT NOT NULL,
                      user_id TEXT NOT NULL,
                      product_id TEXT NOT NULL,
                      channel TEXT NOT NULL,
                      authority_score INTEGER NOT NULL,
                      previous_state TEXT,
                      new_state TEXT,
                      event_time TEXT,
                      server_time TEXT NOT NULL,
                      transaction_id TEXT NOT NULL,
                      reason TEXT NOT NULL,
                      raw_payload_json TEXT NOT NULL
                    )
                    """
                )
                conn.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_iap_subscription_audit_log_user_product
                    ON iap_subscription_audit_log(user_id, product_id, id)
                    """
                )
                conn.execute(
                    """
                    CREATE TRIGGER IF NOT EXISTS prevent_iap_subscription_audit_log_update
                    BEFORE UPDATE ON iap_subscription_audit_log
                    BEGIN
                      SELECT RAISE(ABORT, 'iap_subscription_audit_log is append-only');
                    END
                    """
                )
                conn.execute(
                    """
                    CREATE TRIGGER IF NOT EXISTS prevent_iap_subscription_audit_log_delete
                    BEFORE DELETE ON iap_subscription_audit_log
                    BEGIN
                      SELECT RAISE(ABORT, 'iap_subscription_audit_log is append-only');
                    END
                    """
                )
                DbEntitlementGuard.install(conn)

    def before_write(
        self,
        context: Optional[RuntimeWriteContext],
        *,
        table_name: str,
        operation: str,
        conn: sqlite3.Connection,
    ) -> RuntimeWriteContext:
        active_context = context or RuntimeWriteFirewall.current_context()
        if active_context is not None:
            active_context = active_context.for_table(table_name)
        try:
            RuntimeWriteFirewall.enforce(active_context)
        except RblViolation as exc:
            DbEntitlementGuard.log_block(
                conn,
                active_context,
                table_name=table_name,
                operation=operation,
                reason=f"rbl_blocked_{operation}_{table_name}",
            )
            raise
        if active_context is None:
            raise RblViolation("RBL VIOLATION: unauthorized entitlement write attempt")
        return active_context

    def upsert_entitlement(
        self,
        record: EntitlementRecord,
        user_id: Optional[str] = None,
        write_context: Optional[RuntimeWriteContext] = None,
    ) -> EntitlementRecord:
        updated_at = record.updated_at or utc_now_iso()
        # Only a server-verified login-bound user_id may bind an entitlement.
        # transaction.appAccountToken and record.user_id are verification data,
        # not account-binding authority.
        normalized_user_id = _normalize_user_id(user_id)
        persisted = EntitlementRecord(
            outcome=record.outcome,
            entitlement_tier=record.entitlement_tier,
            app_account_token=record.app_account_token,
            product_id=record.product_id,
            original_transaction_id=record.original_transaction_id,
            latest_transaction_id=record.latest_transaction_id,
            environment=record.environment,
            expires_at=record.expires_at,
            revoked_at=record.revoked_at,
            updated_at=updated_at,
            user_id=normalized_user_id,
        )
        with closing(self._connect()) as conn:
            active_context = self.before_write(
                write_context,
                table_name="iap_entitlements",
                operation="upsert_entitlement",
                conn=conn,
            )
            with conn:
                with DbEntitlementGuard.scoped_write(
                    conn,
                    active_context,
                    table_name="iap_entitlements",
                    operation="upsert_entitlement",
                ):
                    if persisted.user_id:
                        existing_app_token_user_id = _normalize_user_id(
                            self._claim_user_id_for_app_account_token(
                                conn,
                                persisted.app_account_token,
                            )
                        )
                        if existing_app_token_user_id and existing_app_token_user_id != persisted.user_id:
                            raise EntitlementClaimConflict(
                                "app account token is already bound to another user"
                            )
                    if persisted.user_id and persisted.original_transaction_id:
                        existing_original_user_id = _normalize_user_id(
                            self._claim_user_id_for_original_transaction(
                                conn,
                                persisted.original_transaction_id,
                            )
                        )
                        if existing_original_user_id and existing_original_user_id != persisted.user_id:
                            raise EntitlementClaimConflict(
                                "original transaction is already bound to another user"
                            )
                    conn.execute(
                        """
                        INSERT INTO iap_entitlements (
                          app_account_token, entitlement_tier, original_transaction_id,
                          latest_transaction_id, product_id, environment, expires_at,
                          revoked_at, outcome, updated_at, user_id
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        ON CONFLICT(app_account_token) DO UPDATE SET
                          entitlement_tier = excluded.entitlement_tier,
                          original_transaction_id = excluded.original_transaction_id,
                          latest_transaction_id = excluded.latest_transaction_id,
                          product_id = excluded.product_id,
                          environment = excluded.environment,
                          expires_at = excluded.expires_at,
                          revoked_at = excluded.revoked_at,
                          outcome = excluded.outcome,
                          updated_at = excluded.updated_at,
                          user_id = COALESCE(NULLIF(TRIM(iap_entitlements.user_id), ''), excluded.user_id)
                        """,
                        (
                            persisted.app_account_token,
                            persisted.entitlement_tier,
                            persisted.original_transaction_id,
                            persisted.latest_transaction_id,
                            persisted.product_id,
                            persisted.environment,
                            persisted.expires_at,
                            persisted.revoked_at,
                            persisted.outcome,
                            persisted.updated_at,
                            persisted.user_id,
                        ),
                    )
        return self.get_entitlement(persisted.app_account_token) or persisted

    def get_entitlement(self, app_account_token: str) -> Optional[EntitlementRecord]:
        with closing(self._connect()) as conn:
            with conn:
                row = conn.execute(
                    """
                    SELECT *
                    FROM iap_entitlements
                    WHERE app_account_token = ?
                    """,
                    (app_account_token,),
                ).fetchone()
        return EntitlementRecord.from_row(row) if row is not None else None

    def get_latest_entitlement_for_user(self, user_id: str) -> Optional[EntitlementRecord]:
        normalized_user_id = _normalize_user_id(user_id)
        if not normalized_user_id:
            return None
        with closing(self._connect()) as conn:
            with conn:
                row = conn.execute(
                    """
                    SELECT *
                    FROM iap_entitlements
                    WHERE user_id = ?
                    ORDER BY updated_at DESC
                    LIMIT 1
                    """,
                    (normalized_user_id,),
                ).fetchone()
        return EntitlementRecord.from_row(row) if row is not None else None

    def get_latest_max_entitlement_for_user(self, user_id: str) -> Optional[EntitlementRecord]:
        normalized_user_id = _normalize_user_id(user_id)
        if not normalized_user_id:
            return None
        with closing(self._connect()) as conn:
            with conn:
                row = conn.execute(
                    """
                    SELECT *
                    FROM iap_entitlements
                    WHERE user_id = ?
                      AND (
                        entitlement_tier = 'max'
                        OR product_id LIKE '%.max.yearly'
                      )
                      AND outcome != 'verificationFailed'
                    ORDER BY updated_at DESC
                    LIMIT 1
                    """,
                    (normalized_user_id,),
                ).fetchone()
        return EntitlementRecord.from_row(row) if row is not None else None

    def record_purchase_transaction(
        self,
        *,
        transaction_id: str,
        channel: str,
        user_id: str,
        product_id: str,
        payload_hash: str,
        entitlement_tier: str,
    ) -> bool:
        normalized_transaction_id = _normalize_required(transaction_id, "transaction_id")
        normalized_channel = _normalize_required(channel, "channel")
        normalized_user_id = _normalize_required(user_id, "user_id")
        normalized_product_id = _normalize_required(product_id, "product_id")
        normalized_payload_hash = _normalize_required(payload_hash, "payload_hash")
        normalized_tier = _normalize_required(entitlement_tier, "entitlement_tier")
        with closing(self._connect()) as conn:
            with conn:
                existing = conn.execute(
                    """
                    SELECT payload_hash
                    FROM iap_purchase_transactions
                    WHERE transaction_id = ?
                    """,
                    (normalized_transaction_id,),
                ).fetchone()
                if existing is not None:
                    if existing["payload_hash"] == normalized_payload_hash:
                        return False
                    raise PurchaseTransactionReplay(
                        "transaction_id already exists with a different payload"
                    )
                conn.execute(
                    """
                    INSERT INTO iap_purchase_transactions (
                      transaction_id, channel, user_id, product_id,
                      payload_hash, entitlement_tier, processed_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        normalized_transaction_id,
                        normalized_channel,
                        normalized_user_id,
                        normalized_product_id,
                        normalized_payload_hash,
                        normalized_tier,
                        utc_now_iso(),
                    ),
                )
        return True

    def get_subscription_state(
        self,
        user_id: str,
        product_id: str,
    ) -> Optional[SubscriptionStateRecord]:
        normalized_user_id = _normalize_required(user_id, "user_id")
        normalized_product_id = _normalize_required(product_id, "product_id")
        with closing(self._connect()) as conn:
            with conn:
                row = conn.execute(
                    """
                    SELECT *
                    FROM iap_subscription_state
                    WHERE user_id = ?
                      AND product_id = ?
                    """,
                    (normalized_user_id, normalized_product_id),
                ).fetchone()
        return SubscriptionStateRecord.from_row(row) if row is not None else None

    def upsert_subscription_state(
        self,
        *,
        user_id: str,
        product_id: str,
        state: str,
        authority_score: int,
        event_time: Optional[str],
        event_version: int,
        channel: str,
        transaction_id: str,
        write_context: Optional[RuntimeWriteContext] = None,
    ) -> SubscriptionStateRecord:
        normalized_user_id = _normalize_required(user_id, "user_id")
        normalized_product_id = _normalize_required(product_id, "product_id")
        normalized_state = _normalize_required(state, "state")
        normalized_channel = _normalize_required(channel, "channel")
        normalized_transaction_id = _normalize_required(transaction_id, "transaction_id")
        normalized_authority_score = int(authority_score)
        normalized_event_version = int(event_version)
        updated_at = utc_now_iso()
        with closing(self._connect()) as conn:
            active_context = self.before_write(
                write_context,
                table_name="iap_subscription_state",
                operation="upsert_subscription_state",
                conn=conn,
            )
            with conn:
                with DbEntitlementGuard.scoped_write(
                    conn,
                    active_context,
                    table_name="iap_subscription_state",
                    operation="upsert_subscription_state",
                ):
                    conn.execute(
                        """
                        INSERT INTO iap_subscription_state (
                          user_id, product_id, state, authority_score, event_time,
                          event_version, channel, transaction_id, updated_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                        ON CONFLICT(user_id, product_id) DO UPDATE SET
                          state = excluded.state,
                          authority_score = excluded.authority_score,
                          event_time = excluded.event_time,
                          event_version = excluded.event_version,
                          channel = excluded.channel,
                          transaction_id = excluded.transaction_id,
                          updated_at = excluded.updated_at
                        """,
                        (
                            normalized_user_id,
                            normalized_product_id,
                            normalized_state,
                            normalized_authority_score,
                            _normalize_optional_text(event_time),
                            normalized_event_version,
                            normalized_channel,
                            normalized_transaction_id,
                            updated_at,
                        ),
                    )
        record = self.get_subscription_state(normalized_user_id, normalized_product_id)
        if record is None:
            raise sqlite3.DatabaseError("subscription state write failed")
        return record

    def next_subscription_event_version(self, user_id: str) -> int:
        normalized_user_id = _normalize_required(user_id, "user_id")
        with closing(self._connect()) as conn:
            with conn:
                conn.execute(
                    """
                    INSERT INTO iap_subscription_event_versions (user_id, version)
                    VALUES (?, 1)
                    ON CONFLICT(user_id) DO UPDATE SET
                      version = version + 1
                    """,
                    (normalized_user_id,),
                )
                row = conn.execute(
                    """
                    SELECT version
                    FROM iap_subscription_event_versions
                    WHERE user_id = ?
                    """,
                    (normalized_user_id,),
                ).fetchone()
        return int(row["version"])

    def append_subscription_audit_log(
        self,
        *,
        log_type: str,
        user_id: str,
        product_id: str,
        channel: str,
        authority_score: int,
        previous_state: Optional[str],
        new_state: Optional[str],
        event_time: Optional[str],
        transaction_id: str,
        reason: str,
        raw_payload_json: str,
    ) -> int:
        with closing(self._connect()) as conn:
            with conn:
                cursor = conn.execute(
                    """
                    INSERT INTO iap_subscription_audit_log (
                      log_type, user_id, product_id, channel, authority_score,
                      previous_state, new_state, event_time, server_time,
                      transaction_id, reason, raw_payload_json
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        _normalize_required(log_type, "log_type"),
                        _normalize_required(user_id, "user_id"),
                        _normalize_required(product_id, "product_id"),
                        _normalize_required(channel, "channel"),
                        int(authority_score),
                        _normalize_optional_text(previous_state),
                        _normalize_optional_text(new_state),
                        _normalize_optional_text(event_time),
                        utc_now_iso(),
                        _normalize_required(transaction_id, "transaction_id"),
                        _normalize_required(reason, "reason"),
                        _normalize_required(raw_payload_json, "raw_payload_json"),
                    ),
                )
                return int(cursor.lastrowid)

    def list_subscription_audit_log(
        self,
        log_type: Optional[str] = None,
    ) -> list[dict[str, Any]]:
        with closing(self._connect()) as conn:
            with conn:
                if log_type is None:
                    rows = conn.execute(
                        """
                        SELECT *
                        FROM iap_subscription_audit_log
                        ORDER BY id ASC
                        """
                    ).fetchall()
                else:
                    rows = conn.execute(
                        """
                        SELECT *
                        FROM iap_subscription_audit_log
                        WHERE log_type = ?
                        ORDER BY id ASC
                        """,
                        (_normalize_required(log_type, "log_type"),),
                    ).fetchall()
        return [dict(row) for row in rows]

    def list_active_entitlements(self) -> list[EntitlementRecord]:
        with closing(self._connect()) as conn:
            with conn:
                rows = conn.execute(
                    """
                    SELECT *
                    FROM iap_entitlements
                    WHERE entitlement_tier != 'none'
                      AND outcome IN (
                        'verifiedActivePro',
                        'verifiedActiveMax',
                        'verifiedGracePeriodPro',
                        'verifiedGracePeriodMax'
                      )
                    ORDER BY updated_at ASC
                    """
                ).fetchall()
        return [EntitlementRecord.from_row(row) for row in rows]

    def _claim_user_id_for_original_transaction(
        self,
        conn: sqlite3.Connection,
        original_transaction_id: str,
    ) -> Optional[str]:
        row = conn.execute(
            """
            SELECT user_id
            FROM iap_entitlements
            WHERE original_transaction_id = ?
              AND user_id IS NOT NULL
              AND TRIM(user_id) != ''
            ORDER BY updated_at DESC
            LIMIT 1
            """,
            (original_transaction_id,),
        ).fetchone()
        if row is None:
            return None
        return row["user_id"]

    def _claim_user_id_for_app_account_token(
        self,
        conn: sqlite3.Connection,
        app_account_token: str,
    ) -> Optional[str]:
        row = conn.execute(
            """
            SELECT user_id
            FROM iap_entitlements
            WHERE app_account_token = ?
              AND user_id IS NOT NULL
              AND TRIM(user_id) != ''
            LIMIT 1
            """,
            (app_account_token,),
        ).fetchone()
        if row is None:
            return None
        return row["user_id"]


def _normalize_user_id(user_id: Optional[str]) -> Optional[str]:
    if not isinstance(user_id, str):
        return None
    normalized = user_id.strip()
    return normalized or None


def _normalize_required(value: str, field_name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{field_name} is required")
    return value.strip()


def _normalize_optional_text(value: Optional[str]) -> Optional[str]:
    if not isinstance(value, str):
        return None
    normalized = value.strip()
    return normalized or None
