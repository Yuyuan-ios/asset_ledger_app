part of '../db_migrations.dart';

/// v43（Track A / A4-2）：maintenance_records 删除 amount REAL。
///
/// amount_fen 已在 v41 收紧为 INTEGER NOT NULL，本迁移把它提升为唯一存储权威。
/// 旧库若仍缺/残留 NULL amount_fen，重建时用 legacy amount 按
/// CAST(ROUND(COALESCE(amount, 0) * 100.0) AS INTEGER) 兜底。
///
/// 坑A —— AUTOINCREMENT 高水位：DROP+RENAME 后删除
/// maintenance_records/maintenance_records_v43 两个可能的 sqlite_sequence 残留行，
/// 再写回 max(old_seq, current_max_id)。
class Migration043 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 43) {
      await ensureMaintenanceAmountRealDropped(db);
    }
  }

  static Future<void> ensureMaintenanceAmountRealDropped(Database db) async {
    if (!await _tableExists(db, 'maintenance_records')) {
      return;
    }
    if (!await _columnExists(db, 'maintenance_records', 'amount')) {
      return;
    }

    await _addColumnIfMissing(
      db,
      'maintenance_records',
      'amount_fen',
      'INTEGER',
    );

    final oldSeq = await _readSqliteSequenceSeq(db, 'maintenance_records');

    await db.execute('DROP TABLE IF EXISTS maintenance_records_v43;');
    await db.execute('''
      CREATE TABLE maintenance_records_v43 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER,
        ymd INTEGER NOT NULL,
        item TEXT NOT NULL,
        amount_fen INTEGER NOT NULL,
        note TEXT
      );
    ''');
    await db.execute('''
      INSERT INTO maintenance_records_v43 (
        id, device_id, ymd, item, amount_fen, note
      )
      SELECT
        id, device_id, ymd, item,
        COALESCE(amount_fen, CAST(ROUND(COALESCE(amount, 0) * 100.0) AS INTEGER)),
        note
      FROM maintenance_records;
    ''');
    await db.execute('DROP TABLE maintenance_records;');
    await db.execute(
      'ALTER TABLE maintenance_records_v43 RENAME TO maintenance_records;',
    );

    final currentMaxId = await _readMaxId(db, 'maintenance_records');
    final computedSeq = oldSeq > currentMaxId ? oldSeq : currentMaxId;
    if (computedSeq > 0) {
      await db.execute(
        "DELETE FROM sqlite_sequence "
        "WHERE name IN ('maintenance_records', 'maintenance_records_v43');",
      );
      await db.execute(
        "INSERT INTO sqlite_sequence(name, seq) "
        "VALUES ('maintenance_records', ?);",
        [computedSeq],
      );
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
