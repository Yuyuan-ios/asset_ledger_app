part of '../db_migrations.dart';

class ProjectIdentityMigration {
  static Future<void> ensure(
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
      await ProjectForeignKeyMigration.ensure(db);
    }
  }

  static Future<void> _ensureProjectsTable(Database db) async {
    // 新建路径不再使用全局 UNIQUE 约束（见 v21 迁移说明）；同一 legacy_project_key
    // 下只允许一个 active 项目由 v21 创建的 partial unique index 强制。
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
        legacy_project_key TEXT
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

    // Partial unique index：同 legacy_project_key 下只允许一个 active 项目；
    // 已结清的历史项目可以与新 active 项目共享同一 legacy_project_key。
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_projects_active_legacy_key
      ON projects(legacy_project_key)
      WHERE legacy_project_key IS NOT NULL AND status = 'active';
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
}
