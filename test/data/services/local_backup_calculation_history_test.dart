import 'dart:convert';
import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:asset_ledger/data/models/project_key.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/services/local_backup_export_service.dart';
import 'package:asset_ledger/data/services/local_backup_import_preview_service.dart';
import 'package:asset_ledger/data/services/local_backup_restore_service.dart';
import 'package:asset_ledger/data/repositories/timing_calculation_history_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory documentsDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp(
      'asset_ledger_backup_test_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return documentsDir.path;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null),
    );
    await AppDatabase.resetForTest();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
    if (await documentsDir.exists()) {
      await documentsDir.delete(recursive: true);
    }
  });

  test('export includes timing_calculation_history rows and counts', () async {
    final db = await _openCurrentInMemoryDb();
    await _seedDevice(db, id: 1);
    await _seedTimingRecord(db, id: 7, deviceId: 1);
    await _seedCalculationHistory(
      db,
      id: 'history-1',
      timingRecordId: 7,
      expression: '8+8',
      result: 16.0,
      ticketCount: 2,
    );

    final result = await LocalBackupExportService.exportJsonBackup();

    expect(result.success, isTrue);
    final rawJson = await File(result.filePath!).readAsString();
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final summary = decoded['summary'] as Map<String, dynamic>;
    final tableCounts = summary['table_counts'] as Map<String, dynamic>;
    final histories = data['timing_calculation_history'] as List<dynamic>;

    expect(tableCounts['timing_calculation_history'], 1);
    expect(histories, hasLength(1));
    expect(histories.single, {
      'id': 'history-1',
      'timing_record_id': 7,
      'created_at': '2026-05-14T15:32:00.000Z',
      'expression': '8+8',
      'result': 16.0,
      'ticket_count': 2,
    });
  });

  test('export includes account project merge groups and members', () async {
    final db = await _openCurrentInMemoryDb();
    await _seedMergeGroup(db);
    await _seedMergeMember(
      db,
      id: 11,
      projectKey: '甲方||一号工地',
      site: '一号工地',
      sortOrder: 0,
    );
    await _seedMergeMember(
      db,
      id: 12,
      projectKey: '甲方||二号工地',
      site: '二号工地',
      sortOrder: 1,
    );

    final result = await LocalBackupExportService.exportJsonBackup();

    expect(result.success, isTrue);
    final rawJson = await File(result.filePath!).readAsString();
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final summary = decoded['summary'] as Map<String, dynamic>;
    final tableCounts = summary['table_counts'] as Map<String, dynamic>;
    final groups = data['account_project_merge_groups'] as List<dynamic>;
    final members = data['account_project_merge_members'] as List<dynamic>;

    expect(tableCounts['account_project_merge_groups'], 1);
    expect(tableCounts['account_project_merge_members'], 2);
    expect(groups.single['contact'], '甲方');
    expect(members.map((row) => row['project_key']).toList(), [
      '甲方||一号工地',
      '甲方||二号工地',
    ]);
  });

  test('export includes account payment merge batch fields', () async {
    final db = await _openCurrentInMemoryDb();
    await _seedAccountPayment(
      db,
      _paymentMap(
        sourceType: AccountPayment.sourceTypeMergeAllocation,
        mergeGroupId: 3,
        mergeBatchId: 'batch-1',
        mergeBatchTotalAmount: 5000,
        mergeBatchNote: '微信收款',
        createdAt: '2026-05-16T01:02:03.000Z',
      ),
    );

    final result = await LocalBackupExportService.exportJsonBackup();

    expect(result.success, isTrue);
    final rawJson = await File(result.filePath!).readAsString();
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final payments = data['account_payments'] as List<dynamic>;

    expect(payments, hasLength(1));
    expect(payments.single, {
      'id': 1,
      'project_id': _projectIdForKey('甲方||一号工地'),
      'project_key': '甲方||一号工地',
      'ymd': 20260515,
      'amount_fen': 50000,
      'note': '收款',
      'source_type': AccountPayment.sourceTypeMergeAllocation,
      'merge_group_id': 3,
      'merge_batch_id': 'batch-1',
      'merge_batch_total_amount_fen': 500000,
      'merge_batch_note': '微信收款',
      'created_at': '2026-05-16T01:02:03.000Z',
    });
  });

  test('export includes project write-offs and counts', () async {
    final db = await _openCurrentInMemoryDb();
    await _seedProjectWriteOff(
      db,
      _writeOffMap(
        id: 'write-off-1',
        amount: 60,
        reason: ProjectWriteOffReason.rounding.dbValue,
      ),
    );

    final result = await LocalBackupExportService.exportJsonBackup();

    expect(result.success, isTrue);
    final rawJson = await File(result.filePath!).readAsString();
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final summary = decoded['summary'] as Map<String, dynamic>;
    final tableCounts = summary['table_counts'] as Map<String, dynamic>;
    final writeOffs = data['project_write_offs'] as List<dynamic>;

    expect(tableCounts['project_write_offs'], 1);
    expect(writeOffs, hasLength(1));
    expect(writeOffs.single, {
      'id': 'write-off-1',
      'project_id': _projectIdForKey('甲方||一号工地'),
      'amount_fen': 6000,
      'reason': ProjectWriteOffReason.rounding.dbValue,
      'note': '尾款不再追收',
      'write_off_date': '2026-05-18',
      'created_at': '2026-05-18T00:00:00.000Z',
      'updated_at': '2026-05-18T00:00:00.000Z',
    });
  });

  test('export includes projects and project_id child links', () async {
    final db = await _openCurrentInMemoryDb();
    await _seedDevice(db, id: 1);
    await _seedTimingRecord(db, id: 7, deviceId: 1);
    await _seedAccountPayment(db, _paymentMap(includeProjectId: true));
    await db.insert(
      'project_device_rates',
      _projectRateMap(includeProjectId: true),
    );

    final result = await LocalBackupExportService.exportJsonBackup();

    expect(result.success, isTrue);
    final rawJson = await File(result.filePath!).readAsString();
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final projects = data['projects'] as List<dynamic>;
    final timings = data['timing_records'] as List<dynamic>;
    final payments = data['account_payments'] as List<dynamic>;
    final rates = data['project_device_rates'] as List<dynamic>;

    expect(projects, hasLength(1));
    expect(projects.single['id'], _projectIdForKey('甲方||一号工地'));
    expect(timings.single['project_id'], projects.single['id']);
    expect(payments.single['project_id'], projects.single['id']);
    expect(rates.single['project_id'], projects.single['id']);
  });

  test('preview counts timing_calculation_history when present', () {
    final preview = const LocalBackupImportPreviewService()
        .previewFromDecodedJson(
          _backupJson(
            calculationHistories: [
              _historyMap(id: 'history-1', expression: '8+8'),
              _historyMap(id: 'history-2', expression: '7+5'),
            ],
          ),
        );

    expect(preview.isValid, isTrue);
    expect(preview.tableCounts['timing_calculation_history'], 2);
  });

  test('preview accepts legacy branded backups', () {
    final preview = const LocalBackupImportPreviewService()
        .previewFromDecodedJson(_backupJson(appName: '机账通'));

    expect(preview.isValid, isTrue);
  });

  test('preview counts merge tables when present', () {
    final preview = const LocalBackupImportPreviewService()
        .previewFromDecodedJson(
          _backupJson(
            schemaVersion: AppDatabase.schemaVersion,
            mergeGroups: [_mergeGroupMap()],
            mergeMembers: [
              _mergeMemberMap(id: 11, projectKey: '甲方||一号工地', site: '一号工地'),
              _mergeMemberMap(
                id: 12,
                projectKey: '甲方||二号工地',
                site: '二号工地',
                sortOrder: 1,
              ),
            ],
          ),
        );

    expect(preview.isValid, isTrue);
    expect(preview.tableCounts['account_project_merge_groups'], 1);
    expect(preview.tableCounts['account_project_merge_members'], 2);
    expect(preview.projectCount, 2);
    expect(preview.accountCount, 1);
  });

  test('preview counts project write-offs when present', () {
    final preview = const LocalBackupImportPreviewService()
        .previewFromDecodedJson(
          _backupJson(
            schemaVersion: AppDatabase.schemaVersion,
            projectWriteOffs: [
              _writeOffMap(id: 'write-off-1'),
              _writeOffMap(id: 'write-off-2', amount: 40),
            ],
          ),
        );

    expect(preview.isValid, isTrue);
    expect(preview.tableCounts['project_write_offs'], 2);
  });

  test('preview counts new projects table without splitting project ids', () {
    final preview = const LocalBackupImportPreviewService()
        .previewFromDecodedJson(
          _backupJson(
            exportFormatVersion: 2,
            schemaVersion: AppDatabase.schemaVersion,
            projects: [
              _projectMap(
                projectKey: ProjectKey.buildKey(
                  contact: '甲方||分公司',
                  site: '一号||二号工地',
                ),
              ),
            ],
            timingRecords: [
              _timingRecordMap(id: 7, deviceId: 1, includeProjectId: true),
            ],
          ),
        );

    expect(preview.isValid, isTrue);
    expect(preview.projectCount, 1);
  });

  test('preview accepts old backups without account payment merge fields', () {
    final preview = const LocalBackupImportPreviewService()
        .previewFromDecodedJson(
          _backupJson(
            schemaVersion: 11,
            accountPayments: [_legacyPaymentMap()],
          ),
        );

    expect(preview.isValid, isTrue);
    expect(preview.tableCounts['account_payments'], 1);
  });

  test('preview accepts v9 backups without timing_calculation_history', () {
    final preview = const LocalBackupImportPreviewService()
        .previewFromDecodedJson(
          _backupJson(schemaVersion: 9, includeCalculationHistoryTable: false),
        );

    expect(preview.isValid, isTrue);
    expect(preview.warningMessage, isNotNull);
    expect(preview.tableCounts['timing_calculation_history'], 0);
    expect(preview.tableCounts['account_project_merge_groups'], 0);
    expect(preview.tableCounts['account_project_merge_members'], 0);
  });

  test(
    'restore restores calculation histories and clears stale histories',
    () async {
      final db = await _openCurrentInMemoryDb();
      await _seedDevice(db, id: 99);
      await _seedTimingRecord(db, id: 99, deviceId: 99);
      await _seedCalculationHistory(
        db,
        id: 'stale-history',
        timingRecordId: 99,
        expression: '1+1',
        result: 2.0,
        ticketCount: 2,
      );

      final result = await _restoreService().restoreFromDecodedJson(
        _backupJson(
          calculationHistories: [
            _historyMap(
              id: 'history-1',
              expression: '8+8',
              result: 16.0,
              ticketCount: 2,
              createdAt: '2026-05-14T15:32:00.000Z',
            ),
            _historyMap(
              id: 'history-2',
              expression: '8+8.2',
              result: 16.2,
              ticketCount: 2,
              createdAt: '2026-05-14T15:40:00.000Z',
            ),
          ],
        ),
      );

      expect(result.success, isTrue);
      expect(result.restoredCounts['timing_calculation_history'], 2);

      final histories = await SqfliteTimingCalculationHistoryRepository()
          .findByTimingRecordId(7);
      expect(histories.map((history) => history.id).toList(), [
        'history-2',
        'history-1',
      ]);
      expect(histories.last.expression, '8+8');
      expect(histories.last.result, 16.0);
      expect(histories.last.ticketCount, 2);
      expect(histories.last.createdAt, DateTime.utc(2026, 5, 14, 15, 32));

      final staleRows = await db.query(
        'timing_calculation_history',
        where: 'id = ?',
        whereArgs: ['stale-history'],
      );
      expect(staleRows, isEmpty);
    },
  );

  test('restore restores account project merge groups and members', () async {
    final db = await _openCurrentInMemoryDb();

    final result = await _restoreService().restoreFromDecodedJson(
      _backupJson(
        schemaVersion: AppDatabase.schemaVersion,
        mergeGroups: [_mergeGroupMap()],
        mergeMembers: [
          _mergeMemberMap(id: 11, projectKey: '甲方||一号工地', site: '一号工地'),
          _mergeMemberMap(
            id: 12,
            projectKey: '甲方||二号工地',
            site: '二号工地',
            sortOrder: 1,
          ),
        ],
      ),
    );

    expect(result.success, isTrue);
    expect(result.restoredCounts['account_project_merge_groups'], 1);
    expect(result.restoredCounts['account_project_merge_members'], 2);

    final groups = await db.query('account_project_merge_groups');
    final members = await db.query(
      'account_project_merge_members',
      orderBy: 'sort_order ASC',
    );
    expect(groups, hasLength(1));
    expect(groups.single['contact'], '甲方');
    expect(groups.single['is_active'], 1);
    expect(members.map((row) => row['project_key']).toList(), [
      '甲方||一号工地',
      '甲方||二号工地',
    ]);
    expect(members.map((row) => row['group_id']).toSet(), {1});
  });

  test(
    'restore accepts old backups without account payment merge fields',
    () async {
      final db = await _openCurrentInMemoryDb();

      final result = await _restoreService().restoreFromDecodedJson(
        _backupJson(schemaVersion: 11, accountPayments: [_legacyPaymentMap()]),
      );

      expect(result.success, isTrue);
      expect(result.restoredCounts['account_payments'], 1);

      final payment = (await db.query('account_payments')).single;
      expect(payment['source_type'], AccountPayment.sourceTypeManual);
      expect(payment['merge_group_id'], isNull);
      expect(payment['merge_batch_id'], isNull);
      expect(payment.containsKey('amount'), isFalse);
      expect(payment['amount_fen'], 50000);
      expect(payment.containsKey('merge_batch_total_amount'), isFalse);
      expect(payment['merge_batch_total_amount_fen'], isNull);
      expect(payment['merge_batch_note'], isNull);
      expect(payment['created_at'], isNull);
    },
  );

  test('restore accepts old backups without device equipment type', () async {
    final db = await _openCurrentInMemoryDb();
    final legacyDevice = _deviceMap(id: 1)..remove('equipment_type');

    final result = await _restoreService().restoreFromDecodedJson(
      _backupJson(schemaVersion: 9, devices: [legacyDevice]),
    );

    expect(result.success, isTrue);
    final device = (await db.query('devices')).single;
    expect(device['equipment_type'], 'excavator');
  });

  test('restore round-trips legacy device unit prices into fen only', () async {
    final db = await _openCurrentInMemoryDb();
    final legacyDevice = _deviceMap(id: 1)
      ..remove('default_unit_price_fen')
      ..remove('breaking_unit_price_fen')
      ..['default_unit_price'] = 123.45
      ..['breaking_unit_price'] = 456.78;

    final result = await _restoreService().restoreFromDecodedJson(
      _backupJson(schemaVersion: 38, devices: [legacyDevice]),
    );

    expect(result.success, isTrue);
    final device = (await db.query('devices')).single;
    expect(device.containsKey('default_unit_price'), isFalse);
    expect(device.containsKey('breaking_unit_price'), isFalse);
    expect(device['default_unit_price_fen'], 12345);
    expect(device['breaking_unit_price_fen'], 45678);

    final export = await LocalBackupExportService.exportJsonBackup();
    expect(export.success, isTrue);
    final rawJson = await File(export.filePath!).readAsString();
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final exportedDevice =
        (data['devices'] as List<dynamic>).single as Map<String, dynamic>;
    expect(exportedDevice.containsKey('default_unit_price'), isFalse);
    expect(exportedDevice.containsKey('breaking_unit_price'), isFalse);
    expect(exportedDevice['default_unit_price_fen'], 12345);
    expect(exportedDevice['breaking_unit_price_fen'], 45678);
  });

  test('restore round-trips legacy fuel cost into cost_fen only', () async {
    final db = await _openCurrentInMemoryDb();
    final legacyFuel = _fuelLogMap(id: 1, cost: 123.45)..remove('cost_fen');

    final result = await _restoreService().restoreFromDecodedJson(
      _backupJson(schemaVersion: 36, fuelLogs: [legacyFuel]),
    );

    expect(result.success, isTrue);
    final fuel = (await db.query('fuel_logs')).single;
    expect(fuel.containsKey('cost'), isFalse);
    expect(fuel['cost_fen'], 12345);

    final export = await LocalBackupExportService.exportJsonBackup();
    expect(export.success, isTrue);
    final rawJson = await File(export.filePath!).readAsString();
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final exportedFuel =
        (data['fuel_logs'] as List<dynamic>).single as Map<String, dynamic>;
    expect(exportedFuel.containsKey('cost'), isFalse);
    expect(exportedFuel['cost_fen'], 12345);
  });

  test(
    'restore round-trips legacy account payment amounts into fen only',
    () async {
      final db = await _openCurrentInMemoryDb();
      final legacyPayment =
          _paymentMap(
              amount: 123.45,
              includeLegacyAmount: true,
              includeProjectId: true,
              sourceType: AccountPayment.sourceTypeMergeAllocation,
              mergeGroupId: 3,
              mergeBatchId: 'batch-legacy',
              mergeBatchTotalAmount: 600.0,
              includeLegacyMergeBatchTotalAmount: true,
              mergeBatchNote: 'legacy merge',
              createdAt: '2026-05-16T01:02:03.000Z',
            )
            ..remove('amount_fen')
            ..remove('merge_batch_total_amount_fen');

      final result = await _restoreService().restoreFromDecodedJson(
        _backupJson(
          schemaVersion: 31,
          projects: [_projectMap()],
          timingRecords: [],
          accountPayments: [legacyPayment],
        ),
      );

      expect(result.success, isTrue);

      final row = (await db.query('account_payments')).single;
      expect(row.containsKey('amount'), isFalse);
      expect(row['amount_fen'], 12345);
      expect(row.containsKey('merge_batch_total_amount'), isFalse);
      expect(row['merge_batch_total_amount_fen'], 60000);

      final exported = await LocalBackupExportService.exportJsonBackup();
      expect(exported.success, isTrue);
      final rawJson = await File(exported.filePath!).readAsString();
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;
      final exportedPayment =
          (data['account_payments'] as List<dynamic>).single
              as Map<String, dynamic>;
      expect(exportedPayment.containsKey('amount'), isFalse);
      expect(exportedPayment['amount_fen'], 12345);
      expect(exportedPayment.containsKey('merge_batch_total_amount'), isFalse);
      expect(exportedPayment['merge_batch_total_amount_fen'], 60000);
    },
  );

  test(
    'restore round-trips legacy maintenance amount into amount_fen only',
    () async {
      final db = await _openCurrentInMemoryDb();
      final legacyMaintenance = _maintenanceMap(id: 1, amount: 234.56)
        ..remove('amount_fen');

      final result = await _restoreService().restoreFromDecodedJson(
        _backupJson(schemaVersion: 40, maintenanceRecords: [legacyMaintenance]),
      );

      expect(result.success, isTrue);
      final row = (await db.query('maintenance_records')).single;
      expect(row.containsKey('amount'), isFalse);
      expect(row['amount_fen'], 23456);

      final export = await LocalBackupExportService.exportJsonBackup();
      expect(export.success, isTrue);
      final rawJson = await File(export.filePath!).readAsString();
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;
      final exportedMaintenance =
          (data['maintenance_records'] as List<dynamic>).single
              as Map<String, dynamic>;
      expect(exportedMaintenance.containsKey('amount'), isFalse);
      expect(exportedMaintenance['amount_fen'], 23456);
    },
  );

  test(
    'restore accepts old backups without project rate breaking flag',
    () async {
      final db = await _openCurrentInMemoryDb();
      final legacyRate = _projectRateMap(includeLegacyRate: true)
        ..remove('is_breaking')
        ..remove('rate_fen');

      final result = await _restoreService().restoreFromDecodedJson(
        _backupJson(schemaVersion: 7, projectDeviceRates: [legacyRate]),
      );

      expect(result.success, isTrue);
      final rate = (await db.query('project_device_rates')).single;
      expect(rate['is_breaking'], 0);
    },
  );

  test('restore round-trips legacy project rate into rate_fen only', () async {
    final db = await _openCurrentInMemoryDb();
    final legacyRate = _projectRateMap(rate: 123.45, includeLegacyRate: true)
      ..remove('rate_fen');

    final result = await _restoreService().restoreFromDecodedJson(
      _backupJson(schemaVersion: 34, projectDeviceRates: [legacyRate]),
    );

    expect(result.success, isTrue);
    final rate = (await db.query('project_device_rates')).single;
    expect(rate.containsKey('rate'), isFalse);
    expect(rate['rate_fen'], 12345);

    final export = await LocalBackupExportService.exportJsonBackup();
    expect(export.success, isTrue);
    final rawJson = await File(export.filePath!).readAsString();
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final exportedRate =
        (data['project_device_rates'] as List<dynamic>).single
            as Map<String, dynamic>;
    expect(exportedRate.containsKey('rate'), isFalse);
    expect(exportedRate['rate_fen'], 12345);
  });

  test(
    'restore round-trips legacy write-off amount into amount_fen only',
    () async {
      final db = await _openCurrentInMemoryDb();
      final legacyWriteOff = _writeOffMap(
        id: 'write-off-legacy',
        amount: 98.76,
        includeLegacyAmount: true,
      )..remove('amount_fen');

      final result = await _restoreService().restoreFromDecodedJson(
        _backupJson(schemaVersion: 29, projectWriteOffs: [legacyWriteOff]),
      );

      expect(result.success, isTrue);
      final row = (await db.query('project_write_offs')).single;
      expect(row.containsKey('amount'), isFalse);
      expect(row['amount_fen'], 9876);

      final export = await LocalBackupExportService.exportJsonBackup();
      expect(export.success, isTrue);
      final rawJson = await File(export.filePath!).readAsString();
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;
      final exportedWriteOff =
          (data['project_write_offs'] as List<dynamic>).single
              as Map<String, dynamic>;
      expect(exportedWriteOff.containsKey('amount'), isFalse);
      expect(exportedWriteOff['amount_fen'], 9876);
    },
  );

  test('restore accepts old backups without timing contact and site', () async {
    final db = await _openCurrentInMemoryDb();
    final legacyTimingRecord = _timingRecordMap(id: 7, deviceId: 1)
      ..remove('contact')
      ..remove('site');

    final result = await _restoreService().restoreFromDecodedJson(
      _backupJson(schemaVersion: 8, timingRecords: [legacyTimingRecord]),
    );

    expect(result.success, isTrue);
    final record = (await db.query('timing_records')).single;
    expect(record['contact'], '');
    expect(record['site'], '');
  });

  test(
    'restore creates projects and project_id links for old backups',
    () async {
      final db = await _openCurrentInMemoryDb();

      final result = await _restoreService().restoreFromDecodedJson(
        _backupJson(
          schemaVersion: 8,
          accountPayments: [_legacyPaymentMap()],
          projectDeviceRates: [_projectRateMap()],
          mergeGroups: [_mergeGroupMap()],
          mergeMembers: [
            _mergeMemberMap(id: 11, projectKey: '甲方||一号工地', site: '一号工地'),
          ],
        ),
      );

      expect(result.success, isTrue);
      final projects = await db.query('projects');
      expect(projects, hasLength(1));
      final projectId = projects.single['id'];
      expect(
        (await db.query('timing_records')).single['project_id'],
        projectId,
      );
      expect(
        (await db.query('account_payments')).single['project_id'],
        projectId,
      );
      expect(
        (await db.query('project_device_rates')).single['project_id'],
        projectId,
      );
      expect(
        (await db.query('account_project_merge_members')).single['project_id'],
        projectId,
      );
    },
  );

  test('restore rejects invalid timing type before database insert', () async {
    final invalidTimingRecord = _timingRecordMap(id: 7, deviceId: 1)
      ..['type'] = 'monthly';

    final result = await _restoreService().restoreFromDecodedJson(
      _backupJson(timingRecords: [invalidTimingRecord]),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'invalid_timing_records_type');
  });

  test(
    'restore rejects invalid boolean and source values without clearing db',
    () async {
      final db = await _openCurrentInMemoryDb();
      await _seedDevice(db, id: 99);

      final invalidTimingRecord = _timingRecordMap(id: 7, deviceId: 1)
        ..['is_breaking'] = 2;
      final timingResult = await _restoreService().restoreFromDecodedJson(
        _backupJson(timingRecords: [invalidTimingRecord]),
      );
      expect(timingResult.success, isFalse);
      expect(timingResult.errorCode, 'invalid_timing_records_is_breaking');
      expect(await db.query('devices', where: 'id = 99'), hasLength(1));

      final invalidPayment = _paymentMap(sourceType: 'unknown_source');
      final paymentResult = await _restoreService().restoreFromDecodedJson(
        _backupJson(accountPayments: [invalidPayment]),
      );
      expect(paymentResult.success, isFalse);
      expect(paymentResult.errorCode, 'invalid_account_payments_source_type');
      expect(await db.query('devices', where: 'id = 99'), hasLength(1));

      final invalidRate = _projectRateMap(isBreaking: -1);
      final rateResult = await _restoreService().restoreFromDecodedJson(
        _backupJson(projectDeviceRates: [invalidRate]),
      );
      expect(rateResult.success, isFalse);
      expect(rateResult.errorCode, 'invalid_project_device_rates_is_breaking');
      expect(await db.query('devices', where: 'id = 99'), hasLength(1));
    },
  );

  test(
    'restore rejects orphan project_id before clearing existing db',
    () async {
      final db = await _openCurrentInMemoryDb();
      await _seedDevice(db, id: 99);
      final orphanTimingRecord = _timingRecordMap(
        id: 7,
        deviceId: 1,
        includeProjectId: true,
      )..['project_id'] = 'project:missing';

      final result = await _restoreService().restoreFromDecodedJson(
        _backupJson(
          exportFormatVersion: 2,
          schemaVersion: AppDatabase.schemaVersion,
          projects: [_projectMap()],
          timingRecords: [orphanTimingRecord],
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorCode, 'orphan_project_id_timing_records');
      expect(await db.query('devices', where: 'id = 99'), hasLength(1));
    },
  );

  test('restore preserves account payment merge batch fields', () async {
    final db = await _openCurrentInMemoryDb();

    final result = await _restoreService().restoreFromDecodedJson(
      _backupJson(
        schemaVersion: AppDatabase.schemaVersion,
        accountPayments: [
          _paymentMap(
            sourceType: AccountPayment.sourceTypeMergeAllocation,
            mergeGroupId: 3,
            mergeBatchId: 'batch-1',
            mergeBatchTotalAmount: 5000,
            mergeBatchNote: '微信收款',
            createdAt: '2026-05-16T01:02:03.000Z',
          ),
        ],
      ),
    );

    expect(result.success, isTrue);
    expect(result.restoredCounts['account_payments'], 1);

    final payment = (await db.query('account_payments')).single;
    expect(payment['source_type'], AccountPayment.sourceTypeMergeAllocation);
    expect(payment['merge_group_id'], 3);
    expect(payment['merge_batch_id'], 'batch-1');
    expect(payment.containsKey('amount'), isFalse);
    expect(payment['amount_fen'], 50000);
    expect(payment.containsKey('merge_batch_total_amount'), isFalse);
    expect(payment['merge_batch_total_amount_fen'], 500000);
    expect(payment['merge_batch_note'], '微信收款');
    expect(payment['created_at'], '2026-05-16T01:02:03.000Z');
  });

  test('restore restores project write-offs', () async {
    final db = await _openCurrentInMemoryDb();

    final result = await _restoreService().restoreFromDecodedJson(
      _backupJson(
        exportFormatVersion: 2,
        schemaVersion: AppDatabase.schemaVersion,
        projects: [_projectMap()],
        timingRecords: [
          _timingRecordMap(id: 7, deviceId: 1, includeProjectId: true),
        ],
        projectWriteOffs: [_writeOffMap(id: 'write-off-1')],
      ),
    );

    expect(result.success, isTrue);
    expect(result.restoredCounts['project_write_offs'], 1);

    final rows = await db.query('project_write_offs');
    expect(rows, hasLength(1));
    expect(rows.single['id'], 'write-off-1');
    expect(rows.single['project_id'], _projectIdForKey('甲方||一号工地'));
    expect(rows.single.containsKey('amount'), isFalse);
    expect(rows.single['amount_fen'], 6000);
    expect(rows.single['reason'], ProjectWriteOffReason.rounding.dbValue);
  });

  test('exported backup restores in a round trip', () async {
    final db = await _openCurrentInMemoryDb();
    await _seedDevice(db, id: 1);
    await _seedTimingRecord(db, id: 7, deviceId: 1);
    await _seedCalculationHistory(
      db,
      id: 'history-1',
      timingRecordId: 7,
      expression: '8+8',
      result: 16.0,
      ticketCount: 2,
    );
    await _seedAccountPayment(db, _paymentMap());
    await _seedProjectWriteOff(db, _writeOffMap(id: 'write-off-1'));
    await db.insert(
      'project_device_rates',
      _projectRateMap(includeProjectId: true),
    );
    await _seedMergeGroup(db);
    await _seedMergeMember(
      db,
      id: 11,
      projectKey: '甲方||一号工地',
      site: '一号工地',
      sortOrder: 0,
    );

    final export = await LocalBackupExportService.exportJsonBackup();
    expect(export.success, isTrue);
    final rawJson = await File(export.filePath!).readAsString();
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final meta = decoded['meta'] as Map<String, dynamic>;

    expect(meta['app_name'], 'FleetLedger');
    expect(export.fileName, startsWith('FleetLedger_手动备份_'));

    final result = await _restoreService().restoreFromDecodedJson(decoded);

    expect(result.success, isTrue);
    expect(result.restoredCounts['devices'], 1);
    expect(result.restoredCounts['timing_records'], 1);
    expect(result.restoredCounts['timing_calculation_history'], 1);
    expect(result.restoredCounts['account_payments'], 1);
    expect(result.restoredCounts['project_write_offs'], 1);
    expect(result.restoredCounts['project_device_rates'], 1);
    expect(result.restoredCounts['account_project_merge_groups'], 1);
    expect(result.restoredCounts['account_project_merge_members'], 1);
  });

  test(
    'restore accepts old v9 backups without calculation histories',
    () async {
      await _openCurrentInMemoryDb();

      final result = await _restoreService().restoreFromDecodedJson(
        _backupJson(schemaVersion: 9, includeCalculationHistoryTable: false),
      );

      expect(result.success, isTrue);
      expect(result.restoredCounts['timing_calculation_history'], 0);
      expect(result.restoredCounts['account_project_merge_groups'], 0);
      expect(result.restoredCounts['account_project_merge_members'], 0);
      expect(result.restoredCounts['project_write_offs'], 0);
      expect(
        await SqfliteTimingCalculationHistoryRepository().findByTimingRecordId(
          7,
        ),
        isEmpty,
      );
      expect(
        await (await AppDatabase.database).query(
          'account_project_merge_groups',
        ),
        isEmpty,
      );
      expect(
        await (await AppDatabase.database).query(
          'account_project_merge_members',
        ),
        isEmpty,
      );
      expect(
        await (await AppDatabase.database).query('project_write_offs'),
        isEmpty,
      );
    },
  );

  test('restore rolls back orphan merge members', () async {
    final db = await _openCurrentInMemoryDb();

    final result = await _restoreService().restoreFromDecodedJson(
      _backupJson(
        schemaVersion: AppDatabase.schemaVersion,
        mergeGroups: [],
        mergeMembers: [
          _mergeMemberMap(
            id: 11,
            groupId: 999,
            projectKey: '甲方||一号工地',
            site: '一号工地',
          ),
        ],
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'transaction_failed');
    expect(await db.query('account_project_merge_groups'), isEmpty);
    expect(await db.query('account_project_merge_members'), isEmpty);
  });

  test('restore rolls back orphan calculation histories', () async {
    final db = await _openCurrentInMemoryDb();

    final result = await _restoreService().restoreFromDecodedJson(
      _backupJson(
        calculationHistories: [
          _historyMap(id: 'orphan-history', timingRecordId: 999),
        ],
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'transaction_failed');
    expect(await db.query('timing_records'), isEmpty);
    expect(await db.query('timing_calculation_history'), isEmpty);
  });
}

Future<Database> _openCurrentInMemoryDb() {
  AppDatabase.debugInitDbOverride = () {
    return openDatabase(
      inMemoryDatabasePath,
      version: AppDatabase.schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, _) => DbSchema.create(db),
    );
  };
  return AppDatabase.database;
}

LocalBackupRestoreService _restoreService() {
  return LocalBackupRestoreService(
    exportBackup: () async {
      return LocalBackupExportResult(
        success: true,
        filePath: p.join('/tmp', 'pre_restore.json'),
        fileName: 'pre_restore.json',
      );
    },
  );
}

Map<String, dynamic> _backupJson({
  int exportFormatVersion = 1,
  int schemaVersion = 10,
  bool includeCalculationHistoryTable = true,
  List<Map<String, Object?>>? projects,
  List<Map<String, Object?>>? devices,
  List<Map<String, Object?>> fuelLogs = const [],
  List<Map<String, Object?>> maintenanceRecords = const [],
  List<Map<String, Object?>>? timingRecords,
  List<Map<String, Object?>> calculationHistories = const [],
  List<Map<String, Object?>> accountPayments = const [],
  List<Map<String, Object?>>? projectWriteOffs,
  List<Map<String, Object?>> projectDeviceRates = const [],
  List<Map<String, Object?>>? mergeGroups,
  List<Map<String, Object?>>? mergeMembers,
  String appName = 'FleetLedger',
}) {
  final data = <String, Object?>{
    ...projects == null ? const {} : {'projects': projects},
    'devices': devices ?? [_deviceMap(id: 1)],
    'timing_records': timingRecords ?? [_timingRecordMap(id: 7, deviceId: 1)],
    'fuel_logs': fuelLogs,
    'maintenance_records': maintenanceRecords,
    'account_payments': accountPayments,
    ...projectWriteOffs == null
        ? const {}
        : {'project_write_offs': projectWriteOffs},
    'project_device_rates': projectDeviceRates,
  };

  if (includeCalculationHistoryTable) {
    data['timing_calculation_history'] = calculationHistories;
  }
  if (mergeGroups != null) {
    data['account_project_merge_groups'] = mergeGroups;
  }
  if (mergeMembers != null) {
    data['account_project_merge_members'] = mergeMembers;
  }

  return <String, dynamic>{
    'meta': <String, Object?>{
      'export_format_version': exportFormatVersion,
      'schema_version': schemaVersion,
      'exported_at': '2026-05-14T15:32:00.000Z',
      'app_version': 'test',
      'app_name': appName,
    },
    'summary': <String, Object?>{
      'table_counts': <String, int>{
        if (projects != null) 'projects': projects.length,
        'devices': 1,
        'timing_records': 1,
        'fuel_logs': fuelLogs.length,
        'maintenance_records': maintenanceRecords.length,
        'account_payments': accountPayments.length,
        if (projectWriteOffs != null)
          'project_write_offs': projectWriteOffs.length,
        'project_device_rates': projectDeviceRates.length,
        if (includeCalculationHistoryTable)
          'timing_calculation_history': calculationHistories.length,
        if (mergeGroups != null)
          'account_project_merge_groups': mergeGroups.length,
        if (mergeMembers != null)
          'account_project_merge_members': mergeMembers.length,
      },
    },
    'data': data,
  };
}

Map<String, Object?> _projectMap({
  String projectKey = '甲方||一号工地',
  String createdAt = '2026-05-14T15:32:00.000Z',
}) {
  final parsed = ProjectKey.fromKey(projectKey);
  return {
    'id': _projectIdForKey(projectKey),
    'contact': parsed.contact,
    'site': parsed.site,
    'created_at': createdAt,
    'updated_at': createdAt,
    'legacy_project_key': projectKey,
  };
}

Map<String, Object?> _deviceMap({required int id}) {
  return {
    'id': id,
    'name': 'SANY $id#',
    'brand': 'SANY',
    'model': null,
    'default_unit_price_fen': 10000,
    'breaking_unit_price_fen': null,
    'base_meter_hours': 0.0,
    'is_active': 1,
    'custom_avatar_path': null,
    'equipment_type': 'excavator',
  };
}

Map<String, Object?> _fuelLogMap({
  required int id,
  int deviceId = 1,
  double cost = 120.0,
}) {
  return {
    'id': id,
    'device_id': deviceId,
    'date': 20260514,
    'supplier': '王五',
    'liters': 30.0,
    'cost': cost,
    'cost_fen': (cost * 100).round(),
  };
}

Map<String, Object?> _maintenanceMap({
  required int id,
  int? deviceId = 1,
  double amount = 120.0,
}) {
  return {
    'id': id,
    'device_id': deviceId,
    'ymd': 20260514,
    'item': '换机油',
    'amount': amount,
    'amount_fen': (amount * 100).round(),
    'note': '定期保养',
  };
}

Map<String, Object?> _timingRecordMap({
  required int id,
  required int deviceId,
  bool includeProjectId = false,
}) {
  return {
    'id': id,
    if (includeProjectId) 'project_id': _projectIdForKey('甲方||一号工地'),
    'device_id': deviceId,
    'start_date': 20260514,
    'contact': '甲方',
    'site': '一号工地',
    'type': 'hours',
    'start_meter': 0.0,
    'end_meter': 16.0,
    'hours': 16.0,
    'income_fen': 160000,
    'unit': 'HOUR',
    'exclude_from_fuel_eff': 0,
    'is_breaking': 0,
  };
}

Map<String, Object?> _projectRateMap({
  String projectKey = '甲方||一号工地',
  int deviceId = 1,
  int isBreaking = 0,
  double rate = 120.0,
  bool includeProjectId = false,
  bool includeLegacyRate = false,
}) {
  return {
    if (includeProjectId) 'project_id': _projectIdForKey(projectKey),
    'project_key': projectKey,
    'device_id': deviceId,
    'is_breaking': isBreaking,
    if (includeLegacyRate) 'rate': rate,
    'rate_fen': (rate * 100).round(),
  };
}

Map<String, Object?> _historyMap({
  required String id,
  int timingRecordId = 7,
  String createdAt = '2026-05-14T15:32:00.000Z',
  String expression = '8+8',
  double result = 16.0,
  int ticketCount = 2,
}) {
  return {
    'id': id,
    'timing_record_id': timingRecordId,
    'created_at': createdAt,
    'expression': expression,
    'result': result,
    'ticket_count': ticketCount,
  };
}

Map<String, Object?> _legacyPaymentMap({
  int id = 1,
  String projectKey = '甲方||一号工地',
  int ymd = 20260515,
  double amount = 500.0,
  String? note = '收款',
}) {
  return {
    'id': id,
    'project_key': projectKey,
    'ymd': ymd,
    'amount': amount,
    'note': note,
  };
}

Map<String, Object?> _paymentMap({
  int id = 1,
  String projectKey = '甲方||一号工地',
  int ymd = 20260515,
  double amount = 500.0,
  bool includeLegacyAmount = false,
  String? note = '收款',
  String sourceType = AccountPayment.sourceTypeManual,
  int? mergeGroupId,
  String? mergeBatchId,
  double? mergeBatchTotalAmount,
  bool includeLegacyMergeBatchTotalAmount = false,
  String? mergeBatchNote,
  String? createdAt,
  bool includeProjectId = false,
}) {
  return {
    'id': id,
    if (includeProjectId) 'project_id': _projectIdForKey(projectKey),
    'project_key': projectKey,
    'ymd': ymd,
    if (includeLegacyAmount) 'amount': amount,
    'amount_fen': (amount * 100).round(),
    'note': note,
    'source_type': sourceType,
    'merge_group_id': mergeGroupId,
    'merge_batch_id': mergeBatchId,
    if (includeLegacyMergeBatchTotalAmount)
      'merge_batch_total_amount': mergeBatchTotalAmount,
    'merge_batch_total_amount_fen': mergeBatchTotalAmount == null
        ? null
        : (mergeBatchTotalAmount * 100).round(),
    'merge_batch_note': mergeBatchNote,
    'created_at': createdAt,
  };
}

Map<String, Object?> _writeOffMap({
  String id = 'write-off-1',
  String projectKey = '甲方||一号工地',
  double amount = 60.0,
  bool includeLegacyAmount = false,
  String reason = 'rounding',
  String? note = '尾款不再追收',
  String writeOffDate = '2026-05-18',
  String createdAt = '2026-05-18T00:00:00.000Z',
  String updatedAt = '2026-05-18T00:00:00.000Z',
}) {
  return {
    'id': id,
    'project_id': _projectIdForKey(projectKey),
    if (includeLegacyAmount) 'amount': amount,
    'amount_fen': (amount * 100).round(),
    'reason': reason,
    'note': note,
    'write_off_date': writeOffDate,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

Map<String, Object?> _mergeGroupMap({
  int id = 1,
  String contact = '甲方',
  String createdAt = '2026-05-14T15:32:00.000Z',
  String? updatedAt = '2026-05-14T15:32:00.000Z',
  int isActive = 1,
  String? dissolvedAt,
  String sourceType = 'local',
}) {
  return {
    'id': id,
    'contact': contact,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'is_active': isActive,
    'dissolved_at': dissolvedAt,
    'source_type': sourceType,
  };
}

Map<String, Object?> _mergeMemberMap({
  required int id,
  int groupId = 1,
  required String projectKey,
  String contact = '甲方',
  required String site,
  int sortOrder = 0,
  String createdAt = '2026-05-14T15:32:00.000Z',
  int isActive = 1,
  bool includeProjectId = false,
}) {
  return {
    'id': id,
    'group_id': groupId,
    if (includeProjectId) 'project_id': _projectIdForKey(projectKey),
    'project_key': projectKey,
    'contact': contact,
    'site': site,
    'sort_order': sortOrder,
    'created_at': createdAt,
    'is_active': isActive,
  };
}

Future<void> _seedDevice(Database db, {required int id}) async {
  await db.insert('devices', _deviceMap(id: id));
}

Future<void> _seedTimingRecord(
  Database db, {
  required int id,
  required int deviceId,
}) async {
  await _seedProject(db, projectKey: '甲方||一号工地');
  await db.insert(
    'timing_records',
    _timingRecordMap(id: id, deviceId: deviceId, includeProjectId: true),
  );
}

Future<void> _seedCalculationHistory(
  Database db, {
  required String id,
  required int timingRecordId,
  required String expression,
  required double result,
  required int ticketCount,
}) async {
  await db.insert(
    'timing_calculation_history',
    _historyMap(
      id: id,
      timingRecordId: timingRecordId,
      expression: expression,
      result: result,
      ticketCount: ticketCount,
    ),
  );
}

Future<void> _seedAccountPayment(
  Database db,
  Map<String, Object?> payment,
) async {
  final projectKey = payment['project_key'] as String;
  await _seedProject(db, projectKey: projectKey);
  final legacyAmount = payment['amount'] as num?;
  final amountFen =
      (payment['amount_fen'] as num?)?.toInt() ??
      ((legacyAmount ?? 0) * 100).round();
  final legacyMergeTotal = payment['merge_batch_total_amount'] as num?;
  final mergeBatchTotalAmountFen =
      (payment['merge_batch_total_amount_fen'] as num?)?.toInt() ??
      (legacyMergeTotal == null ? null : (legacyMergeTotal * 100).round());
  final row = Map<String, Object?>.from(payment);
  row
    ..remove('amount')
    ..remove('merge_batch_total_amount');
  await db.insert('account_payments', {
    ...row,
    'amount_fen': amountFen,
    'merge_batch_total_amount_fen': mergeBatchTotalAmountFen,
    'project_id': payment['project_id'] ?? _projectIdForKey(projectKey),
  });
}

Future<void> _seedProjectWriteOff(
  Database db,
  Map<String, Object?> writeOff,
) async {
  final projectId = writeOff['project_id'] as String;
  await _seedProject(db, projectKey: '甲方||一号工地');
  final legacyAmount = writeOff['amount'] as num?;
  final amountFen =
      (writeOff['amount_fen'] as num?)?.toInt() ??
      ((legacyAmount ?? 0) * 100).round();
  final normalized = Map<String, Object?>.of(writeOff)..remove('amount');
  await db.insert('project_write_offs', {
    ...normalized,
    'amount_fen': amountFen,
    'project_id': projectId,
  });
}

Future<void> _seedMergeGroup(Database db) async {
  await db.insert('account_project_merge_groups', _mergeGroupMap());
}

Future<void> _seedMergeMember(
  Database db, {
  required int id,
  required String projectKey,
  required String site,
  required int sortOrder,
}) async {
  await _seedProject(db, projectKey: projectKey);
  await db.insert(
    'account_project_merge_members',
    _mergeMemberMap(
      id: id,
      projectKey: projectKey,
      site: site,
      sortOrder: sortOrder,
      includeProjectId: true,
    ),
  );
}

Future<void> _seedProject(Database db, {required String projectKey}) async {
  final parsed = ProjectKey.fromKey(projectKey);
  await db.insert('projects', {
    'id': _projectIdForKey(projectKey),
    'contact': parsed.contact,
    'site': parsed.site,
    'created_at': '2026-05-14T15:32:00.000Z',
    'updated_at': '2026-05-14T15:32:00.000Z',
    'legacy_project_key': projectKey,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
}

String _projectIdForKey(String projectKey) =>
    ProjectId.legacyFromKey(projectKey);
