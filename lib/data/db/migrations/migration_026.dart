part of '../db_migrations.dart';

/// v26：sync_state 增加 nullable gate_state。
///
/// 该列承载 R5.21 的 restore-pending push gate 状态：restore 同事务写入
/// gate_state='restore-pending'，SyncManager.pushPending 在 push 前据此短路。
/// 不动旧业务表、不动 sync_outbox / entity_sync_meta；只补 sync_state 一列。
/// ensure* 形式幂等，可由 DbSchemaCompat.ensure 在 onOpen 兜底已升级过的库。
class Migration026 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 26) {
      await ensureSyncStateGateState(db);
    }
  }

  static Future<void> ensureSyncStateGateState(Database db) async {
    if (!await _tableExists(db, 'sync_state')) {
      return;
    }
    await _addColumnIfMissing(db, 'sync_state', 'gate_state', 'TEXT');
  }
}
