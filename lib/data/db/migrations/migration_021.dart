part of '../db_migrations.dart';

/// v21：历史版本曾计划移除 projects.legacy_project_key 的全局 UNIQUE 约束，
/// 并改为 active-scoped partial unique index。
///
/// 业务规则（business_rules_v1.md §1）：
/// - 已结清项目不再被自动复用，需要保留历史。
/// - 同一 legacy_project_key 下允许多个 settled 历史项目。
/// - 同一 legacy_project_key 下只允许一个 active 项目（此规则已由 v54 废弃）。
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
/// 或 schema 重建**。
///
/// v54 已废弃 active-scoped legacy key 唯一性；历史库遗留的列级 UNIQUE 与
/// partial unique index 现在统一由
/// [Migration054.dropActiveScopedLegacyProjectKeyUniqueness] 在 onOpen 路径
/// （DbSchemaCompat.ensure）处理。
class Migration021 {
  /// onUpgrade 入口：刻意为空。
  ///
  /// 只为占位声明 v21 在迁移链中存在；真正动 schema 的工作不能放在
  /// onUpgrade 事务里执行。
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    // 故意为空——见上方文档；任何在此处执行的 DROP/重建都会在 onUpgrade 事务
    // 内被 FK 阻断。
  }
}
