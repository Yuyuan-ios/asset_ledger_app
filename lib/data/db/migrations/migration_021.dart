part of '../db_migrations.dart';

/// v21：移除 projects.legacy_project_key 的全局 UNIQUE 约束，改为
/// "同 legacy_project_key 下只允许一个 active 项目" 的 partial unique index。
///
/// 业务规则（business_rules_v1.md §1）：
/// - 已结清项目不再被自动复用，需要保留历史。
/// - 同一 legacy_project_key 下允许多个 settled 历史项目。
/// - 同一 legacy_project_key 下只允许一个 active 项目。
///
/// 全局 UNIQUE 会阻止 "已结清后再次开工" 的合法路径，因此必须移除。
///
/// 执行策略（重要）：
/// sqflite 的 onUpgrade 在事务内执行。SQLite 在事务内 `PRAGMA foreign_keys = OFF`
/// 不生效，而旧库已有 timing_records / account_payments / project_device_rates /
/// account_project_merge_members / external_work_records 通过 FK 反向引用 projects；
/// 在 onUpgrade 事务内 `DROP TABLE projects` 会触发 `FOREIGN KEY constraint failed`。
///
/// 因此本迁移在 onUpgrade（[apply]）路径中只把版本号推进到 21，**不做任何 DROP
/// 或 schema 重建**；真正的列级 UNIQUE 拆除 + partial unique index 建立由
/// [ensureActiveScopedLegacyProjectKeyUniqueness] 在 onOpen 路径（DbSchemaCompat.ensure）
/// 执行——那里没有 sqflite 管理的事务，PRAGMA foreign_keys = OFF 才会真正生效。
class Migration021 {
  /// onUpgrade 入口：刻意为空。
  ///
  /// 只为占位声明 v21 在迁移链中存在；真正动 schema 的工作放在
  /// [ensureActiveScopedLegacyProjectKeyUniqueness]，由 DbSchemaCompat.ensure
  /// 在 onOpen 中调用（在事务外、PRAGMA foreign_keys = OFF 生效的环境下）。
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    // 故意为空——见上方文档；任何在此处执行的 DROP/重建都会在 onUpgrade 事务
    // 内被 FK 阻断。
  }

  /// 幂等：DbSchemaCompat.ensure（onOpen）每次打开都会调用。
  /// - 若旧库带列级 UNIQUE：执行 rebuild（此时不在 sqflite onUpgrade 事务里，
  ///   PRAGMA foreign_keys = OFF 生效）。
  /// - 若已是新结构：仅幂等地确保 partial unique index 存在。
  static Future<void> ensureActiveScopedLegacyProjectKeyUniqueness(
    Database db,
  ) async {
    if (!await _tableExists(db, 'projects')) return;

    if (await _projectsHasLegacyKeyColumnUnique(db)) {
      await _rebuildProjectsWithoutLegacyKeyUnique(db);
    }

    // 即使无需 rebuild，仍幂等地确保 partial unique index 存在。
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_projects_active_legacy_key
      ON projects(legacy_project_key)
      WHERE legacy_project_key IS NOT NULL AND status = 'active';
    ''');
  }

  static Future<bool> _projectsHasLegacyKeyColumnUnique(Database db) async {
    final rows = await db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type='table' AND name='projects';",
    );
    if (rows.isEmpty) return false;
    final sql = (rows.single['sql'] as String?) ?? '';
    final match = RegExp(
      r'legacy_project_key[^,)\n]*',
      caseSensitive: false,
    ).firstMatch(sql);
    if (match == null) return false;
    return match.group(0)!.toUpperCase().contains('UNIQUE');
  }

  /// SQLite 不支持直接 ALTER 删除列级 UNIQUE，必须用 "12-step" 重建表。
  /// 期间临时关闭 foreign_keys，结束后用 PRAGMA foreign_key_check 校验。
  ///
  /// 必须在 sqflite **事务外** 调用（onOpen / DbSchemaCompat.ensure）。
  /// 如果检测到 PRAGMA foreign_keys = OFF 未生效（说明被事务包裹），抛错
  /// 而不是在 FK 仍然 ON 的状态下贸然 DROP，避免出现半改完的状态。
  static Future<void> _rebuildProjectsWithoutLegacyKeyUnique(
    Database db,
  ) async {
    await db.execute('PRAGMA foreign_keys = OFF;');
    final fkState = await db.rawQuery('PRAGMA foreign_keys;');
    final fkEnabled = (fkState.single.values.first as int?) == 1;
    if (fkEnabled) {
      // 仍为 ON：说明当前处于活动事务中，PRAGMA 被忽略；不能继续 rebuild。
      throw StateError(
        'projects rebuild 需在 sqflite 事务外执行；'
        'PRAGMA foreign_keys = OFF 未生效（疑似在 onUpgrade 事务内调用）。'
        '请把 ensureActiveScopedLegacyProjectKeyUniqueness 放到 onOpen / '
        'DbSchemaCompat.ensure 中执行。',
      );
    }
    try {
      await db.execute('DROP TABLE IF EXISTS projects_v21_no_unique;');
      await db.execute('''
        CREATE TABLE projects_v21_no_unique (
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
        INSERT INTO projects_v21_no_unique (
          id, contact, site, status, settled_at, settled_snapshot,
          created_at, updated_at, legacy_project_key
        )
        SELECT
          id, contact, site, status, settled_at, settled_snapshot,
          created_at, updated_at, legacy_project_key
        FROM projects;
      ''');
      await db.execute('DROP TABLE projects;');
      await db.execute(
        'ALTER TABLE projects_v21_no_unique RENAME TO projects;',
      );

      // 重建非 unique 索引（partial unique index 由调用方在外部 ensure）。
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_projects_legacy_key
        ON projects(legacy_project_key);
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_projects_active_contact_site
        ON projects(contact, site)
        WHERE status = 'active';
      ''');
    } finally {
      await db.execute('PRAGMA foreign_keys = ON;');
    }

    final issues = await db.rawQuery('PRAGMA foreign_key_check;');
    if (issues.isNotEmpty) {
      throw StateError(
        'projects legacy_project_key UNIQUE 重建后外键校验失败: $issues',
      );
    }
  }
}
