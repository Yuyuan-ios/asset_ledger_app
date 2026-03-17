import 'package:sqflite/sqflite.dart';

/// 打开数据库后的结构兼容修复（历史库兜底）。
class DbSchemaCompat {
  static Future<void> ensure(Database db) async {
    // devices.breaking_unit_price 兜底
    final deviceCols = await db.rawQuery('PRAGMA table_info(devices);');
    final hasBreakingUnitPrice = deviceCols.any(
      (row) => row['name'] == 'breaking_unit_price',
    );
    if (!hasBreakingUnitPrice) {
      await db.execute(
        'ALTER TABLE devices ADD COLUMN breaking_unit_price REAL;',
      );
    }

    final hasEquipmentType = deviceCols.any(
      (row) => row['name'] == 'equipment_type',
    );
    if (!hasEquipmentType) {
      await db.execute(
        "ALTER TABLE devices ADD COLUMN equipment_type TEXT NOT NULL DEFAULT 'excavator';",
      );
    }

    // project_device_rates 兜底：必须含 is_breaking 且主键为 3 列
    final rateCols = await db.rawQuery(
      'PRAGMA table_info(project_device_rates);',
    );
    final hasIsBreaking = rateCols.any((row) => row['name'] == 'is_breaking');
    final pkCols = rateCols
        .where((row) => ((row['pk'] as int?) ?? 0) > 0)
        .map((row) => row['name'] as String)
        .toList();
    final has3Key =
        pkCols.length == 3 &&
        pkCols.contains('project_key') &&
        pkCols.contains('device_id') &&
        pkCols.contains('is_breaking');

    if (!hasIsBreaking || !has3Key) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS project_device_rates_v8_fix (
          project_key TEXT NOT NULL,
          device_id INTEGER NOT NULL,
          is_breaking INTEGER NOT NULL DEFAULT 0,
          rate REAL NOT NULL,
          PRIMARY KEY (project_key, device_id, is_breaking)
        );
      ''');
      await db.execute('''
        INSERT OR REPLACE INTO project_device_rates_v8_fix (
          project_key, device_id, is_breaking, rate
        )
        SELECT project_key, device_id, 0, rate
        FROM project_device_rates;
      ''');
      await db.execute('DROP TABLE IF EXISTS project_device_rates;');
      await db.execute(
        'ALTER TABLE project_device_rates_v8_fix RENAME TO project_device_rates;',
      );
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_project_device_rates_project
        ON project_device_rates(project_key);
      ''');
    }
  }
}
