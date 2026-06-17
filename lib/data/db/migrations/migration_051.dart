part of '../db_migrations.dart';

/// v51：external_work_records 新增 customer_unit_price_fen（nullable）。
///
/// 语义：我对项目方/客户设置的客户侧应收单价（分）。null = 未设客户单价。
/// 与应付侧 source/local/amount 解耦：应付在分享人侧已定、不可改，此列只决定
/// 账户页外协客户侧应收（应收 = customer_unit_price_fen × 工时）。additive：
/// 旧库无此列时补一列，不回填、不重建表。
class Migration051 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 51) {
      await ensureExternalWorkCustomerPriceColumn(db);
    }
  }

  static Future<void> ensureExternalWorkCustomerPriceColumn(Database db) async {
    if (!await _tableExists(db, 'external_work_records')) return;
    await _addColumnIfMissing(
      db,
      'external_work_records',
      'customer_unit_price_fen',
      'INTEGER CHECK (customer_unit_price_fen IS NULL '
          'OR customer_unit_price_fen >= 0)',
    );
  }
}
