part of '../db_migrations.dart';

/// v37（Track A / money-fen 收口 A1）：给 `fuel_logs.cost` 与
/// `maintenance_records.amount` 补 `*_fen INTEGER` 影子列并回填。
///
/// 这两张表是 money_real_migration_plan 里仅剩从未做 additive 的金额字段
/// （加油成本 / 维保金额，均非同步实体）。本片只做 additive：
/// - 加 `cost_fen` / `amount_fen`（nullable，与既有 additive fen 列风格一致）。
/// - 回填 `= CAST(ROUND(COALESCE(x, 0) * 100.0) AS INTEGER)`，只填 NULL，幂等。
/// - REAL 列保持权威，fen 仅为影子；权威切换与 NOT NULL 收紧留待 A2/A3。
///
/// 回填口径与 [Migration018]（account_payments / project_write_offs）、
/// [Migration029]（timing income_fen）逐字一致，保证全 App fen 派生同源。
class Migration037 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 37) {
      await ensureFuelMaintenanceMoneyFen(db);
    }
  }

  static Future<void> ensureFuelMaintenanceMoneyFen(Database db) async {
    if (await _tableExists(db, 'fuel_logs')) {
      await _addColumnIfMissing(db, 'fuel_logs', 'cost_fen', 'INTEGER');
      await db.execute('''
        UPDATE fuel_logs
        SET cost_fen = CAST(ROUND(COALESCE(cost, 0) * 100.0) AS INTEGER)
        WHERE cost_fen IS NULL;
      ''');
    }

    if (await _tableExists(db, 'maintenance_records')) {
      await _addColumnIfMissing(
        db,
        'maintenance_records',
        'amount_fen',
        'INTEGER',
      );
      await db.execute('''
        UPDATE maintenance_records
        SET amount_fen = CAST(ROUND(COALESCE(amount, 0) * 100.0) AS INTEGER)
        WHERE amount_fen IS NULL;
      ''');
    }
  }
}
