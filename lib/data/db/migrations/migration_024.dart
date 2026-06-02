part of '../db_migrations.dart';

/// v24：operation_audit_logs 增加 nullable token_id。
///
/// 不加外键，不保存 token_status / session_id；仅提供更精确的审计与 token
/// 关联查询维度。`ensure*` 供 onUpgrade 与 onOpen 兼容兜底复用。
class Migration024 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 24) {
      await ensureOperationAuditLogTokenId(db);
    }
  }

  static Future<void> ensureOperationAuditLogTokenId(Database db) async {
    if (!await _tableExists(db, 'operation_audit_logs')) {
      await OperationsSchema.create(db);
      return;
    }

    await _addColumnIfMissing(db, 'operation_audit_logs', 'token_id', 'TEXT');
    await OperationsSchema.create(db);
  }
}
