from __future__ import annotations

import dataclasses
import os
import sqlite3
from contextlib import closing
from typing import Any, Dict, List

from http_helpers import HttpError


class ClosingSQLiteConnection(sqlite3.Connection):
    def __exit__(self, exc_type: object, exc_value: object, traceback: object) -> bool:
        result = super().__exit__(exc_type, exc_value, traceback)
        self.close()
        return result


@dataclasses.dataclass(frozen=True)
class BackupMetadata:
    backup_id: str
    user_id: str
    object_key: str
    db_schema_version: int
    payload_sha256: str
    payload_bytes: int
    created_at: str

    def public_json(self) -> Dict[str, Any]:
        return {
            "backup_id": self.backup_id,
            "created_at": self.created_at,
            "db_schema_version": self.db_schema_version,
            "payload_bytes": self.payload_bytes,
        }


class BackupMetadataStore:
    def __init__(self, db_path: str):
        self.db_path = db_path
        parent = os.path.dirname(os.path.abspath(db_path))
        if parent:
            os.makedirs(parent, exist_ok=True)
        self._init_schema()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path, factory=ClosingSQLiteConnection)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_schema(self) -> None:
        with closing(self._connect()) as conn:
            with conn:
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS backups (
                      backup_id TEXT PRIMARY KEY,
                      user_id TEXT NOT NULL,
                      object_key TEXT NOT NULL,
                      db_schema_version INTEGER NOT NULL,
                      payload_sha256 TEXT NOT NULL,
                      payload_bytes INTEGER NOT NULL,
                      created_at TEXT NOT NULL
                    )
                    """
                )
                conn.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_backups_user_created
                    ON backups(user_id, created_at DESC)
                    """
                )
                conn.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_backups_user_id
                    ON backups(user_id)
                    """
                )
                conn.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_backups_created_at
                    ON backups(created_at DESC)
                    """
                )

    def insert(self, metadata: BackupMetadata) -> None:
        with closing(self._connect()) as conn:
            with conn:
                conn.execute(
                    """
                    INSERT INTO backups (
                      backup_id, user_id, object_key, db_schema_version,
                      payload_sha256, payload_bytes, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        metadata.backup_id,
                        metadata.user_id,
                        metadata.object_key,
                        metadata.db_schema_version,
                        metadata.payload_sha256,
                        metadata.payload_bytes,
                        metadata.created_at,
                    ),
                )

    def list_for_user(self, user_id: str) -> List[BackupMetadata]:
        with closing(self._connect()) as conn:
            with conn:
                rows = conn.execute(
                    """
                    SELECT * FROM backups
                    WHERE user_id = ?
                    ORDER BY created_at DESC, backup_id DESC
                    """,
                    (user_id,),
                ).fetchall()
        return [metadata_from_row(row) for row in rows]

    def get_for_user(self, user_id: str, backup_id: str) -> BackupMetadata:
        with closing(self._connect()) as conn:
            with conn:
                row = conn.execute(
                    "SELECT * FROM backups WHERE user_id = ? AND backup_id = ?",
                    (user_id, backup_id),
                ).fetchone()
        if row is None:
            raise HttpError(404, "not_found", "backup not found")
        return metadata_from_row(row)


def metadata_from_row(row: sqlite3.Row) -> BackupMetadata:
    return BackupMetadata(
        backup_id=row["backup_id"],
        user_id=row["user_id"],
        object_key=row["object_key"],
        db_schema_version=int(row["db_schema_version"]),
        payload_sha256=row["payload_sha256"],
        payload_bytes=int(row["payload_bytes"]),
        created_at=row["created_at"],
    )
