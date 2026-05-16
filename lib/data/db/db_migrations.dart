import 'package:sqflite/sqflite.dart';

/// 数据库增量迁移链（onUpgrade）。
///
/// 说明：
/// - 保持 if(oldVersion < X) 的顺序与语义稳定。
/// - 迁移版本需与 AppDatabase._dbVersion 同步维护。
class DbMigrations {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    // v1 -> v2：devices 增加 custom_avatar_path
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE devices ADD COLUMN custom_avatar_path TEXT;',
      );
    }

    // v2 -> v3：fuel_logs 增加 supplier
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE fuel_logs ADD COLUMN supplier TEXT NOT NULL DEFAULT '';",
      );
    }

    // v3 -> v4：新增 maintenance_records
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS maintenance_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id INTEGER,
          ymd INTEGER NOT NULL,
          item TEXT NOT NULL,
          amount REAL NOT NULL,
          note TEXT
        );
      ''');
    }

    // v4 -> v5：新增 account_payments + project_device_rates
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS account_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          project_key TEXT NOT NULL,
          ymd INTEGER NOT NULL,
          amount REAL NOT NULL,
          note TEXT
        );
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_account_payments_project_ymd
        ON account_payments(project_key, ymd);
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS project_device_rates (
          project_key TEXT NOT NULL,
          device_id INTEGER NOT NULL,
          is_breaking INTEGER NOT NULL DEFAULT 0,
          rate REAL NOT NULL,
          PRIMARY KEY (project_key, device_id, is_breaking)
        );
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_project_device_rates_project
        ON project_device_rates(project_key);
      ''');
    }

    // ✅ v5 -> v6：timing_records 增加 exclude_from_fuel_eff
    if (oldVersion < 6) {
      await db.execute('''
        ALTER TABLE timing_records
        ADD COLUMN exclude_from_fuel_eff INTEGER NOT NULL DEFAULT 0;
      ''');
    }

    // ✅ v6 -> v7：timing_records 增加 is_breaking
    if (oldVersion < 7) {
      await db.execute('''
        ALTER TABLE timing_records
        ADD COLUMN is_breaking INTEGER NOT NULL DEFAULT 0;
      ''');
    }

    // ✅ v7 -> v8：设备增加破碎默认单价；项目设备单价覆盖按模式拆分
    if (oldVersion < 8) {
      await db.execute('''
        ALTER TABLE devices
        ADD COLUMN breaking_unit_price REAL;
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS project_device_rates_v2 (
          project_key TEXT NOT NULL,
          device_id INTEGER NOT NULL,
          is_breaking INTEGER NOT NULL DEFAULT 0,
          rate REAL NOT NULL,
          PRIMARY KEY (project_key, device_id, is_breaking)
        );
      ''');

      await db.execute('''
        INSERT OR REPLACE INTO project_device_rates_v2 (
          project_key, device_id, is_breaking, rate
        )
        SELECT project_key, device_id, 0, rate
        FROM project_device_rates;
      ''');

      await db.execute('DROP TABLE IF EXISTS project_device_rates;');
      await db.execute(
        'ALTER TABLE project_device_rates_v2 RENAME TO project_device_rates;',
      );
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_project_device_rates_project
        ON project_device_rates(project_key);
      ''');
    }

    // ✅ v8 -> v9：设备增加 equipment_type
    if (oldVersion < 9) {
      await db.execute('''
        ALTER TABLE devices
        ADD COLUMN equipment_type TEXT NOT NULL DEFAULT 'excavator';
      ''');
    }

    // ✅ v9 -> v10：新增计时记录工时计算依据历史
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS timing_calculation_history (
          id TEXT PRIMARY KEY,
          timing_record_id INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          expression TEXT NOT NULL,
          result REAL NOT NULL,
          ticket_count INTEGER NOT NULL,
          FOREIGN KEY (timing_record_id)
            REFERENCES timing_records(id) ON DELETE CASCADE
        );
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_timing_calc_record_id
        ON timing_calculation_history(timing_record_id);
      ''');
    }

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
  }

  static Future<bool> _tableExists(Database db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?;",
      [table],
    );
    return rows.isNotEmpty;
  }

  static Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table);');
    final exists = columns.any((row) => row['name'] == column);
    if (exists) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition;');
  }
}
