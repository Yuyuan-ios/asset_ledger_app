part of '../db_migrations.dart';

/// v38（Track A / A2a）：devices.default_unit_price_fen 提升为 INTEGER NOT NULL。
///
/// default_unit_price_fen 现在是所有设备默认单价的完整 fen 镜像；重建表时用
/// COALESCE(default_unit_price_fen, ROUND(default_unit_price*100)) 兜底残留 NULL。
/// breaking_unit_price_fen 继续保持 nullable，因为 breaking_unit_price 本身可空：
/// NULL 表示未单独配置破碎单价，计算仍回落默认单价。
///
/// 坑A —— AUTOINCREMENT 高水位：处理方式同 migration_031。DROP+RENAME 后先删除
/// devices/devices_v38 两个可能的 sqlite_sequence 残留行，再插唯一一行
/// max(old_seq, current_max_id)，避免 id 回退或重复序列行。
class Migration038 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 38) {
      await ensureDeviceDefaultUnitPriceFenNotNull(db);
    }
  }

  static Future<void> ensureDeviceDefaultUnitPriceFenNotNull(
    Database db,
  ) async {
    if (!await _tableExists(db, 'devices')) {
      return;
    }
    if (await _columnIsNotNull(db, 'devices', 'default_unit_price_fen')) {
      return;
    }

    await _addColumnIfMissing(
      db,
      'devices',
      'default_unit_price_fen',
      'INTEGER',
    );
    await _addColumnIfMissing(db, 'devices', 'breaking_unit_price', 'REAL');
    await _addColumnIfMissing(
      db,
      'devices',
      'equipment_type',
      "TEXT NOT NULL DEFAULT 'excavator'",
    );
    await _addColumnIfMissing(
      db,
      'devices',
      'breaking_unit_price_fen',
      'INTEGER',
    );

    final oldSeq = await _readSqliteSequenceSeq(db, 'devices');

    await db.execute('DROP TABLE IF EXISTS devices_v38;');
    await db.execute('''
      CREATE TABLE devices_v38 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        brand TEXT NOT NULL,
        model TEXT,
        default_unit_price REAL NOT NULL,
        breaking_unit_price REAL,
        default_unit_price_fen INTEGER NOT NULL,
        breaking_unit_price_fen INTEGER,
        base_meter_hours REAL NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        custom_avatar_path TEXT,
        equipment_type TEXT NOT NULL DEFAULT 'excavator'
      );
    ''');
    await db.execute('''
      INSERT INTO devices_v38 (
        id, name, brand, model, default_unit_price, breaking_unit_price,
        default_unit_price_fen, breaking_unit_price_fen, base_meter_hours,
        is_active, custom_avatar_path, equipment_type
      )
      SELECT
        id, name, brand, model, default_unit_price, breaking_unit_price,
        COALESCE(
          default_unit_price_fen,
          CAST(ROUND(COALESCE(default_unit_price, 0) * 100.0) AS INTEGER)
        ),
        COALESCE(
          breaking_unit_price_fen,
          CASE
            WHEN breaking_unit_price IS NULL THEN NULL
            ELSE CAST(
              ROUND(COALESCE(breaking_unit_price, 0) * 100.0) AS INTEGER
            )
          END
        ),
        base_meter_hours, is_active, custom_avatar_path, equipment_type
      FROM devices;
    ''');
    await db.execute('DROP TABLE devices;');
    await db.execute('ALTER TABLE devices_v38 RENAME TO devices;');

    final currentMaxId = await _readMaxId(db, 'devices');
    final computedSeq = oldSeq > currentMaxId ? oldSeq : currentMaxId;
    if (computedSeq > 0) {
      await db.execute(
        "DELETE FROM sqlite_sequence "
        "WHERE name IN ('devices', 'devices_v38');",
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
