from __future__ import annotations

import os
import sqlite3
from contextlib import closing
from typing import Optional

from http_helpers import utc_now_iso
from verifier import EntitlementRecord


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
                      updated_at TEXT NOT NULL
                    )
                    """
                )
                conn.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_iap_entitlements_updated_at
                    ON iap_entitlements(updated_at)
                    """
                )

    def upsert_entitlement(self, record: EntitlementRecord) -> EntitlementRecord:
        updated_at = record.updated_at or utc_now_iso()
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
        )
        with closing(self._connect()) as conn:
            with conn:
                conn.execute(
                    """
                    INSERT INTO iap_entitlements (
                      app_account_token, entitlement_tier, original_transaction_id,
                      latest_transaction_id, product_id, environment, expires_at,
                      revoked_at, outcome, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(app_account_token) DO UPDATE SET
                      entitlement_tier = excluded.entitlement_tier,
                      original_transaction_id = excluded.original_transaction_id,
                      latest_transaction_id = excluded.latest_transaction_id,
                      product_id = excluded.product_id,
                      environment = excluded.environment,
                      expires_at = excluded.expires_at,
                      revoked_at = excluded.revoked_at,
                      outcome = excluded.outcome,
                      updated_at = excluded.updated_at
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
                    ),
                )
        return persisted

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
