part of '../db_migrations.dart';

/// v25：timing_records 增加 nullable allocation_cutoff_date。
///
/// 该列仅保存未来显式分摊右开边界（YYYYMMDD）；null 时继续使用当前
/// legacy 隐式分摊规则。迁移只补持久化字段，不接入统计、账户或 UI 逻辑。
class Migration025 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 25) {
      await ensureTimingAllocationCutoffDate(db);
    }
  }

  static Future<void> ensureTimingAllocationCutoffDate(Database db) async {
    if (!await _tableExists(db, 'timing_records')) {
      return;
    }

    await _addColumnIfMissing(
      db,
      'timing_records',
      'allocation_cutoff_date',
      'INTEGER',
    );
  }
}
