part of '../db_migrations.dart';

/// v54：移除 projects.idx_projects_active_legacy_key partial unique index。
///
/// 业务规则变更：同一 legacy_project_key 下现在允许多个 active 项目共存。
/// 场景举例：甲方·工地 的旧批次已结清，新批次进行中，用户需要撤销旧批次的
/// 结清状态时不再被阻断。
///
/// 旧规则"同 key 只允许一个 active 项目"由 partial unique index 和应用层
/// _ensureNoActiveProjectConflict 共同实现；两者均已随本版本移除。
class Migration054 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 54) {
      await _dropActiveScopedLegacyProjectKeyUniqueIndex(db);
    }
  }

  /// onOpen 兜底：拆掉历史库中遗留的 legacy_project_key 列级 UNIQUE，
  /// 并删除 v21-v53 曾使用的 active-scoped partial unique index。
  ///
  /// 列级 UNIQUE 需要重建 projects 表，只能在 sqflite onUpgrade 事务外执行。
  /// [apply] 因此只做事务安全的 DROP INDEX，完整修复由 DbSchemaCompat.ensure
  /// 在 onOpen 调用本方法完成。
  static Future<void> dropActiveScopedLegacyProjectKeyUniqueness(
    Database db,
  ) async {
    if (!await _tableExists(db, 'projects')) return;

    if (await _projectsHasLegacyKeyColumnUnique(db)) {
      await _rebuildProjectsWithoutLegacyKeyUnique(db);
    }

    await _dropActiveScopedLegacyProjectKeyUniqueIndex(db);
  }

  static Future<void> _dropActiveScopedLegacyProjectKeyUniqueIndex(
    Database db,
  ) async {
    if (!await _tableExists(db, 'projects')) return;
    await db.execute('DROP INDEX IF EXISTS idx_projects_active_legacy_key;');
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
        '请把 dropActiveScopedLegacyProjectKeyUniqueness 放到 onOpen / '
        'DbSchemaCompat.ensure 中执行。',
      );
    }
    try {
      await db.execute('DROP TABLE IF EXISTS projects_v54_no_unique;');
      await db.execute('''
        CREATE TABLE projects_v54_no_unique (
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
        INSERT INTO projects_v54_no_unique (
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
        'ALTER TABLE projects_v54_no_unique RENAME TO projects;',
      );

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
      throw StateError('projects legacy_project_key UNIQUE 重建后外键校验失败: $issues');
    }
  }
}
