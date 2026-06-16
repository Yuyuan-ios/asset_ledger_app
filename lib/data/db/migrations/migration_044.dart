part of '../db_migrations.dart';

/// v44（Track A / A4-3）：devices 删除 default_unit_price / breaking_unit_price REAL。
///
/// default_unit_price_fen 已在 v38 收紧为 INTEGER NOT NULL，本迁移把设备单价
/// 提升为 fen-only 存储权威。旧库若仍缺/残留 NULL fen，重建时用 legacy REAL 按
/// CAST(ROUND(COALESCE(real, 0) * 100.0) AS INTEGER) 兜底。
///
/// 坑A —— AUTOINCREMENT 高水位：DROP+RENAME 后删除 devices/devices_v44 两个
/// 可能的 sqlite_sequence 残留行，再写回 max(old_seq, current_max_id)。
class Migration044 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 44) {
      await ensureDeviceUnitPriceRealsDropped(db);
    }
  }

  static Future<void> ensureDeviceUnitPriceRealsDropped(Database db) async {
    if (!await _tableExists(db, 'devices')) {
      return;
    }

    final hasDefaultReal = await _columnExists(
      db,
      'devices',
      'default_unit_price',
    );
    final hasBreakingReal = await _columnExists(
      db,
      'devices',
      'breaking_unit_price',
    );
    if (!hasDefaultReal && !hasBreakingReal) {
      return;
    }

    await _addColumnIfMissing(
      db,
      'devices',
      'default_unit_price_fen',
      'INTEGER',
    );
    await _addColumnIfMissing(
      db,
      'devices',
      'breaking_unit_price_fen',
      'INTEGER',
    );
    await _addColumnIfMissing(
      db,
      'devices',
      'equipment_type',
      "TEXT NOT NULL DEFAULT 'excavator'",
    );

    final oldSeq = await _readSqliteSequenceSeq(db, 'devices');
    final defaultFenExpr = hasDefaultReal
        ? '''
        COALESCE(
          default_unit_price_fen,
          CAST(ROUND(COALESCE(default_unit_price, 0) * 100.0) AS INTEGER)
        )
        '''
        : 'COALESCE(default_unit_price_fen, 0)';
    final breakingFenExpr = hasBreakingReal
        ? '''
        COALESCE(
          breaking_unit_price_fen,
          CASE
            WHEN breaking_unit_price IS NULL THEN NULL
            ELSE CAST(
              ROUND(COALESCE(breaking_unit_price, 0) * 100.0) AS INTEGER
            )
          END
        )
        '''
        : 'breaking_unit_price_fen';

    await db.execute('DROP TABLE IF EXISTS devices_v44;');
    await db.execute('''
      CREATE TABLE devices_v44 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        brand TEXT NOT NULL,
        model TEXT,
        default_unit_price_fen INTEGER NOT NULL,
        breaking_unit_price_fen INTEGER,
        base_meter_hours REAL NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        custom_avatar_path TEXT,
        equipment_type TEXT NOT NULL DEFAULT 'excavator'
      );
    ''');
    await db.execute('''
      INSERT INTO devices_v44 (
        id, name, brand, model, default_unit_price_fen,
        breaking_unit_price_fen, base_meter_hours, is_active,
        custom_avatar_path, equipment_type
      )
      SELECT
        id, name, brand, model,
        $defaultFenExpr,
        $breakingFenExpr,
        base_meter_hours, is_active, custom_avatar_path, equipment_type
      FROM devices;
    ''');
    await db.execute('DROP TABLE devices;');
    await db.execute('ALTER TABLE devices_v44 RENAME TO devices;');

    final currentMaxId = await _readMaxId(db, 'devices');
    final computedSeq = oldSeq > currentMaxId ? oldSeq : currentMaxId;
    if (computedSeq > 0) {
      await db.execute(
        "DELETE FROM sqlite_sequence "
        "WHERE name IN ('devices', 'devices_v44');",
      );
      await db.execute(
        "INSERT INTO sqlite_sequence(name, seq) VALUES ('devices', ?);",
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
