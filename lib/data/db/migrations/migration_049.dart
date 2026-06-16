part of '../db_migrations.dart';

/// v49：sync_state 增加 pull_cursor(last_applied_server_seq)。
///
/// 该列承载 Track B / B2 的客户端 pull 游标。保留既有 last_pull_cursor TEXT
/// 兼容列，新增 INTEGER NOT NULL DEFAULT 0，旧库升级后没有显式 cursor 的行
/// 从 0 开始重放。ensure* 形式幂等，可由 DbSchemaCompat.ensure 在 onOpen 兜底。
class Migration049 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 49) {
      await ensureSyncStatePullCursor(db);
    }
  }

  static Future<void> ensureSyncStatePullCursor(Database db) async {
    if (!await _tableExists(db, 'sync_state')) {
      return;
    }
    await _addColumnIfMissing(
      db,
      'sync_state',
      'pull_cursor',
      'INTEGER NOT NULL DEFAULT 0',
    );
  }
}
