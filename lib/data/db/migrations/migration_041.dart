part of '../db_migrations.dart';

/// v41（Track A / A2d）：maintenance_records.amount_fen 提升为 INTEGER NOT NULL。
///
/// amount_fen 是维保金额的完整 fen 镜像；重建表时用
/// COALESCE(amount_fen, ROUND(amount*100)) 兜底残留 NULL。保留 amount REAL
/// 兼容列与 note/device_id nullable 语义。
///
/// 坑A —— AUTOINCREMENT 高水位：DROP+RENAME 后删除
/// maintenance_records/maintenance_records_v41 两个可能的 sqlite_sequence 残留行，
/// 再写回 max(old_seq, current_max_id)。
class Migration041 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 41) {
      await ensureMaintenanceAmountFenNotNull(db);
    }
  }

  static Future<void> ensureMaintenanceAmountFenNotNull(Database db) async {
    if (!await _tableExists(db, 'maintenance_records')) {
      return;
    }
    if (await _columnIsNotNull(db, 'maintenance_records', 'amount_fen')) {
      return;
    }

    await _addColumnIfMissing(
      db,
      'maintenance_records',
      'amount_fen',
      'INTEGER',
    );

    final oldSeq = await _readSqliteSequenceSeq(db, 'maintenance_records');

    await db.execute('DROP TABLE IF EXISTS maintenance_records_v41;');
    await db.execute('''
      CREATE TABLE maintenance_records_v41 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER,
        ymd INTEGER NOT NULL,
        item TEXT NOT NULL,
        amount REAL NOT NULL,
        amount_fen INTEGER NOT NULL,
        note TEXT
      );
    ''');
    await db.execute('''
      INSERT INTO maintenance_records_v41 (
        id, device_id, ymd, item, amount, amount_fen, note
      )
      SELECT
        id, device_id, ymd, item, amount,
        COALESCE(amount_fen, CAST(ROUND(COALESCE(amount, 0) * 100.0) AS INTEGER)),
        note
      FROM maintenance_records;
    ''');
    await db.execute('DROP TABLE maintenance_records;');
    await db.execute(
      'ALTER TABLE maintenance_records_v41 RENAME TO maintenance_records;',
    );

    final currentMaxId = await _readMaxId(db, 'maintenance_records');
    final computedSeq = oldSeq > currentMaxId ? oldSeq : currentMaxId;
    if (computedSeq > 0) {
      await db.execute(
        "DELETE FROM sqlite_sequence "
        "WHERE name IN ('maintenance_records', 'maintenance_records_v41');",
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
