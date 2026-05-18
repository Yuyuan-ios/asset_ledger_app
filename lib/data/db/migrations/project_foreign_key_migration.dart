part of '../db_migrations.dart';

class ProjectForeignKeyMigration {
  static Future<void> ensure(Database db) async {
    if (await _allProjectForeignKeysExist(db)) {
      return;
    }

    await db.execute('PRAGMA foreign_keys = OFF;');
    try {
      if (await _tableExists(db, 'timing_records') &&
          !await _hasProjectForeignKey(db, 'timing_records')) {
        await _rebuildTimingRecordsWithProjectForeignKey(db);
      }
      if (await _tableExists(db, 'account_payments') &&
          !await _hasProjectForeignKey(db, 'account_payments')) {
        await _rebuildAccountPaymentsWithProjectForeignKey(db);
      }
      if (await _tableExists(db, 'project_device_rates') &&
          !await _hasProjectForeignKey(db, 'project_device_rates')) {
        await _rebuildProjectDeviceRatesWithProjectForeignKey(db);
      }
      if (await _tableExists(db, 'account_project_merge_members') &&
          !await _hasProjectForeignKey(db, 'account_project_merge_members')) {
        await _rebuildMergeMembersWithProjectForeignKey(db);
      }
    } finally {
      await db.execute('PRAGMA foreign_keys = ON;');
    }

    final issues = await db.rawQuery('PRAGMA foreign_key_check;');
    if (issues.isNotEmpty) {
      throw StateError('project_id 外键校验失败: $issues');
    }
  }

  static Future<bool> _allProjectForeignKeysExist(Database db) async {
    final checks = <String>[
      if (await _tableExists(db, 'timing_records')) 'timing_records',
      if (await _tableExists(db, 'account_payments')) 'account_payments',
      if (await _tableExists(db, 'project_device_rates'))
        'project_device_rates',
      if (await _tableExists(db, 'account_project_merge_members'))
        'account_project_merge_members',
    ];
    for (final table in checks) {
      if (!await _hasProjectForeignKey(db, table)) return false;
    }
    return true;
  }

  static Future<bool> _hasProjectForeignKey(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA foreign_key_list($table);');
    return rows.any((row) {
      return row['table'] == 'projects' && row['from'] == 'project_id';
    });
  }

