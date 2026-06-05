part of '../db_migrations.dart';

/// v27：sync_outbox 增加 nullable transaction_group_id / local_sequence（R5.22-A）。
///
/// 这两列把"同一个业务事务里产生的多条 outbox 行"标记为一个有序组：
/// - transaction_group_id：同事务 cluster 共享的组 id（`txn-<hex>`）。
/// - local_sequence：组内本地因果顺序（1,2,3…）。
///
/// 本轮只补列与入队侧写入；SyncManager 的 push ordering / replay 仍是 R5.22-B
/// 的后续切片，不在此实现。旧行的两列保持 NULL；普通单条入队也保持 NULL。
/// 不动旧业务表、不动 entity_sync_meta / sync_state；ensure* 形式幂等，可由
/// DbSchemaCompat.ensure 在 onOpen 兜底已升级过的库。
class Migration027 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 27) {
      await ensureSyncOutboxTransactionGroup(db);
    }
  }

  static Future<void> ensureSyncOutboxTransactionGroup(Database db) async {
    if (!await _tableExists(db, 'sync_outbox')) {
      return;
    }
    await _addColumnIfMissing(
      db,
      'sync_outbox',
      'transaction_group_id',
      'TEXT',
    );
    await _addColumnIfMissing(db, 'sync_outbox', 'local_sequence', 'INTEGER');
  }
}
