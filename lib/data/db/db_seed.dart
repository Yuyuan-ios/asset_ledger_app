import 'package:sqflite/sqflite.dart';

/// 数据库演示数据写入逻辑（仅开发/演示模式使用）。
class DbSeed {
  /// 若设备表非空则跳过；仅在空库时写入最小演示数据。
  static Future<void> seedDemoDataIfEmpty(Database db) async {
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM devices'),
        ) ??
        0;
    if (count > 0) return;

    await db.transaction((txn) async {
      await txn.insert('devices', {
        'name': 'SANY 1#',
        'brand': 'SANY',
        'model': null,
        'default_unit_price_fen': 35000,
        'breaking_unit_price_fen': null,
        'base_meter_hours': 0.0,
        'is_active': 1,
        'custom_avatar_path': null,
        'equipment_type': 'excavator',
      });

      await txn.insert('devices', {
        'name': 'SANY 2#',
        'brand': 'SANY',
        'model': null,
        'default_unit_price_fen': 36000,
        'breaking_unit_price_fen': null,
        'base_meter_hours': 120.0,
        'is_active': 1,
        'custom_avatar_path': null,
        'equipment_type': 'excavator',
      });
    });
  }
}
