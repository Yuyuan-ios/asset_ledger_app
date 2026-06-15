part of '../db_migrations.dart';

/// v39（Track A / A2b）：project_device_rates.rate_fen 提升为 INTEGER NOT NULL。
///
/// rate_fen 是项目设备覆盖单价的完整 fen 镜像；重建表时用
/// COALESCE(rate_fen, ROUND(rate*100)) 兜底残留 NULL。保留 rate REAL 兼容列、
/// 复合主键 (project_id, device_id, is_breaking)、projects FK RESTRICT 与
/// idx_project_device_rates_project 索引。
class Migration039 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 39) {
      await ensureProjectDeviceRateFenNotNull(db);
    }
  }

  static Future<void> ensureProjectDeviceRateFenNotNull(Database db) async {
    if (!await _tableExists(db, 'project_device_rates')) {
      return;
    }
    if (await _columnIsNotNull(db, 'project_device_rates', 'rate_fen')) {
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
      await db.execute('DROP TABLE IF EXISTS project_device_rates_v39;');
      await db.execute('''
        CREATE TABLE project_device_rates_v39 (
          project_id TEXT NOT NULL,
          project_key TEXT NOT NULL,
          device_id INTEGER NOT NULL,
          is_breaking INTEGER NOT NULL DEFAULT 0,
          rate REAL NOT NULL,
          rate_fen INTEGER NOT NULL,
          PRIMARY KEY (project_id, device_id, is_breaking),
          FOREIGN KEY (project_id)
            REFERENCES projects(id) ON DELETE RESTRICT
        );
      ''');
      await db.execute('''
        INSERT OR REPLACE INTO project_device_rates_v39 (
          project_id, project_key, device_id, is_breaking, rate, rate_fen
        )
        SELECT
          project_id, project_key, device_id, is_breaking, rate,
          COALESCE(rate_fen, CAST(ROUND(COALESCE(rate, 0) * 100.0) AS INTEGER))
        FROM project_device_rates;
      ''');
      await db.execute('DROP TABLE project_device_rates;');
      await db.execute(
        'ALTER TABLE project_device_rates_v39 RENAME TO project_device_rates;',
      );
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_project_device_rates_project
        ON project_device_rates(project_id);
      ''');
    } finally {
      await db.execute('PRAGMA foreign_keys = ON;');
    }

    final issues = await db.rawQuery('PRAGMA foreign_key_check;');
    if (issues.isNotEmpty) {
      throw StateError('project_device_rates 外键校验失败: $issues');
    }
  }
}
