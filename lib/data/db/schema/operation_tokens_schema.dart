import 'package:sqflite/sqflite.dart';

/// 阶段 D Step 47：operation_tokens 表（preview -> confirm -> execute 确认凭据落库）。
///
/// 设计要点（与 [OperationsSchema] 的 append-only 审计表刻意区分）：
/// - **可变状态机表**：issued -> consumed / cancelled / expired。与
///   `operation_audit_logs`（append-only 事实日志）职责分离，不能复用同一张表。
/// - **本地安全 / 会话状态**：operation_tokens **不进入用户备份白名单**
///   （见 `BackupRestoreTables`，本表不在 insertOrder/clearOrder/requiredColumns
///   中），导出不带、restore 也不清空；恢复后旧 token 靠 hash/freshness 自然失效。
/// - 不绑外键、不 cascade，避免迁移/恢复复杂化。
/// - `status` 与三个 bool 列带 CHECK 约束；DateTime 存 TEXT ISO8601；bool 存 0/1。
/// - `token_json` 保存 [OperationConfirmationToken] 的 toMap() JSON 全量快照，
///   是权威来源；其余列是为索引/查询而拍平的去规范化副本，必须与 token_json 一致。
class OperationTokensSchema {
  static Future<void> create(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS operation_tokens (
        id TEXT PRIMARY KEY,
        operation_id TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        actor_type TEXT NOT NULL,
        actor_id TEXT,
        delegated_actor_type TEXT,
        delegated_actor_id TEXT,
        session_id TEXT,
        source TEXT,
        created_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        consumed_at TEXT,
        cancelled_at TEXT,
        status TEXT NOT NULL
          CHECK (status IN ('issued', 'consumed', 'expired', 'cancelled')),
        input_hash TEXT NOT NULL,
        full_analysis_hash TEXT NOT NULL,
        redacted_preview_hash TEXT,
        actor_scope_hash TEXT NOT NULL,
        freshness_required INTEGER NOT NULL
          CHECK (freshness_required IN (0, 1)),
        requires_reanalysis_before_execute INTEGER NOT NULL
          CHECK (requires_reanalysis_before_execute IN (0, 1)),
        one_time_use INTEGER NOT NULL CHECK (one_time_use IN (0, 1)),
        token_json TEXT NOT NULL,
        last_error TEXT,
        metadata_json TEXT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_operation_tokens_operation_id
      ON operation_tokens(operation_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_operation_tokens_status_expires_at
      ON operation_tokens(status, expires_at);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_operation_tokens_actor_session
      ON operation_tokens(actor_type, actor_id, session_id);
    ''');
  }
}
