part of '../db_migrations.dart';

class Migration011017 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    // v10 -> v11：新增账户项目合并关系表
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS account_project_merge_groups (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          contact TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          dissolved_at TEXT,
          source_type TEXT NOT NULL DEFAULT 'local'
        );
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_account_project_merge_groups_active_contact
        ON account_project_merge_groups(is_active, contact);
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS account_project_merge_members (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          group_id INTEGER NOT NULL,
          project_key TEXT NOT NULL,
          contact TEXT NOT NULL,
          site TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (group_id)
            REFERENCES account_project_merge_groups(id) ON DELETE CASCADE
        );
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_account_project_merge_members_group
        ON account_project_merge_members(group_id, sort_order);
      ''');

      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_account_project_merge_members_group_project
        ON account_project_merge_members(group_id, project_key);
      ''');

      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_account_project_merge_members_active_project
        ON account_project_merge_members(project_key)
        WHERE is_active = 1;
      ''');
    }

    // v11 -> v12：account_payments 增加合并收款分摊批次字段
    if (oldVersion < 12) {
      if (await _tableExists(db, 'account_payments')) {
        await _addColumnIfMissing(
          db,
          'account_payments',
          'source_type',
          "TEXT NOT NULL DEFAULT 'manual'",
        );
        await _addColumnIfMissing(
          db,
          'account_payments',
          'merge_group_id',
          'INTEGER',
        );
        await _addColumnIfMissing(
          db,
          'account_payments',
          'merge_batch_id',
          'TEXT',
        );
        await _addColumnIfMissing(
          db,
          'account_payments',
          'merge_batch_total_amount',
          'REAL',
        );
        await _addColumnIfMissing(
          db,
          'account_payments',
          'merge_batch_note',
          'TEXT',
        );
        await _addColumnIfMissing(db, 'account_payments', 'created_at', 'TEXT');
      }
    }

    // v12 -> v13：新增稳定 projects/project_id 身份层。
    if (oldVersion < 13) {
      await ensureProjectIdentitySchema(db);
    }

    // v13 -> v14：projects 状态字段；FK 在 onOpen 兼容阶段统一重建。
    if (oldVersion < 14) {
      await ensureProjectIdentitySchema(db);
    }

    // v14 -> v15：新增单层外协项目导入基础表。
    if (oldVersion < 15) {
      await ensureExternalWorkSchema(db);
    }

    // v15 -> v16：新增项目核销记录表。
    if (oldVersion < 16) {
      await ensureProjectWriteOffSchema(db);
    }

    // v16 -> v17：新增云端同步与小程序司机端工时预留表。
    if (oldVersion < 17) {
      await ensureSyncSchema(db);
    }
  }

  static Future<void> ensureExternalWorkSchema(Database db) async {
    await ExternalWorkSchema.create(db);
  }

  static Future<void> ensureSyncSchema(Database db) async {
    await SyncSchema.create(db);
  }

  static Future<void> ensureProjectWriteOffSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS project_write_offs (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        amount REAL NOT NULL CHECK (amount > 0),
        amount_fen INTEGER,
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
      CREATE INDEX IF NOT EXISTS idx_project_write_offs_project_id
      ON project_write_offs(project_id);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_project_write_offs_write_off_date
      ON project_write_offs(write_off_date);
    ''');
  }

  static Future<void> ensureProjectIdentitySchema(
    Database db, {
    bool enforceForeignKeys = false,
  }) {
    return ProjectIdentityMigration.ensure(
      db,
      enforceForeignKeys: enforceForeignKeys,
    );
  }
}
