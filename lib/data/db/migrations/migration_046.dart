part of '../db_migrations.dart';

/// v46（Track A / A4-5）：project_write_offs 删除 amount REAL。
///
/// amount_fen 已在 v30 收紧为 INTEGER NOT NULL，本迁移把项目核销金额提升为
/// fen-only 存储权威。旧库若仍缺/残留 NULL fen，重建时用 legacy amount 按
/// CAST(ROUND(COALESCE(amount, 0) * 100.0) AS INTEGER) 兜底。
///
/// 本表带 projects FK；重建需临时关闭 foreign_keys，重建后先执行
/// foreign_key_check，再恢复 foreign_keys。原 CHECK(amount > 0) 的「严格正」金额
/// 约束忠实转移到 CHECK(amount_fen > 0)，不放松为非负。
class Migration046 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 46) {
      await ensureProjectWriteOffAmountRealDropped(db);
    }
  }

  static Future<void> ensureProjectWriteOffAmountRealDropped(
    Database db,
  ) async {
    if (!await _tableExists(db, 'project_write_offs')) {
      return;
    }
    if (!await _columnExists(db, 'project_write_offs', 'amount')) {
      return;
    }

    await _addColumnIfMissing(
      db,
      'project_write_offs',
      'amount_fen',
      'INTEGER',
    );

    await db.execute('PRAGMA foreign_keys = OFF;');
    try {
      await db.execute('DROP TABLE IF EXISTS project_write_offs_v46;');
      await db.execute('''
        CREATE TABLE project_write_offs_v46 (
          id TEXT PRIMARY KEY,
          project_id TEXT NOT NULL,
          amount_fen INTEGER NOT NULL CHECK (amount_fen > 0),
          reason TEXT NOT NULL,
          note TEXT,
          write_off_date TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (project_id)
            REFERENCES projects(id) ON DELETE RESTRICT
        );
      ''');
      await db.execute('''
        INSERT INTO project_write_offs_v46 (
          id, project_id, amount_fen, reason, note,
          write_off_date, created_at, updated_at
        )
        SELECT
          id, project_id,
          COALESCE(
            amount_fen,
            CAST(ROUND(COALESCE(amount, 0) * 100.0) AS INTEGER)
          ),
          reason, note, write_off_date, created_at, updated_at
        FROM project_write_offs;
      ''');
      await db.execute('DROP TABLE project_write_offs;');
      await db.execute(
        'ALTER TABLE project_write_offs_v46 RENAME TO project_write_offs;',
      );
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_project_write_offs_project_id
        ON project_write_offs(project_id);
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_project_write_offs_write_off_date
        ON project_write_offs(write_off_date);
      ''');

      final issues = await db.rawQuery('PRAGMA foreign_key_check;');
      if (issues.isNotEmpty) {
        throw StateError('project_write_offs 外键校验失败: $issues');
      }
    } finally {
      await db.execute('PRAGMA foreign_keys = ON;');
    }
  }
}
