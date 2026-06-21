part of '../db_migrations.dart';

/// v52：devices 新增生命周期回本金额（nullable）。
///
/// 语义：单位为分；null = 未设置，0 = 用户明确填 0。仅用于本地 DB 与
/// 本地备份恢复。本字段为设备级本地配置，刻意不纳入跨端 sync。
/// additive：旧库无列时补列，不回填、不重建表。
class Migration052 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 52) {
      await ensureDeviceLifecyclePaybackAmountColumns(db);
    }
  }

  static Future<void> ensureDeviceLifecyclePaybackAmountColumns(
    Database db,
  ) async {
    if (!await _tableExists(db, 'devices')) return;
    await _addColumnIfMissing(
      db,
      'devices',
      'lifecycle_initial_cost_fen',
      'INTEGER',
    );
    await _addColumnIfMissing(
      db,
      'devices',
      'lifecycle_estimated_residual_fen',
      'INTEGER',
    );
  }
}
