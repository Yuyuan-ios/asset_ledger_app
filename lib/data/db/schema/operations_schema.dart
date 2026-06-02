import 'package:sqflite/sqflite.dart';

/// 阶段 D Step 3：operation audit log 表。
///
/// 设计要点：
/// - append-only：repository 不提供 update / delete；schema 上不绑定外键，避免
///   业务表清理时把审计连带删掉（审计是“操作发生过”的事实，不应随业务回滚消失）。
/// - 不纳入业务备份/恢复：local backup 走正向白名单，本表不在名单里，restore
///   也不会清空本表（这是设备本地的操作历史）。
/// - JSON 字段为 [OperationEntityRef] / [OperationPreview] 的 toMap → jsonEncode
///   结果，供未来 audit / MCP / diff 工具结构化消费。
class OperationsSchema {
  static Future<void> create(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS operation_audit_logs (
        id TEXT PRIMARY KEY,
        operation_id TEXT NOT NULL,
        token_id TEXT,
        operation_type TEXT NOT NULL,
        actor_id TEXT,
        actor_type TEXT NOT NULL,
        source TEXT NOT NULL,
        created_at TEXT NOT NULL,
        entity_refs_json TEXT NOT NULL,
        preview_snapshot_json TEXT,
        before_snapshot_json TEXT,
        after_snapshot_json TEXT,
        confirmed INTEGER NOT NULL DEFAULT 0 CHECK (confirmed IN (0, 1)),
        result TEXT NOT NULL,
        error_message TEXT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_operation_audit_logs_operation_id
      ON operation_audit_logs(operation_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_operation_audit_logs_token_id
      ON operation_audit_logs(token_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_operation_audit_logs_created_at
      ON operation_audit_logs(created_at);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_operation_audit_logs_operation_type
      ON operation_audit_logs(operation_type);
    ''');
  }
}