  static Future<void> _rebuildTimingRecordsWithProjectForeignKey(
    Database db,
  ) async {
    await db.execute('DROP TABLE IF EXISTS timing_records_v14_fk;');
    await db.execute('''
      CREATE TABLE timing_records_v14_fk (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id TEXT NOT NULL,
        device_id INTEGER NOT NULL,
        start_date INTEGER NOT NULL,
        contact TEXT NOT NULL,
        site TEXT NOT NULL,
        type TEXT NOT NULL,
        start_meter REAL NOT NULL,
        end_meter REAL NOT NULL,
        hours REAL NOT NULL,
        income REAL NOT NULL,
        exclude_from_fuel_eff INTEGER NOT NULL DEFAULT 0,
        is_breaking INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (project_id)
          REFERENCES projects(id) ON DELETE RESTRICT
      );
    ''');
    await db.execute('''
      INSERT INTO timing_records_v14_fk (
        id, project_id, device_id, start_date, contact, site, type,
        start_meter, end_meter, hours, income, exclude_from_fuel_eff,
        is_breaking
      )
      SELECT
        id, project_id, device_id, start_date, contact, site, type,
        start_meter, end_meter, hours, income, exclude_from_fuel_eff,
        is_breaking
      FROM timing_records;
    ''');
    await db.execute('DROP TABLE timing_records;');
    await db.execute(
      'ALTER TABLE timing_records_v14_fk RENAME TO timing_records;',
    );
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_timing_records_project
      ON timing_records(project_id);
    ''');
  }

  static Future<void> _rebuildAccountPaymentsWithProjectForeignKey(
    Database db,
  ) async {
    await db.execute('DROP TABLE IF EXISTS account_payments_v14_fk;');
    await db.execute('''
      CREATE TABLE account_payments_v14_fk (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id TEXT NOT NULL,
        project_key TEXT NOT NULL,
        ymd INTEGER NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        source_type TEXT NOT NULL DEFAULT 'manual',
        merge_group_id INTEGER,
        merge_batch_id TEXT,
        merge_batch_total_amount REAL,
        merge_batch_note TEXT,
        created_at TEXT,
        FOREIGN KEY (project_id)
          REFERENCES projects(id) ON DELETE RESTRICT
      );
    ''');
    await db.execute('''
      INSERT INTO account_payments_v14_fk (
        id, project_id, project_key, ymd, amount, note, source_type,
        merge_group_id, merge_batch_id, merge_batch_total_amount,
        merge_batch_note, created_at
      )
      SELECT
        id, project_id, project_key, ymd, amount, note, source_type,
        merge_group_id, merge_batch_id, merge_batch_total_amount,
        merge_batch_note, created_at
      FROM account_payments;
    ''');
    await db.execute('DROP TABLE account_payments;');
    await db.execute(
      'ALTER TABLE account_payments_v14_fk RENAME TO account_payments;',
    );
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_account_payments_project_ymd
      ON account_payments(project_id, ymd);
    ''');
  }

  static Future<void> _rebuildProjectDeviceRatesWithProjectForeignKey(
    Database db,
  ) async {
    await db.execute('DROP TABLE IF EXISTS project_device_rates_v14_fk;');
    await db.execute('''
      CREATE TABLE project_device_rates_v14_fk (
        project_id TEXT NOT NULL,
        project_key TEXT NOT NULL,
        device_id INTEGER NOT NULL,
        is_breaking INTEGER NOT NULL DEFAULT 0,
        rate REAL NOT NULL,
        PRIMARY KEY (project_id, device_id, is_breaking),
        FOREIGN KEY (project_id)
          REFERENCES projects(id) ON DELETE RESTRICT
      );
    ''');
    await db.execute('''
      INSERT OR REPLACE INTO project_device_rates_v14_fk (
        project_id, project_key, device_id, is_breaking, rate
      )
      SELECT project_id, project_key, device_id, is_breaking, rate
      FROM project_device_rates;
    ''');
    await db.execute('DROP TABLE project_device_rates;');
    await db.execute('''
      ALTER TABLE project_device_rates_v14_fk
      RENAME TO project_device_rates;
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_project_device_rates_project
      ON project_device_rates(project_id);
    ''');
  }

  static Future<void> _rebuildMergeMembersWithProjectForeignKey(
    Database db,
  ) async {
    await db.execute(
      'DROP TABLE IF EXISTS account_project_merge_members_v14_fk;',
    );
    await db.execute('''
      CREATE TABLE account_project_merge_members_v14_fk (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id INTEGER NOT NULL,
        project_id TEXT NOT NULL,
        project_key TEXT NOT NULL,
        contact TEXT NOT NULL,
        site TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (group_id)
          REFERENCES account_project_merge_groups(id) ON DELETE CASCADE,
        FOREIGN KEY (project_id)
          REFERENCES projects(id) ON DELETE RESTRICT
      );
    ''');
    await db.execute('''
      INSERT INTO account_project_merge_members_v14_fk (
        id, group_id, project_id, project_key, contact, site, sort_order,
        created_at, is_active
      )
      SELECT
        id, group_id, project_id, project_key, contact, site, sort_order,
        created_at, is_active
      FROM account_project_merge_members;
    ''');
    await db.execute('DROP TABLE account_project_merge_members;');
    await db.execute('''
      ALTER TABLE account_project_merge_members_v14_fk
      RENAME TO account_project_merge_members;
    ''');
    await ProjectIdentityMigration._reindexMergeMembersForProjectId(db);
  }
}
