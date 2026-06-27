from __future__ import annotations

import os
import sqlite3
from contextlib import closing
from typing import Optional

from http_helpers import utc_now_iso
from verifier import EntitlementRecord


class EntitlementClaimConflict(Exception):
    pass


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

    def upsert_entitlement(
        self,
        record: EntitlementRecord,
        user_id: Optional[str] = None,
    ) -> EntitlementRecord:
        updated_at = record.updated_at or utc_now_iso()
        normalized_user_id = _normalize_user_id(user_id) or _normalize_user_id(record.user_id)
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
            with conn:
                if persisted.user_id and persisted.original_transaction_id:
                    existing_user_id = _normalize_user_id(
                        self._claim_user_id_for_original_transaction(
                            conn,
                            persisted.original_transaction_id,
                        )
                    )
                    if existing_user_id and existing_user_id != persisted.user_id:
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
                      user_id = COALESCE(excluded.user_id, iap_entitlements.user_id)
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


def _normalize_user_id(user_id: Optional[str]) -> Optional[str]:
    if not isinstance(user_id, str):
        return None
    normalized = user_id.strip()
    return normalized or None
