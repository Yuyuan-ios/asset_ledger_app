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
      await dropActiveScopedLegacyProjectKeyUniqueness(db);
    }
  }

  static Future<void> dropActiveScopedLegacyProjectKeyUniqueness(
    Database db,
  ) async {
    if (!await _tableExists(db, 'projects')) return;
    await db.execute(
      'DROP INDEX IF EXISTS idx_projects_active_legacy_key;',
    );
  }
}
