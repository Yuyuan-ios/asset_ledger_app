import 'package:sqflite/sqflite.dart';

import '../models/project.dart';
import '../models/project_key.dart';

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

    // v12 -> v13：新增稳定 projects/project_id 身份层。
    if (oldVersion < 13) {
      await ensureProjectIdentitySchema(db);
    }

    // v13 -> v14：projects 状态字段；FK 在 onOpen 兼容阶段统一重建。
    if (oldVersion < 14) {
      await ensureProjectIdentitySchema(db);
    }
  }

  static Future<void> ensureProjectIdentitySchema(
    Database db, {
    bool enforceForeignKeys = false,
  }) async {
    await _ensureProjectsTable(db);
    await _ensureProjectStatusColumns(db);

    final legacyProjectMap = await _buildLegacyProjects(db);
    await _ensureProjectIdColumns(db);
    await _backfillProjectIds(db, legacyProjectMap);
    await _rebuildProjectDeviceRatesForProjectId(db);
    await _reindexMergeMembersForProjectId(db);
    await _ensureProjectsForChildRows(db);
    await _ensureProjectIdentityIndexes(db);
    if (enforceForeignKeys) {
      await _ensureProjectForeignKeyTables(db);
    }
  }

  static Future<void> _ensureProjectsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS projects (
        id TEXT PRIMARY KEY,
        contact TEXT NOT NULL,
        site TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        settled_at TEXT,
        settled_snapshot TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        legacy_project_key TEXT UNIQUE
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_projects_legacy_key
      ON projects(legacy_project_key);
    ''');
  }

  static Future<void> _ensureProjectStatusColumns(Database db) async {
    await _addColumnIfMissing(
      db,
      'projects',
      'status',
      "TEXT NOT NULL DEFAULT 'active'",
    );
    await _addColumnIfMissing(db, 'projects', 'settled_at', 'TEXT');
    await _addColumnIfMissing(db, 'projects', 'settled_snapshot', 'TEXT');
    await db.update('projects', {
      'status': ProjectStatus.active.name,
    }, where: "status IS NULL OR TRIM(status) = ''");
  }

  static Future<Map<String, Project>> _buildLegacyProjects(Database db) async {
    final projects = <String, Project>{};
    final timestamp = DateTime.now().toUtc().toIso8601String();

    void addProject({required String contact, required String site}) {
      final key = ProjectKey.buildKey(contact: contact, site: site);
      projects.putIfAbsent(
        key,
        () =>
            Project.legacy(contact: contact, site: site, timestamp: timestamp),
      );
    }

    void addProjectKey(Object? rawKey) {
      final key = (rawKey as String?)?.trim() ?? '';
      if (key.isEmpty) return;
      final parsed = ProjectKey.fromKey(key);
      addProject(contact: parsed.contact, site: parsed.site);
    }

    if (await _tableExists(db, 'timing_records')) {
      final rows = await db.query('timing_records');
      for (final row in rows) {
        addProject(
          contact: (row['contact'] as String?) ?? '',
          site: (row['site'] as String?) ?? '',
        );
      }
    }

    if (await _tableExists(db, 'account_payments')) {
      final rows = await db.query('account_payments');
      for (final row in rows) {
        addProjectKey(row['project_key']);
      }
    }

    if (await _tableExists(db, 'project_device_rates')) {
      final rows = await db.query('project_device_rates');
      for (final row in rows) {
        addProjectKey(row['project_key']);
      }
    }

    if (await _tableExists(db, 'account_project_merge_members')) {
      final rows = await db.query('account_project_merge_members');
      for (final row in rows) {
        final rawKey = (row['project_key'] as String?)?.trim() ?? '';
        if (rawKey.isNotEmpty) {
          addProjectKey(rawKey);
        } else {
          addProject(
            contact: (row['contact'] as String?) ?? '',
            site: (row['site'] as String?) ?? '',
          );
        }
      }
    }

    for (final project in projects.values) {
      await db.insert(
        'projects',
        project.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    return projects;
  }

  static Future<void> _ensureProjectIdColumns(Database db) async {
    if (await _tableExists(db, 'timing_records')) {
      await _addColumnIfMissing(
        db,
        'timing_records',
        'project_id',
        "TEXT NOT NULL DEFAULT ''",
      );
    }
    if (await _tableExists(db, 'account_payments')) {
      await _addColumnIfMissing(
        db,
        'account_payments',
        'project_id',
        "TEXT NOT NULL DEFAULT ''",
      );
    }
    if (await _tableExists(db, 'project_device_rates')) {
      await _addColumnIfMissing(
        db,
        'project_device_rates',
        'project_id',
        "TEXT NOT NULL DEFAULT ''",
      );
    }
    if (await _tableExists(db, 'account_project_merge_members')) {
      await _addColumnIfMissing(
        db,
        'account_project_merge_members',
        'project_id',
        "TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  static Future<void> _backfillProjectIds(
    Database db,
    Map<String, Project> legacyProjectMap,
  ) async {
    Project projectForParts(String contact, String site) {
      final key = ProjectKey.buildKey(contact: contact, site: site);
      return legacyProjectMap[key] ??
          Project.legacy(
            contact: contact,
            site: site,
            timestamp: DateTime.now().toUtc().toIso8601String(),
          );
    }

    Project projectForKey(String key) {
      final parsed = ProjectKey.fromKey(key);
      return projectForParts(parsed.contact, parsed.site);
    }

    if (await _tableExists(db, 'timing_records')) {
      final rows = await db.query('timing_records');
      for (final row in rows) {
        final existing = (row['project_id'] as String?)?.trim() ?? '';
        if (existing.isNotEmpty) continue;
        final project = projectForParts(
          (row['contact'] as String?) ?? '',
          (row['site'] as String?) ?? '',
        );
        await db.update(
          'timing_records',
          {'project_id': project.id},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }

    if (await _tableExists(db, 'account_payments')) {
      final rows = await db.query('account_payments');
      for (final row in rows) {
        final existing = (row['project_id'] as String?)?.trim() ?? '';
        if (existing.isNotEmpty) continue;
        final project = projectForKey((row['project_key'] as String?) ?? '');
        await db.update(
          'account_payments',
          {'project_id': project.id},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }

    if (await _tableExists(db, 'project_device_rates')) {
      final hasIsBreaking = await _columnExists(
        db,
        'project_device_rates',
        'is_breaking',
      );
      final rows = await db.query('project_device_rates');
      for (final row in rows) {
        final existing = (row['project_id'] as String?)?.trim() ?? '';
        if (existing.isNotEmpty) continue;
        final project = projectForKey((row['project_key'] as String?) ?? '');
        await db.update(
          'project_device_rates',
          {'project_id': project.id},
          where: hasIsBreaking
              ? 'project_key = ? AND device_id = ? AND is_breaking = ?'
              : 'project_key = ? AND device_id = ?',
          whereArgs: hasIsBreaking
              ? [row['project_key'], row['device_id'], row['is_breaking'] ?? 0]
              : [row['project_key'], row['device_id']],
        );
      }
    }

    if (await _tableExists(db, 'account_project_merge_members')) {
      final rows = await db.query('account_project_merge_members');
      for (final row in rows) {
        final existing = (row['project_id'] as String?)?.trim() ?? '';
        if (existing.isNotEmpty) continue;
        final rawKey = (row['project_key'] as String?)?.trim() ?? '';
        final project = rawKey.isNotEmpty
            ? projectForKey(rawKey)
            : projectForParts(
                (row['contact'] as String?) ?? '',
                (row['site'] as String?) ?? '',
              );
        await db.update(
          'account_project_merge_members',
          {'project_id': project.id},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }

  static Future<void> _rebuildProjectDeviceRatesForProjectId(
    Database db,
  ) async {
    if (!await _tableExists(db, 'project_device_rates')) return;
    final cols = await db.rawQuery('PRAGMA table_info(project_device_rates);');
    final hasIsBreaking = cols.any((row) => row['name'] == 'is_breaking');
    final pkCols = cols
        .where((row) => ((row['pk'] as int?) ?? 0) > 0)
        .map((row) => row['name'] as String)
        .toList();
    final alreadyProjectIdPrimary =
        pkCols.length == 3 &&
        pkCols.contains('project_id') &&
        pkCols.contains('device_id') &&
        pkCols.contains('is_breaking');
    if (alreadyProjectIdPrimary) return;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS project_device_rates_v13 (
        project_id TEXT NOT NULL,
        project_key TEXT NOT NULL,
        device_id INTEGER NOT NULL,
        is_breaking INTEGER NOT NULL DEFAULT 0,
        rate REAL NOT NULL,
        PRIMARY KEY (project_id, device_id, is_breaking)
      );
    ''');
    final isBreakingSelect = hasIsBreaking ? 'is_breaking' : '0';
    await db.execute('''
      INSERT OR REPLACE INTO project_device_rates_v13 (
        project_id, project_key, device_id, is_breaking, rate
      )
      SELECT project_id, project_key, device_id, $isBreakingSelect, rate
      FROM project_device_rates;
    ''');
    await db.execute('DROP TABLE IF EXISTS project_device_rates;');
    await db.execute(
      'ALTER TABLE project_device_rates_v13 RENAME TO project_device_rates;',
    );
  }

  static Future<void> _reindexMergeMembersForProjectId(Database db) async {
    if (!await _tableExists(db, 'account_project_merge_members')) return;
    await db.execute(
      'DROP INDEX IF EXISTS idx_account_project_merge_members_group_project;',
    );
    await db.execute(
      'DROP INDEX IF EXISTS idx_account_project_merge_members_active_project;',
    );
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_account_project_merge_members_group_project
      ON account_project_merge_members(group_id, project_id);
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_account_project_merge_members_active_project
      ON account_project_merge_members(project_id)
      WHERE is_active = 1;
    ''');
  }

  static Future<void> _ensureProjectIdentityIndexes(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_projects_active_contact_site
      ON projects(contact, site)
      WHERE status = 'active';
    ''');

    if (await _tableExists(db, 'timing_records')) {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_timing_records_project
        ON timing_records(project_id);
      ''');
    }
    if (await _tableExists(db, 'account_payments')) {
      await db.execute(
        'DROP INDEX IF EXISTS idx_account_payments_project_ymd;',
      );
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_account_payments_project_ymd
        ON account_payments(project_id, ymd);
      ''');
    }
    if (await _tableExists(db, 'project_device_rates')) {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_project_device_rates_project
        ON project_device_rates(project_id);
      ''');
    }
  }

  static Future<void> _ensureProjectsForChildRows(Database db) async {
    Future<void> ensureProject({
      required String projectId,
      required String contact,
      required String site,
      String? legacyProjectKey,
    }) async {
      final normalizedProjectId = projectId.trim();
      if (normalizedProjectId.isEmpty) return;
      final existing = await db.query(
        'projects',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [normalizedProjectId],
        limit: 1,
      );
      if (existing.isNotEmpty) return;

      final timestamp = DateTime.now().toUtc().toIso8601String();
      final project = Project(
        id: normalizedProjectId,
        contact: contact.trim(),
        site: site.trim(),
        status: ProjectStatus.active,
        createdAt: timestamp,
        updatedAt: timestamp,
        legacyProjectKey: legacyProjectKey?.trim().isNotEmpty == true
            ? legacyProjectKey!.trim()
            : null,
      );
      await db.insert(
        'projects',
        project.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      final saved = await db.query(
        'projects',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [normalizedProjectId],
        limit: 1,
      );
      if (saved.isNotEmpty || project.legacyProjectKey == null) return;

      await db.insert(
        'projects',
        project.copyWith(legacyProjectKey: null).toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    if (await _tableExists(db, 'timing_records')) {
      final rows = await db.query('timing_records');
      for (final row in rows) {
        await ensureProject(
          projectId: (row['project_id'] as String?) ?? '',
          contact: (row['contact'] as String?) ?? '',
          site: (row['site'] as String?) ?? '',
          legacyProjectKey: ProjectKey.buildKey(
            contact: (row['contact'] as String?) ?? '',
            site: (row['site'] as String?) ?? '',
          ),
        );
      }
    }

    Future<void> ensureProjectFromKeyRow(
      Map<String, Object?> row, {
      required String projectIdColumn,
    }) async {
      final projectKey = (row['project_key'] as String?) ?? '';
      final parsed = ProjectKey.fromKey(projectKey);
      await ensureProject(
        projectId: (row[projectIdColumn] as String?) ?? '',
        contact: parsed.contact,
        site: parsed.site,
        legacyProjectKey: projectKey,
      );
    }

    if (await _tableExists(db, 'account_payments')) {
      final rows = await db.query('account_payments');
      for (final row in rows) {
        await ensureProjectFromKeyRow(row, projectIdColumn: 'project_id');
      }
    }

    if (await _tableExists(db, 'project_device_rates')) {
      final rows = await db.query('project_device_rates');
      for (final row in rows) {
        await ensureProjectFromKeyRow(row, projectIdColumn: 'project_id');
      }
    }

    if (await _tableExists(db, 'account_project_merge_members')) {
      final rows = await db.query('account_project_merge_members');
      for (final row in rows) {
        final projectKey = (row['project_key'] as String?) ?? '';
        final parsed = ProjectKey.fromKey(projectKey);
        await ensureProject(
          projectId: (row['project_id'] as String?) ?? '',
          contact: parsed.contact.trim().isNotEmpty
              ? parsed.contact
              : (row['contact'] as String?) ?? '',
          site: parsed.site.trim().isNotEmpty
              ? parsed.site
              : (row['site'] as String?) ?? '',
          legacyProjectKey: projectKey,
        );
      }
    }
  }

  static Future<void> _ensureProjectForeignKeyTables(Database db) async {
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
    await _reindexMergeMembersForProjectId(db);
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

  static Future<bool> _columnExists(
    Database db,
    String table,
    String column,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table);');
    return columns.any((row) => row['name'] == column);
  }
}
