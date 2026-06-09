part of '../db_migrations.dart';

/// v31：account_payments.amount_fen 提升为 INTEGER NOT NULL（R5.26-B1）。
///
/// SQLite 无法原地修改列约束，故重建表：新表 amount_fen INTEGER NOT NULL，
/// INSERT…SELECT 时用 COALESCE(amount_fen, CAST(ROUND(amount*100) AS INTEGER))
/// 兜底任何残留 NULL（B0.5/migration_018 已保证应用写入与回填恒一致，这里只是
/// 最后防线）。保留 amount REAL 兼容列、id INTEGER PRIMARY KEY AUTOINCREMENT、
/// projects FK RESTRICT 与 idx_account_payments_project_ymd 索引。
///
/// 坑A —— AUTOINCREMENT 高水位：DROP+RENAME 会让 sqlite_sequence 高水位回退到当前
/// MAX(id)。若历史上曾插入高 id 再删除（old_seq > MAX(id)），只写 MAX(id) 会让新
/// 收款复用已删除的 id 区间。故重建前读取 old_seq，重建后写回
/// max(old_seq, current_max_id)。
///   注：本项目运行的 SQLite（3.x，sqflite_common_ffi/系统库）在
///   `ALTER TABLE account_payments_v31 RENAME TO account_payments` 时会把
///   sqlite_sequence 里的行名一并改为 account_payments；而 sqlite_sequence 没有
///   name 唯一约束，直接 INSERT OR REPLACE 会插出第二行（出现两条
///   account_payments），导致 AUTOINCREMENT 读到错误高水位。因此这里改为
///   「先删除 account_payments / account_payments_v31 两个可能的残留行，再插入唯一
///   一行 (account_payments, computed_seq)」，保证 sqlite_sequence 中该表恰有一行、
///   高水位不倒退、无 _v31 残留。
///
/// 坑C —— merge_batch_total_amount_fen 保持 nullable（原样迁移，不翻 NOT NULL）。
///
/// ensure 幂等：amount_fen 已是 NOT NULL 时直接返回，可由 onUpgrade 链与
/// DbSchemaCompat.ensure(onOpen) 反复调用。重建沿用本项目既有重建迁移
/// （migration_030 / project_foreign_key_migration）写法：PRAGMA foreign_keys
/// OFF→重建→ON（onUpgrade 事务内该 PRAGMA 为 no-op，但 account_payments 是 projects
/// 叶子子表、无入边外键，FK ON 下重建同样安全），最后过 foreign_key_check。
class Migration031 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 31) {
      await ensureAccountPaymentAmountFenNotNull(db);
    }
  }

  static Future<void> ensureAccountPaymentAmountFenNotNull(Database db) async {
    if (!await _tableExists(db, 'account_payments')) {
      return;
    }
    // 已是 NOT NULL → 幂等返回，不重建。
    if (await _columnIsNotNull(db, 'account_payments', 'amount_fen')) {
      return;
    }
    // 极简/历史库可能缺列：先补 nullable 列（与 migration_018 同口径），再统一
    // 重建为 NOT NULL。merge_batch_total_amount_fen 同样防御性补列（保持 nullable）。
    await _addColumnIfMissing(db, 'account_payments', 'amount_fen', 'INTEGER');
    await _addColumnIfMissing(
      db,
      'account_payments',
      'merge_batch_total_amount_fen',
      'INTEGER',
    );

    // 重建前读取旧高水位（容错：sqlite_sequence 表或行可能不存在 → 0）。
    final oldSeq = await _readSqliteSequenceSeq(db, 'account_payments');

    await db.execute('PRAGMA foreign_keys = OFF;');
    try {
      await db.execute('DROP TABLE IF EXISTS account_payments_v31;');
      await db.execute('''
        CREATE TABLE account_payments_v31 (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          project_id TEXT NOT NULL,
          project_key TEXT NOT NULL,
          ymd INTEGER NOT NULL,
          amount REAL NOT NULL,
          amount_fen INTEGER NOT NULL,
          note TEXT,
          source_type TEXT NOT NULL DEFAULT 'manual',
          merge_group_id INTEGER,
          merge_batch_id TEXT,
          merge_batch_total_amount REAL,
          merge_batch_total_amount_fen INTEGER,
          merge_batch_note TEXT,
          created_at TEXT,
          FOREIGN KEY (project_id)
            REFERENCES projects(id) ON DELETE RESTRICT
        );
      ''');
      await db.execute('''
        INSERT INTO account_payments_v31 (
          id, project_id, project_key, ymd, amount, amount_fen, note,
          source_type, merge_group_id, merge_batch_id, merge_batch_total_amount,
          merge_batch_total_amount_fen, merge_batch_note, created_at
        )
        SELECT
          id, project_id, project_key, ymd, amount,
          COALESCE(amount_fen, CAST(ROUND(amount * 100) AS INTEGER)),
          note, source_type, merge_group_id, merge_batch_id,
          merge_batch_total_amount, merge_batch_total_amount_fen,
          merge_batch_note, created_at
        FROM account_payments;
      ''');
      await db.execute('DROP TABLE account_payments;');
      await db.execute(
        'ALTER TABLE account_payments_v31 RENAME TO account_payments;',
      );
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_account_payments_project_ymd
        ON account_payments(project_id, ymd);
      ''');

      // sqlite_sequence 高水位写回：max(old_seq, current_max_id)，不倒退。
      final currentMaxId = await _readMaxId(db, 'account_payments');
      final computedSeq = oldSeq > currentMaxId ? oldSeq : currentMaxId;
      // computedSeq == 0（空表 + 无历史高水位）：无高水位需保留，且此时
      // sqlite_sequence 可能尚未创建，跳过写入避免 'no such table'。
      // computedSeq > 0 时 sqlite_sequence 必然存在（old_seq>0 ⇒ 旧表曾有行；
      // current_max_id>0 ⇒ 上面的 INSERT…SELECT 已建 AUTOINCREMENT 序列）。
      if (computedSeq > 0) {
        // RENAME 可能把序列行改名为 account_payments，也可能残留
        // account_payments_v31；sqlite_sequence 无 name 唯一约束，先删两者再插唯一行。
        await db.execute(
          "DELETE FROM sqlite_sequence "
          "WHERE name IN ('account_payments', 'account_payments_v31');",
        );
        await db.execute(
          "INSERT INTO sqlite_sequence(name, seq) "
          "VALUES ('account_payments', ?);",
          [computedSeq],
        );
      }
    } finally {
      await db.execute('PRAGMA foreign_keys = ON;');
    }

    final issues = await db.rawQuery('PRAGMA foreign_key_check;');
    if (issues.isNotEmpty) {
      throw StateError('account_payments 外键校验失败: $issues');
    }
  }

  /// 读取 sqlite_sequence 中 [name] 的 seq；表或行缺失返回 0（容错，不抛错）。
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
