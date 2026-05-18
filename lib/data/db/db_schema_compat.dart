import 'package:sqflite/sqflite.dart';

import 'db_migrations.dart';

/// 打开数据库后的结构兼容修复（历史库兜底）。
class DbSchemaCompat {
  static Future<void> ensure(Database db) async {
    await _ensureAccountProjectMergeSchema(db);
    await _ensureAccountPaymentMergeColumns(db);

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

    await DbMigrations.ensureProjectIdentitySchema(
      db,
      enforceForeignKeys: true,
    );
    await DbMigrations.ensureProjectWriteOffSchema(db);
    await DbMigrations.ensureExternalWorkSchema(db);
  }

  static Future<void> _ensureAccountPaymentMergeColumns(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(account_payments);');
    final names = cols.map((row) => row['name'] as String).toSet();

    if (!names.contains('source_type')) {
      await db.execute('''
        ALTER TABLE account_payments
        ADD COLUMN source_type TEXT NOT NULL DEFAULT 'manual';
      ''');
    }
    if (!names.contains('merge_group_id')) {
      await db.execute(
        'ALTER TABLE account_payments ADD COLUMN merge_group_id INTEGER;',
      );
    }
    if (!names.contains('merge_batch_id')) {
      await db.execute(
        'ALTER TABLE account_payments ADD COLUMN merge_batch_id TEXT;',
      );
    }
    if (!names.contains('merge_batch_total_amount')) {
      await db.execute('''
        ALTER TABLE account_payments
        ADD COLUMN merge_batch_total_amount REAL;
      ''');
    }
    if (!names.contains('merge_batch_note')) {
      await db.execute(
        'ALTER TABLE account_payments ADD COLUMN merge_batch_note TEXT;',
      );
    }
    if (!names.contains('created_at')) {
      await db.execute(
        'ALTER TABLE account_payments ADD COLUMN created_at TEXT;',
      );
    }
  }

  static Future<void> _ensureAccountProjectMergeSchema(Database db) async {
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
}
