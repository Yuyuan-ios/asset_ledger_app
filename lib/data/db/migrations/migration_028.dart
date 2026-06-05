part of '../db_migrations.dart';

/// v28：sync_outbox 增加 nullable next_retry_at（R5.22-B）。
///
/// 该列承载失败重试的退避时间点：push 失败后 SyncManager 写入
/// next_retry_at = now + backoff(retry_count)，listPending 跳过 next_retry_at 在
/// 未来的行，避免未到期的失败行被立即重推。
/// - 成功 push 的行会被删除，因此正常路径不依赖该列。
/// - 旧行与从未失败的行保持 NULL（NULL 视为"立即可推"）。
/// 不动旧业务表、不动 transaction_group_id / local_sequence / sync_state；
/// ensure* 形式幂等，可由 DbSchemaCompat.ensure 在 onOpen 兜底已升级过的库。
class Migration028 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 28) {
      await ensureSyncOutboxNextRetryAt(db);
    }
  }

  static Future<void> ensureSyncOutboxNextRetryAt(Database db) async {
    if (!await _tableExists(db, 'sync_outbox')) {
      return;
    }
    await _addColumnIfMissing(db, 'sync_outbox', 'next_retry_at', 'TEXT');
  }
}
