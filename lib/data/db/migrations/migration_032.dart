part of '../db_migrations.dart';

/// v32：timing_records 增加 nullable display_end_date。
///
/// display_end_date 是 rent/台班 UI inclusive 展示结束日（YYYYMMDD），仅用于
/// 记录展示与编辑回填。迁移为 additive：只补 nullable INTEGER 列，不回填、不重建表、
/// 不改变 allocation_cutoff_date / income_fen / 收入账户结清口径。
class Migration032 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 32) {
      await ensureTimingDisplayEndDate(db);
    }
  }

  static Future<void> ensureTimingDisplayEndDate(Database db) async {
    if (!await _tableExists(db, 'timing_records')) {
      return;
    }

    await _addColumnIfMissing(
      db,
      'timing_records',
      'display_end_date',
      'INTEGER',
    );
  }
}
