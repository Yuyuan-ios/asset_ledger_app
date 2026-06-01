part of '../db_migrations.dart';

/// v23：新增 operation_tokens（confirmation token 持久化表）。
///
/// 不改任何旧业务表，也不改 operation_audit_logs，仅新增独立表 + 3 个索引。
/// `ensure*` 形式既可在 onUpgrade 串接，也由 [DbSchemaCompat.ensure] 在 onOpen
/// 兜底，全程幂等（CREATE TABLE / INDEX IF NOT EXISTS）。
class Migration023 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 23) {
      await ensureOperationTokensSchema(db);
    }
  }

  static Future<void> ensureOperationTokensSchema(Database db) async {
    await OperationTokensSchema.create(db);
  }
}
