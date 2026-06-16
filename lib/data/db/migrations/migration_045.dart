part of '../db_migrations.dart';

/// v45（Track A / A4-4）：project_device_rates 删除 rate REAL。
///
/// rate_fen 已在 v39 收紧为 INTEGER NOT NULL，本迁移把项目设备覆盖单价
/// 提升为 fen-only 存储权威。旧库若仍缺/残留 NULL fen，重建时用 legacy
/// rate 按 CAST(ROUND(COALESCE(rate, 0) * 100.0) AS INTEGER) 兜底。
///
/// 本表带 projects FK；重建需临时关闭 foreign_keys，重建后先执行
/// foreign_key_check，再恢复 foreign_keys。
class Migration045 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 45) {
      await ensureProjectDeviceRateRealDropped(db);
    }
  }

  static Future<void> ensureProjectDeviceRateRealDropped(Database db) async {
    if (!await _tableExists(db, 'project_device_rates')) {
      return;
    }
    if (!await _columnExists(db, 'project_device_rates', 'rate')) {
      return;
    }

    await _addColumnIfMissing(
      db,
      'project_device_rates',
      'rate_fen',
      'INTEGER',
    );

    await db.execute('PRAGMA foreign_keys = OFF;');
    try {
      await db.execute('DROP TABLE IF EXISTS project_device_rates_v45;');
      await db.execute('''
        CREATE TABLE project_device_rates_v45 (
          project_id TEXT NOT NULL,
          project_key TEXT NOT NULL,
          device_id INTEGER NOT NULL,
          is_breaking INTEGER NOT NULL DEFAULT 0,
          rate_fen INTEGER NOT NULL,
          PRIMARY KEY (project_id, device_id, is_breaking),
          FOREIGN KEY (project_id)
            REFERENCES projects(id) ON DELETE RESTRICT
        );
      ''');
      await db.execute('''
        INSERT OR REPLACE INTO project_device_rates_v45 (
          project_id, project_key, device_id, is_breaking, rate_fen
        )
        SELECT
          project_id, project_key, device_id, is_breaking,
          COALESCE(rate_fen, CAST(ROUND(COALESCE(rate, 0) * 100.0) AS INTEGER))
        FROM project_device_rates;
      ''');
      await db.execute('DROP TABLE project_device_rates;');
      await db.execute(
        'ALTER TABLE project_device_rates_v45 RENAME TO project_device_rates;',
      );
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_project_device_rates_project
        ON project_device_rates(project_id);
      ''');

      final issues = await db.rawQuery('PRAGMA foreign_key_check;');
      if (issues.isNotEmpty) {
        throw StateError('project_device_rates 外键校验失败: $issues');
      }
    } finally {
      await db.execute('PRAGMA foreign_keys = ON;');
    }
  }
}
