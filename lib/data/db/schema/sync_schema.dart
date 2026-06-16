import 'package:sqflite/sqflite.dart';

class SyncSchema {
  static Future<void> create(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        payload_hash TEXT NOT NULL,
        status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0 CHECK (retry_count >= 0),
        last_error TEXT,
        next_retry_at TEXT,
        transaction_group_id TEXT,
        local_sequence INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_outbox_status_created
      ON sync_outbox(status, created_at);
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_state (
        scope TEXT PRIMARY KEY,
        last_pull_cursor TEXT,
        pull_cursor INTEGER NOT NULL DEFAULT 0,
        last_push_at TEXT,
        last_success_at TEXT,
        last_error TEXT,
        gate_state TEXT,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS entity_sync_meta (
        entity_type TEXT NOT NULL,
        local_id TEXT NOT NULL,
        server_id TEXT,
        sync_status TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 0 CHECK (version >= 0),
        source TEXT NOT NULL,
        created_by TEXT,
        updated_by TEXT,
        deleted_at TEXT,
        payload_hash TEXT,
        last_synced_at TEXT,
        conflict_reason TEXT,
        PRIMARY KEY (entity_type, local_id)
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entity_sync_meta_server
      ON entity_sync_meta(entity_type, server_id);
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_conflicts (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        remote_server_seq INTEGER NOT NULL CHECK (remote_server_seq >= 0),
        remote_base_version INTEGER NOT NULL DEFAULT 0 CHECK (remote_base_version >= 0),
        remote_new_version INTEGER NOT NULL CHECK (remote_new_version >= 0),
        remote_payload_json TEXT NOT NULL,
        remote_payload_hash TEXT NOT NULL,
        remote_deleted INTEGER NOT NULL DEFAULT 0 CHECK (remote_deleted IN (0, 1)),
        conflict_reason TEXT NOT NULL,
        detected_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        resolution TEXT,
        resolved_at TEXT,
        UNIQUE(entity_type, entity_id, remote_server_seq)
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_conflicts_status_detected
      ON sync_conflicts(status, detected_at);
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS work_records (
        server_id TEXT,
        local_id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        driver_id TEXT,
        project_id TEXT,
        device_id TEXT,
        work_date INTEGER NOT NULL,
        work_type TEXT NOT NULL,
        hours_milli INTEGER NOT NULL CHECK (hours_milli >= 0),
        unit_price_fen INTEGER NOT NULL CHECK (unit_price_fen >= 0),
        amount_fen INTEGER NOT NULL CHECK (amount_fen >= 0),
        status TEXT NOT NULL,
        source TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 0 CHECK (version >= 0),
        created_by TEXT,
        updated_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        payload_hash TEXT NOT NULL,
        origin_fingerprint TEXT,
        reviewed_by TEXT,
        reviewed_at TEXT,
        reject_reason TEXT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_work_records_review_status
      ON work_records(status, work_date);
    ''');
  }
}
