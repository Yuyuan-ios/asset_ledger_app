import 'package:sqflite/sqflite.dart';

/// 数据库演示数据写入逻辑（仅开发/演示模式使用）。
class DbSeed {
  static const String appReviewDemoProjectId = 'project:app-review-demo';

  static const String _appReviewProjectContact = 'App Review Demo';
  static const String _appReviewProjectSite = 'Sample Site';
  static const String _appReviewProjectKey =
      '$_appReviewProjectContact||$_appReviewProjectSite';
  static const String _appReviewCreatedAt = '2026-06-01T00:00:00.000Z';

  /// 若设备表非空则跳过；仅在空库时写入最小演示数据。
  static Future<void> seedDemoDataIfEmpty(Database db) async {
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM devices'),
        ) ??
        0;
    if (count > 0) return;

    await db.transaction(_ensureAppReviewDemoData);
  }

  /// Ensures the App Review demo account has a complete sample ledger.
  ///
  /// This is invoked only after the fixed App Review demo account logs in. It
  /// does not alter subscription/IAP state and writes current integer-fen
  /// fields directly.
  static Future<void> seedAppReviewDemoData(Database db) async {
    await db.transaction(_ensureAppReviewDemoData);
  }

  static Future<void> _ensureAppReviewDemoData(Transaction txn) async {
    final firstDeviceId = await _ensureDevice(
      txn,
      name: 'Demo Excavator 1',
      brand: 'SANY',
      defaultUnitPriceFen: 35000,
      baseMeterHours: 0,
    );
    final secondDeviceId = await _ensureDevice(
      txn,
      name: 'Demo Loader 2',
      brand: 'XCMG',
      defaultUnitPriceFen: 36000,
      baseMeterHours: 120,
      equipmentType: 'loader',
    );

    await txn.insert('projects', {
      'id': appReviewDemoProjectId,
      'contact': _appReviewProjectContact,
      'site': _appReviewProjectSite,
      'status': 'active',
      'settled_at': null,
      'settled_snapshot': null,
      'created_at': _appReviewCreatedAt,
      'updated_at': _appReviewCreatedAt,
      'legacy_project_key': _appReviewProjectKey,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await _ensureProjectDeviceRate(txn, firstDeviceId, 35000);
    await _ensureProjectDeviceRate(txn, secondDeviceId, 36000);

    await _ensureTimingRecord(
      txn,
      deviceId: firstDeviceId,
      startDate: 20260610,
      startMeter: 1000,
      endMeter: 1008,
      hours: 8,
      incomeFen: 280000,
    );
    await _ensureTimingRecord(
      txn,
      deviceId: secondDeviceId,
      startDate: 20260612,
      startMeter: 220,
      endMeter: 226,
      hours: 6,
      incomeFen: 216000,
    );
    await _ensureAccountPayment(txn);
  }

  static Future<int> _ensureDevice(
    Transaction txn, {
    required String name,
    required String brand,
    required int defaultUnitPriceFen,
    required double baseMeterHours,
    String equipmentType = 'excavator',
  }) async {
    final existing = await txn.query(
      'devices',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return (existing.single['id'] as num).toInt();
    }

    return txn.insert('devices', {
      'name': name,
      'brand': brand,
      'model': null,
      'default_unit_price_fen': defaultUnitPriceFen,
      'breaking_unit_price_fen': null,
      'base_meter_hours': baseMeterHours,
      'is_active': 1,
      'custom_avatar_path': null,
      'equipment_type': equipmentType,
      'lifecycle_initial_cost_fen': null,
      'lifecycle_estimated_residual_fen': null,
    });
  }

  static Future<void> _ensureProjectDeviceRate(
    Transaction txn,
    int deviceId,
    int rateFen,
  ) async {
    await txn.insert('project_device_rates', {
      'project_id': appReviewDemoProjectId,
      'project_key': _appReviewProjectKey,
      'device_id': deviceId,
      'is_breaking': 0,
      'rate_fen': rateFen,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> _ensureTimingRecord(
    Transaction txn, {
    required int deviceId,
    required int startDate,
    required double startMeter,
    required double endMeter,
    required double hours,
    required int incomeFen,
  }) async {
    final existing = await txn.query(
      'timing_records',
      columns: ['id'],
      where: 'project_id = ? AND device_id = ? AND start_date = ?',
      whereArgs: [appReviewDemoProjectId, deviceId, startDate],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    await txn.insert('timing_records', {
      'project_id': appReviewDemoProjectId,
      'device_id': deviceId,
      'start_date': startDate,
      'allocation_cutoff_date': null,
      'display_end_date': null,
      'contact': _appReviewProjectContact,
      'site': _appReviewProjectSite,
      'type': 'hours',
      'start_meter': startMeter,
      'end_meter': endMeter,
      'hours': hours,
      'income_fen': incomeFen,
      'unit': 'HOUR',
      'quantity_scaled': (hours * 1000).round(),
      'exclude_from_fuel_eff': 0,
      'is_breaking': 0,
    });
  }

  static Future<void> _ensureAccountPayment(Transaction txn) async {
    final existing = await txn.query(
      'account_payments',
      columns: ['id'],
      where: 'project_id = ? AND ymd = ? AND amount_fen = ?',
      whereArgs: [appReviewDemoProjectId, 20260615, 150000],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    await txn.insert('account_payments', {
      'project_id': appReviewDemoProjectId,
      'project_key': _appReviewProjectKey,
      'ymd': 20260615,
      'amount_fen': 150000,
      'note': 'App Review demo payment',
      'source_type': 'manual',
      'merge_group_id': null,
      'merge_batch_id': null,
      'merge_batch_total_amount_fen': null,
      'merge_batch_note': null,
      'created_at': _appReviewCreatedAt,
    });
  }
}
