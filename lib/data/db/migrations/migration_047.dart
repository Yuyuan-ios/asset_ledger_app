part of '../db_migrations.dart';

/// v47（Track A / A4-6）：account_payments 删除金额 REAL 列。
///
/// amount_fen 已在 v31 收紧为 INTEGER NOT NULL，本迁移把收款金额提升为
/// fen-only 存储权威；merge_batch_total_amount_fen 继续保持 nullable。
/// 旧库若仍缺/残留 NULL fen，重建时用 legacy REAL 按
/// CAST(ROUND(COALESCE(real, 0) * 100.0) AS INTEGER) 兜底。
///
/// 坑A —— AUTOINCREMENT 高水位：DROP+RENAME 后删除 account_payments /
/// account_payments_v47 两个可能的 sqlite_sequence 残留行，再写回
/// max(old_seq, current_max_id)。
class Migration047 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 47) {
      await ensureAccountPaymentAmountRealsDropped(db);
    }
  }

  static Future<void> ensureAccountPaymentAmountRealsDropped(
    Database db,
  ) async {
    if (!await _tableExists(db, 'account_payments')) {
      return;
    }

    final hasAmountReal = await _columnExists(db, 'account_payments', 'amount');
    final hasMergeAmountReal = await _columnExists(
      db,
      'account_payments',
      'merge_batch_total_amount',
    );
    if (!hasAmountReal && !hasMergeAmountReal) {
      return;
    }

    await _addColumnIfMissing(db, 'account_payments', 'amount_fen', 'INTEGER');
    await _addColumnIfMissing(
      db,
      'account_payments',
      'merge_batch_total_amount_fen',
      'INTEGER',
    );

    final oldSeq = await _readSqliteSequenceSeq(db, 'account_payments');
    final amountFenExpr = hasAmountReal
        ? '''
        COALESCE(
          amount_fen,
          CAST(ROUND(COALESCE(amount, 0) * 100.0) AS INTEGER)
        )
        '''
        : 'COALESCE(amount_fen, 0)';
    final mergeTotalFenExpr = hasMergeAmountReal
        ? '''
        COALESCE(
          merge_batch_total_amount_fen,
          CASE
            WHEN merge_batch_total_amount IS NULL THEN NULL
            ELSE CAST(ROUND(merge_batch_total_amount * 100.0) AS INTEGER)
          END
        )
        '''
        : 'merge_batch_total_amount_fen';

    await db.execute('PRAGMA foreign_keys = OFF;');
    try {
      await db.execute('DROP TABLE IF EXISTS account_payments_v47;');
      await db.execute('''
        CREATE TABLE account_payments_v47 (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          project_id TEXT NOT NULL,
          project_key TEXT NOT NULL,
          ymd INTEGER NOT NULL,
          amount_fen INTEGER NOT NULL,
          note TEXT,
          source_type TEXT NOT NULL DEFAULT 'manual',
          merge_group_id INTEGER,
          merge_batch_id TEXT,
          merge_batch_total_amount_fen INTEGER,
          merge_batch_note TEXT,
          created_at TEXT,
          FOREIGN KEY (project_id)
            REFERENCES projects(id) ON DELETE RESTRICT
        );
      ''');
      await db.execute('''
        INSERT INTO account_payments_v47 (
          id, project_id, project_key, ymd, amount_fen, note,
          source_type, merge_group_id, merge_batch_id,
          merge_batch_total_amount_fen, merge_batch_note, created_at
        )
        SELECT
          id, project_id, project_key, ymd, $amountFenExpr, note,
          source_type, merge_group_id, merge_batch_id,
          $mergeTotalFenExpr, merge_batch_note, created_at
        FROM account_payments;
      ''');
      await db.execute('DROP TABLE account_payments;');
      await db.execute(
        'ALTER TABLE account_payments_v47 RENAME TO account_payments;',
      );
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_account_payments_project_ymd
        ON account_payments(project_id, ymd);
      ''');

      final currentMaxId = await _readMaxId(db, 'account_payments');
      final computedSeq = oldSeq > currentMaxId ? oldSeq : currentMaxId;
      if (computedSeq > 0) {
        await db.execute(
          "DELETE FROM sqlite_sequence "
          "WHERE name IN ('account_payments', 'account_payments_v47');",
        );
        await db.execute(
          "INSERT INTO sqlite_sequence(name, seq) "
          "VALUES ('account_payments', ?);",
          [computedSeq],
        );
      }

      final issues = await db.rawQuery('PRAGMA foreign_key_check;');
      if (issues.isNotEmpty) {
        throw StateError('account_payments 外键校验失败: $issues');
      }
    } finally {
      await db.execute('PRAGMA foreign_keys = ON;');
    }
  }

  static Future<int> _readSqliteSequenceSeq(Database db, String name) async {
    if (!await _tableExists(db, 'sqlite_sequence')) return 0;
    final rows = await db.rawQuery(
      'SELECT seq FROM sqlite_sequence WHERE name = ?;',
      [name],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['seq'] as int?) ?? 0;
  }

  static Future<int> _readMaxId(Database db, String table) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(id), 0) AS m FROM $table;',
    );
    return (rows.first['m'] as int?) ?? 0;
  }
}
