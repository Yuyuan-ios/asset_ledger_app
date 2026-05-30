part of '../db_migrations.dart';

/// v22：新增 operation_audit_logs（append-only 操作审计表）。
///
/// 不改任何旧业务表，仅新增独立表 + 三个索引。`ensure*` 形式既可在
/// onUpgrade 串接，也由 [DbSchemaCompat.ensure] 在 onOpen 兜底，全程幂等
/// （CREATE TABLE / INDEX IF NOT EXISTS）。
class Migration022 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 22) {
      await ensureOperationAuditLogSchema(db);
    }
  }

  static Future<void> ensureOperationAuditLogSchema(Database db) async {
    await OperationsSchema.create(db);
  }
}
