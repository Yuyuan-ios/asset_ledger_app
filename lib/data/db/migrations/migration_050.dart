part of '../db_migrations.dart';

/// v50：新增 Track B / B3 本地 sync_conflicts 冲突复核队列表。
///
/// 该表只保存客户端本地待复核冲突，不纳入业务备份；重复远端变更通过
/// (entity_type, entity_id, remote_server_seq) 唯一约束幂等去重。
class Migration050 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 50) {
      await ensureSyncConflictsSchema(db);
    }
  }

  static Future<void> ensureSyncConflictsSchema(Database db) async {
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
  }
}
