part of '../db_migrations.dart';

/// v30：project_write_offs.amount_fen 提升为 INTEGER NOT NULL（R5.26-B2）。
///
/// SQLite 无法原地修改列约束，故重建表：新表 amount_fen INTEGER NOT NULL，
/// INSERT…SELECT 时用 COALESCE(amount_fen, CAST(ROUND(amount*100) AS INTEGER))
/// 兜底任何残留 NULL（B0.5/B3 已保证应用写入与回填恒一致，这里只是最后防线）。
/// 保留 amount REAL 兼容列、CHECK(amount>0)、TEXT 主键、projects FK RESTRICT 与
/// idx_project_write_offs_project_id / idx_project_write_offs_write_off_date 两索引。
///
/// 不动 account_payments（B1）、不改 model/payload/读路径。
/// ensure 幂等：amount_fen 已是 NOT NULL 时直接返回，可由 onUpgrade 链与
/// DbSchemaCompat.ensure(onOpen) 反复调用。重建沿用本项目既有重建迁移
/// （project_foreign_key_migration / project_identity_migration / v8 fix）写法：
/// PRAGMA foreign_keys OFF→重建→ON（onUpgrade 事务内该 PRAGMA 为 no-op，但
/// project_write_offs 是叶子子表、无入边外键，FK ON 下重建同样安全），最后过
/// foreign_key_check。
class Migration030 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 30) {
      await ensureProjectWriteOffAmountFenNotNull(db);
    }
  }

  static Future<void> ensureProjectWriteOffAmountFenNotNull(Database db) async {
    if (!await _tableExists(db, 'project_write_offs')) {
      return;
    }
    // 已是 NOT NULL → 幂等返回，不重建。
    if (await _columnIsNotNull(db, 'project_write_offs', 'amount_fen')) {
      return;
    }
    // 极简/历史库可能缺 amount_fen 列：先补 nullable 列（与 migration_018 同口径），
    // 再统一重建为 NOT NULL。
    await _addColumnIfMissing(db, 'project_write_offs', 'amount_fen', 'INTEGER');

    await db.execute('PRAGMA foreign_keys = OFF;');
    try {
      await db.execute('DROP TABLE IF EXISTS project_write_offs_v30;');
      await db.execute('''
        CREATE TABLE project_write_offs_v30 (
          id TEXT PRIMARY KEY,
          project_id TEXT NOT NULL,
          amount REAL NOT NULL CHECK (amount > 0),
          amount_fen INTEGER NOT NULL,
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
        INSERT INTO project_write_offs_v30 (
          id, project_id, amount, amount_fen, reason, note,
          write_off_date, created_at, updated_at
        )
        SELECT
          id, project_id, amount,
          COALESCE(amount_fen, CAST(ROUND(amount * 100) AS INTEGER)),
          reason, note, write_off_date, created_at, updated_at
        FROM project_write_offs;
      ''');
      await db.execute('DROP TABLE project_write_offs;');
      await db.execute(
        'ALTER TABLE project_write_offs_v30 RENAME TO project_write_offs;',
      );
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_project_write_offs_project_id
        ON project_write_offs(project_id);
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_project_write_offs_write_off_date
        ON project_write_offs(write_off_date);
      ''');
    } finally {
      await db.execute('PRAGMA foreign_keys = ON;');
    }

    final issues = await db.rawQuery('PRAGMA foreign_key_check;');
    if (issues.isNotEmpty) {
      throw StateError('project_write_offs 外键校验失败: $issues');
    }
  }
}
