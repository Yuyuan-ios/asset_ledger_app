import 'dart:convert';
import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/services/local_backup_export_service.dart';
import 'package:asset_ledger/data/services/local_backup_import_preview_service.dart';
import 'package:asset_ledger/data/services/local_backup_restore_service.dart';
import 'package:asset_ledger/features/timing/calculator/repository/timing_calculation_history_repository.dart';
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
      'project_key': '甲方||一号工地',
      'ymd': 20260515,
      'amount': 500.0,
      'note': '收款',
      'source_type': AccountPayment.sourceTypeMergeAllocation,
      'merge_group_id': 3,
      'merge_batch_id': 'batch-1',
      'merge_batch_total_amount': 5000.0,
      'merge_batch_note': '微信收款',
      'created_at': '2026-05-16T01:02:03.000Z',
    });
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
      expect(payment['merge_batch_total_amount'], isNull);
      expect(payment['merge_batch_note'], isNull);
      expect(payment['created_at'], isNull);
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
    expect(payment['merge_batch_total_amount'], 5000.0);
    expect(payment['merge_batch_note'], '微信收款');
    expect(payment['created_at'], '2026-05-16T01:02:03.000Z');
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
    },
  );

  test('restore rolls back orphan merge members', () async {
    final db = await _openCurrentInMemoryDb();

    final result = await _restoreService().restoreFromDecodedJson(
      _backupJson(
        schemaVersion: AppDatabase.schemaVersion,
        mergeGroups: const [],
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
  int schemaVersion = 10,
  bool includeCalculationHistoryTable = true,
  List<Map<String, Object?>> calculationHistories = const [],
  List<Map<String, Object?>> accountPayments = const [],
  List<Map<String, Object?>>? mergeGroups,
  List<Map<String, Object?>>? mergeMembers,
}) {
  final data = <String, Object?>{
    'devices': [_deviceMap(id: 1)],
    'timing_records': [_timingRecordMap(id: 7, deviceId: 1)],
    'fuel_logs': const [],
    'maintenance_records': const [],
    'account_payments': accountPayments,
    'project_device_rates': const [],
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
      'export_format_version': 1,
      'schema_version': schemaVersion,
      'exported_at': '2026-05-14T15:32:00.000Z',
      'app_version': 'test',
      'app_name': '机账通',
    },
    'summary': <String, Object?>{
      'table_counts': <String, int>{
        'devices': 1,
        'timing_records': 1,
        'fuel_logs': 0,
        'maintenance_records': 0,
        'account_payments': accountPayments.length,
        'project_device_rates': 0,
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

Map<String, Object?> _deviceMap({required int id}) {
  return {
    'id': id,
    'name': 'SANY $id#',
    'brand': 'SANY',
    'model': null,
    'default_unit_price': 100.0,
    'breaking_unit_price': null,
    'base_meter_hours': 0.0,
    'is_active': 1,
    'custom_avatar_path': null,
    'equipment_type': 'excavator',
  };
}

Map<String, Object?> _timingRecordMap({
  required int id,
  required int deviceId,
}) {
  return {
    'id': id,
    'device_id': deviceId,
    'start_date': 20260514,
    'contact': '甲方',
    'site': '一号工地',
    'type': 'hours',
    'start_meter': 0.0,
    'end_meter': 16.0,
    'hours': 16.0,
    'income': 1600.0,
    'exclude_from_fuel_eff': 0,
    'is_breaking': 0,
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
  String? note = '收款',
  String sourceType = AccountPayment.sourceTypeManual,
  int? mergeGroupId,
  String? mergeBatchId,
  double? mergeBatchTotalAmount,
  String? mergeBatchNote,
  String? createdAt,
}) {
  return {
    'id': id,
    'project_key': projectKey,
    'ymd': ymd,
    'amount': amount,
    'note': note,
    'source_type': sourceType,
    'merge_group_id': mergeGroupId,
    'merge_batch_id': mergeBatchId,
    'merge_batch_total_amount': mergeBatchTotalAmount,
    'merge_batch_note': mergeBatchNote,
    'created_at': createdAt,
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
}) {
  return {
    'id': id,
    'group_id': groupId,
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
  await db.insert(
    'timing_records',
    _timingRecordMap(id: id, deviceId: deviceId),
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
  await db.insert('account_payments', payment);
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
  await db.insert(
    'account_project_merge_members',
    _mergeMemberMap(
      id: id,
      projectKey: projectKey,
      site: site,
      sortOrder: sortOrder,
    ),
  );
}
