part of '../db_migrations.dart';

/// v42（Track A / A4-1）：fuel_logs 删除 cost REAL。
///
/// cost_fen 已在 v40 收紧为 INTEGER NOT NULL，本迁移把它提升为唯一存储权威。
/// 旧库若仍缺/残留 NULL cost_fen，重建时用 legacy cost 按
/// CAST(ROUND(COALESCE(cost, 0) * 100.0) AS INTEGER) 兜底。
///
/// 坑A —— AUTOINCREMENT 高水位：DROP+RENAME 后删除 fuel_logs/fuel_logs_v42
/// 两个可能的 sqlite_sequence 残留行，再写回 max(old_seq, current_max_id)。
class Migration042 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 42) {
      await ensureFuelCostRealDropped(db);
    }
  }

  static Future<void> ensureFuelCostRealDropped(Database db) async {
    if (!await _tableExists(db, 'fuel_logs')) {
      return;
    }
    if (!await _columnExists(db, 'fuel_logs', 'cost')) {
      return;
    }

    await _addColumnIfMissing(db, 'fuel_logs', 'cost_fen', 'INTEGER');

    final oldSeq = await _readSqliteSequenceSeq(db, 'fuel_logs');

    await db.execute('DROP TABLE IF EXISTS fuel_logs_v42;');
    await db.execute('''
      CREATE TABLE fuel_logs_v42 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER NOT NULL,
        date INTEGER NOT NULL,
        supplier TEXT NOT NULL,
        liters REAL NOT NULL,
        cost_fen INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      INSERT INTO fuel_logs_v42 (
        id, device_id, date, supplier, liters, cost_fen
      )
      SELECT
        id, device_id, date, supplier, liters,
        COALESCE(cost_fen, CAST(ROUND(COALESCE(cost, 0) * 100.0) AS INTEGER))
      FROM fuel_logs;
    ''');
    await db.execute('DROP TABLE fuel_logs;');
    await db.execute('ALTER TABLE fuel_logs_v42 RENAME TO fuel_logs;');

    final currentMaxId = await _readMaxId(db, 'fuel_logs');
    final computedSeq = oldSeq > currentMaxId ? oldSeq : currentMaxId;
    if (computedSeq > 0) {
      await db.execute(
        "DELETE FROM sqlite_sequence "
        "WHERE name IN ('fuel_logs', 'fuel_logs_v42');",
      );
      await db.execute(
        "INSERT INTO sqlite_sequence(name, seq) VALUES ('fuel_logs', ?);",
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
