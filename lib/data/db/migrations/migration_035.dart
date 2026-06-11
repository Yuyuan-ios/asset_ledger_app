part of '../db_migrations.dart';

/// v35：单价整数分权威列（审计 P1-1 上半，指引切片 1-1）。
///
/// devices.default_unit_price / breaking_unit_price 与
/// project_device_rates.rate 此前只有 REAL 权威。本片为 additive 起步
/// （模式同 migration_029/033）：
/// - devices 增 nullable default_unit_price_fen / breaking_unit_price_fen，
///   按 round(REAL × 100) 回填；breaking 为 NULL 的行保持 NULL（语义：未单独
///   配置破碎单价，计算回落 default）。
/// - project_device_rates 增 nullable rate_fen，按 round(rate × 100) 回填。
/// 本片不重建表、不切换读路径：REAL 仍是业务读口径，fen 列是与之双写的
/// 镜像；读路径切换与 NOT NULL 翻转留待后续切片（1-4 / 重建同车）。
/// ensure* 幂等：列缺失则 ADD，值为 NULL 则回填，已有非 NULL 不被覆盖。
class Migration035 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 35) {
      await ensureUnitPriceFenColumns(db);
    }
  }

  static Future<void> ensureUnitPriceFenColumns(Database db) async {
    if (await _tableExists(db, 'devices')) {
      await _addColumnIfMissing(
        db,
        'devices',
        'default_unit_price_fen',
        'INTEGER',
      );
      await _addColumnIfMissing(
        db,
        'devices',
        'breaking_unit_price_fen',
        'INTEGER',
      );
      // 防御：极简/历史 schema 可能缺 REAL 源列，缺则只补列、跳过回填。
      if (await _columnExists(db, 'devices', 'default_unit_price')) {
        await db.execute('''
          UPDATE devices
          SET default_unit_price_fen =
            CAST(ROUND(default_unit_price * 100) AS INTEGER)
          WHERE default_unit_price_fen IS NULL;
        ''');
      }
      if (await _columnExists(db, 'devices', 'breaking_unit_price')) {
        await db.execute('''
          UPDATE devices
          SET breaking_unit_price_fen =
            CAST(ROUND(breaking_unit_price * 100) AS INTEGER)
          WHERE breaking_unit_price_fen IS NULL
            AND breaking_unit_price IS NOT NULL;
        ''');
      }
    }

    if (await _tableExists(db, 'project_device_rates')) {
      await _addColumnIfMissing(
        db,
        'project_device_rates',
        'rate_fen',
        'INTEGER',
      );
      if (await _columnExists(db, 'project_device_rates', 'rate')) {
        await db.execute('''
          UPDATE project_device_rates
          SET rate_fen = CAST(ROUND(rate * 100) AS INTEGER)
          WHERE rate_fen IS NULL;
        ''');
      }
    }
  }
}
