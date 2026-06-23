import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/backup_preview.dart';
import 'package:asset_ledger/data/models/backup_restore_result.dart';
import 'package:asset_ledger/data/services/local_backup_export_service.dart';
import 'package:asset_ledger/data/services/local_backup_import_preview_service.dart';
import 'package:asset_ledger/data/services/local_backup_restore_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
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
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  group('schema/version validation', () {
    test(
      'missing_schema_version path returns missing_schema_version',
      () async {
        final backup = _validBackup();
        (backup['meta'] as Map<String, dynamic>).remove('schema_version');

        final result = await _restore(backup, permissivePreview: true);

        expect(result.success, isFalse);
        expect(result.errorCode, 'missing_schema_version');
        expect(result.message, '备份文件格式不完整：缺少数据库版本');
      },
    );

    test('schema_version_newer path returns schema_version_newer', () async {
      final backup = _validBackup(
        metaOverrides: <String, Object?>{
          'schema_version': AppDatabase.schemaVersion + 1,
        },
      );

      final result = await _restore(backup, permissivePreview: true);

      expect(result.success, isFalse);
      expect(result.errorCode, 'schema_version_newer');
      expect(result.message, '备份文件版本较新，请升级 App 后再试');
    });

    test(
      'missing_export_format_version path returns missing_export_format_version',
      () async {
        final backup = _validBackup();
        (backup['meta'] as Map<String, dynamic>).remove(
          'export_format_version',
        );

        final result = await _restore(backup, permissivePreview: true);

        expect(result.success, isFalse);
        expect(result.errorCode, 'missing_export_format_version');
        expect(result.message, '备份文件格式不完整：缺少备份版本');
      },
    );

    test(
      'unsupported_export_format_version path returns unsupported_export_format_version',
      () async {
        final backup = _validBackup(
          metaOverrides: const <String, Object?>{'export_format_version': 3},
        );

        final result = await _restore(backup);

        expect(result.success, isFalse);
        expect(result.errorCode, 'unsupported_export_format_version');
        expect(result.message, '当前版本暂不支持该备份格式');
      },
    );
  });

  test('valid rows for all backup tables restore successfully', () async {
    final result = await _restore(_validBackup());

    expect(result.success, isTrue, reason: result.message);
    expect(result.warnings, isEmpty);
    for (final tableName in _backupTables) {
      expect(
        result.restoredCounts[tableName],
        1,
        reason: '$tableName should be counted after restore',
      );
      expect(
        await _rowCount(tableName),
        1,
        reason: '$tableName should contain the restored row',
      );
    }
  });

  test(
    'invalid row validation returns the first table-specific error code',
    () async {
      for (final entry in _invalidRowCases()) {
        await AppDatabase.resetForTest();
        final result = await _restore(
          _validBackup(
            dataOverrides: <String, List<Map<String, dynamic>>>{
              entry.tableName: <Map<String, dynamic>>[entry.invalidRow],
            },
          ),
        );

        expect(result.success, isFalse, reason: entry.tableName);
        expect(result.errorCode, entry.errorCode, reason: entry.tableName);
        expect(result.message, '备份数据结构异常，无法恢复');
      }
    },
  );

  test('legacy REAL money columns are normalized before insert', () async {
    final result = await _restore(_legacyRealMoneyBackup());

    expect(result.success, isTrue, reason: result.message);

    final db = await AppDatabase.database;
    final devices = await db.query('devices');
    expect(devices.single.containsKey('default_unit_price'), isFalse);
    expect(devices.single.containsKey('breaking_unit_price'), isFalse);
    expect(devices.single['default_unit_price_fen'], 12345);
    expect(devices.single['breaking_unit_price_fen'], 6789);

    final timingRecords = await db.query('timing_records');
    expect(timingRecords.single.containsKey('income'), isFalse);
    expect(timingRecords.single['income_fen'], 33333);

    final fuelLogs = await db.query('fuel_logs');
    expect(fuelLogs.single.containsKey('cost'), isFalse);
    expect(fuelLogs.single['cost_fen'], 4567);

    final maintenanceRecords = await db.query('maintenance_records');
    expect(maintenanceRecords.single.containsKey('amount'), isFalse);
    expect(maintenanceRecords.single['amount_fen'], 8888);

    final accountPayments = await db.query('account_payments');
    expect(accountPayments.single.containsKey('amount'), isFalse);
    expect(
      accountPayments.single.containsKey('merge_batch_total_amount'),
      isFalse,
    );
    expect(accountPayments.single['amount_fen'], 10001);
    expect(accountPayments.single['merge_batch_total_amount_fen'], 25075);

    final writeOffs = await db.query('project_write_offs');
    expect(writeOffs.single.containsKey('amount'), isFalse);
    expect(writeOffs.single['amount_fen'], 7777);

    final rates = await db.query('project_device_rates');
    expect(rates.single.containsKey('rate'), isFalse);
    expect(rates.single['rate_fen'], 22222);
  });

  test(
    'external work missing project warnings aggregate ids in row order',
    () async {
      final first = _externalWorkRecordRow(
        id: 'external-work-1',
        linkedProjectId: 'project:missing-a',
      );
      final second = _externalWorkRecordRow(
        id: 'external-work-2',
        sourceRecordUuid: 'source-record-2',
        originFingerprint: 'fingerprint-2',
        linkedProjectId: 'project:missing-b',
      );
      final result = await _restore(
        _validBackup(
          dataOverrides: <String, List<Map<String, dynamic>>>{
            'external_work_records': <Map<String, dynamic>>[first, second],
          },
        ),
      );

      expect(result.success, isTrue, reason: result.message);
      expect(result.restoredCounts['external_work_records'], 2);
      expect(result.warnings, hasLength(1));

      final warning = result.warnings.single;
      expect(
        warning.code,
        BackupRestoreWarningCode.externalWorkLinkedProjectMissing,
      );
      expect(warning.message, '部分外协记录已恢复为未关联状态（关联项目不在备份中）');
      expect(warning.context['detached_count'], 2);
      expect(warning.context['external_work_record_ids'], <String>[
        'external-work-1',
        'external-work-2',
      ]);

      final db = await AppDatabase.database;
      final rows = await db.query('external_work_records', orderBy: 'id ASC');
      expect(rows.map((row) => row['linked_project_id']).toList(), <Object?>[
        null,
        null,
      ]);
    },
  );
}

const _projectId = 'project:s6a';
const _projectKey = '甲方||一号工地';
const _now = '2026-06-01T00:00:00.000Z';

const _backupTables = <String>[
  'devices',
  'projects',
  'timing_records',
  'fuel_logs',
  'maintenance_records',
  'account_payments',
  'project_write_offs',
  'project_device_rates',
  'timing_calculation_history',
  'account_project_merge_groups',
  'account_project_merge_members',
  'external_import_batches',
  'external_work_records',
];

Future<BackupRestoreResult> _restore(
  Map<String, dynamic> backup, {
  bool permissivePreview = false,
}) {
  final service = LocalBackupRestoreService(
    previewService: permissivePreview
        ? const _PermissivePreviewService()
        : const LocalBackupImportPreviewService(),
    exportBackup: () async => const LocalBackupExportResult(
      success: true,
      filePath: '/tmp/pre-restore-stub.json',
      fileName: 'pre-restore-stub.json',
    ),
  );
  return service.restoreFromDecodedJson(backup);
}

Future<int> _rowCount(String tableName) async {
  final db = await AppDatabase.database;
  final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $tableName');
  return (rows.single['c'] as num).toInt();
}

Map<String, dynamic> _validBackup({
  Map<String, Object?> metaOverrides = const <String, Object?>{},
  Map<String, List<Map<String, dynamic>>> dataOverrides =
      const <String, List<Map<String, dynamic>>>{},
}) {
  final meta = <String, dynamic>{
    'app_name': 'FleetLedger',
    'app_version': 'test',
    'export_format_version': 2,
    'schema_version': AppDatabase.schemaVersion,
    'exported_at': _now,
    ...metaOverrides,
  };
  final data = <String, List<Map<String, dynamic>>>{
    'devices': <Map<String, dynamic>>[_deviceRow()],
    'projects': <Map<String, dynamic>>[_projectRow()],
    'timing_records': <Map<String, dynamic>>[_timingRecordRow()],
    'fuel_logs': <Map<String, dynamic>>[_fuelLogRow()],
    'maintenance_records': <Map<String, dynamic>>[_maintenanceRecordRow()],
    'account_payments': <Map<String, dynamic>>[_accountPaymentRow()],
    'project_write_offs': <Map<String, dynamic>>[_projectWriteOffRow()],
    'project_device_rates': <Map<String, dynamic>>[_projectDeviceRateRow()],
    'timing_calculation_history': <Map<String, dynamic>>[
      _timingCalculationHistoryRow(),
    ],
    'account_project_merge_groups': <Map<String, dynamic>>[_mergeGroupRow()],
    'account_project_merge_members': <Map<String, dynamic>>[_mergeMemberRow()],
    'external_import_batches': <Map<String, dynamic>>[_externalBatchRow()],
    'external_work_records': <Map<String, dynamic>>[_externalWorkRecordRow()],
    ...dataOverrides,
  };
  return <String, dynamic>{'meta': meta, 'data': data};
}

Map<String, dynamic> _legacyRealMoneyBackup() {
  final device = _deviceRow()
    ..remove('default_unit_price_fen')
    ..remove('breaking_unit_price_fen')
    ..['default_unit_price'] = 123.45
    ..['breaking_unit_price'] = 67.89;
  final timing = _timingRecordRow()
    ..remove('income_fen')
    ..['income'] = 333.33;
  final fuel = _fuelLogRow()
    ..remove('cost_fen')
    ..['cost'] = 45.67;
  final maintenance = _maintenanceRecordRow()
    ..remove('amount_fen')
    ..['amount'] = 88.88;
  final payment =
      _accountPaymentRow(
          sourceType: 'merge_allocation',
          mergeGroupId: 1,
          mergeBatchId: 'merge-batch-1',
        )
        ..remove('amount_fen')
        ..remove('merge_batch_total_amount_fen')
        ..['amount'] = 100.01
        ..['merge_batch_total_amount'] = 250.75;
  final writeOff = _projectWriteOffRow()
    ..remove('amount_fen')
    ..['amount'] = 77.77;
  final rate = _projectDeviceRateRow()
    ..remove('rate_fen')
    ..['rate'] = 222.22;
  return _validBackup(
    dataOverrides: <String, List<Map<String, dynamic>>>{
      'devices': <Map<String, dynamic>>[device],
      'timing_records': <Map<String, dynamic>>[timing],
      'fuel_logs': <Map<String, dynamic>>[fuel],
      'maintenance_records': <Map<String, dynamic>>[maintenance],
      'account_payments': <Map<String, dynamic>>[payment],
      'project_write_offs': <Map<String, dynamic>>[writeOff],
      'project_device_rates': <Map<String, dynamic>>[rate],
    },
  );
}

List<_InvalidRowCase> _invalidRowCases() {
  return <_InvalidRowCase>[
    _InvalidRowCase(
      'devices',
      _deviceRow()..['default_unit_price_fen'] = '12000',
      'invalid_devices_default_unit_price_fen',
    ),
    _InvalidRowCase(
      'projects',
      _projectRow()..['id'] = '',
      'invalid_projects_id',
    ),
    _InvalidRowCase(
      'timing_records',
      _timingRecordRow()..['income_fen'] = -1,
      'invalid_timing_records_income_fen',
    ),
    _InvalidRowCase(
      'fuel_logs',
      _fuelLogRow()..['cost_fen'] = '65000',
      'invalid_fuel_logs_cost_fen',
    ),
    _InvalidRowCase(
      'maintenance_records',
      _maintenanceRecordRow()..['amount_fen'] = '12000',
      'invalid_maintenance_records_amount_fen',
    ),
    _InvalidRowCase(
      'account_payments',
      _accountPaymentRow()..['amount_fen'] = -1,
      'invalid_account_payments_amount_fen',
    ),
    _InvalidRowCase(
      'project_write_offs',
      _projectWriteOffRow()..['amount_fen'] = -1,
      'invalid_project_write_offs_amount_fen',
    ),
    _InvalidRowCase(
      'project_device_rates',
      _projectDeviceRateRow()..['rate_fen'] = '13000',
      'invalid_project_device_rates_rate_fen',
    ),
    _InvalidRowCase(
      'timing_calculation_history',
      _timingCalculationHistoryRow()..['ticket_count'] = '1',
      'invalid_timing_calculation_history_ticket_count',
    ),
    _InvalidRowCase(
      'account_project_merge_groups',
      _mergeGroupRow()..['source_type'] = 'cloud',
      'invalid_account_project_merge_groups_source_type',
    ),
    _InvalidRowCase(
      'account_project_merge_members',
      _mergeMemberRow()..['group_id'] = '1',
      'invalid_account_project_merge_members_group_id',
    ),
    _InvalidRowCase(
      'external_import_batches',
      _externalBatchRow()..['record_count'] = -1,
      'invalid_external_import_batches_record_count',
    ),
    _InvalidRowCase(
      'external_work_records',
      _externalWorkRecordRow()..['amount_fen'] = -1,
      'invalid_external_work_records_amount_fen',
    ),
  ];
}

Map<String, dynamic> _deviceRow() {
  return <String, dynamic>{
    'id': 1,
    'name': '一号机',
    'brand': 'CAT',
    'model': '320',
    'default_unit_price_fen': 12000,
    'breaking_unit_price_fen': 15000,
    'base_meter_hours': 0.0,
    'is_active': 1,
    'custom_avatar_path': null,
    'equipment_type': 'excavator',
    'lifecycle_initial_cost_fen': null,
    'lifecycle_estimated_residual_fen': null,
  };
}

Map<String, dynamic> _projectRow() {
  return <String, dynamic>{
    'id': _projectId,
    'contact': '甲方',
    'site': '一号工地',
    'status': 'active',
    'settled_at': null,
    'settled_snapshot': null,
    'created_at': _now,
    'updated_at': _now,
    'legacy_project_key': _projectKey,
  };
}

Map<String, dynamic> _timingRecordRow() {
  return <String, dynamic>{
    'id': 1,
    'project_id': _projectId,
    'device_id': 1,
    'start_date': 20260601,
    'allocation_cutoff_date': null,
    'display_end_date': null,
    'contact': '甲方',
    'site': '一号工地',
    'type': 'hours',
    'start_meter': 1.0,
    'end_meter': 3.5,
    'hours': 2.5,
    'income_fen': 30000,
    'unit': 'HOUR',
    'quantity_scaled': 2500,
    'exclude_from_fuel_eff': 0,
    'is_breaking': 0,
  };
}

Map<String, dynamic> _fuelLogRow() {
  return <String, dynamic>{
    'id': 1,
    'device_id': 1,
    'date': 20260601,
    'supplier': '油站',
    'liters': 10.5,
    'cost_fen': 65000,
  };
}

Map<String, dynamic> _maintenanceRecordRow() {
  return <String, dynamic>{
    'id': 1,
    'device_id': 1,
    'ymd': 20260601,
    'item': '保养',
    'amount_fen': 12000,
    'note': null,
  };
}

Map<String, dynamic> _accountPaymentRow({
  String sourceType = 'manual',
  int? mergeGroupId,
  String? mergeBatchId,
}) {
  return <String, dynamic>{
    'id': 1,
    'project_id': _projectId,
    'project_key': _projectKey,
    'ymd': 20260601,
    'amount_fen': 10000,
    'note': null,
    'source_type': sourceType,
    'merge_group_id': mergeGroupId,
    'merge_batch_id': mergeBatchId,
    'merge_batch_total_amount_fen': null,
    'merge_batch_note': null,
    'created_at': _now,
  };
}

Map<String, dynamic> _projectWriteOffRow() {
  return <String, dynamic>{
    'id': 'write-off-1',
    'project_id': _projectId,
    'amount_fen': 5000,
    'reason': 'settlement',
    'note': null,
    'write_off_date': '2026-06-01',
    'created_at': _now,
    'updated_at': _now,
  };
}

Map<String, dynamic> _projectDeviceRateRow() {
  return <String, dynamic>{
    'project_id': _projectId,
    'project_key': _projectKey,
    'device_id': 1,
    'is_breaking': 0,
    'rate_fen': 13000,
  };
}

Map<String, dynamic> _timingCalculationHistoryRow() {
  return <String, dynamic>{
    'id': 'calculation-1',
    'timing_record_id': 1,
    'created_at': _now,
    'expression': '1 + 2',
    'result': 3.0,
    'ticket_count': 1,
  };
}

Map<String, dynamic> _mergeGroupRow() {
  return <String, dynamic>{
    'id': 1,
    'contact': '甲方',
    'created_at': _now,
    'updated_at': _now,
    'is_active': 1,
    'dissolved_at': null,
    'source_type': 'local',
  };
}

Map<String, dynamic> _mergeMemberRow() {
  return <String, dynamic>{
    'id': 1,
    'group_id': 1,
    'project_id': _projectId,
    'project_key': _projectKey,
    'contact': '甲方',
    'site': '一号工地',
    'sort_order': 0,
    'created_at': _now,
    'is_active': 1,
  };
}

Map<String, dynamic> _externalBatchRow() {
  return <String, dynamic>{
    'id': 'external-batch-1',
    'source_share_id': 'source-share-1',
    'source_display_name': '外协包',
    'record_count': 1,
    'total_hours_milli': 1000,
    'total_amount_fen': 20000,
    'site_summary': '一号工地',
    'imported_at': _now,
    'status': 'active',
    'created_at': _now,
    'updated_at': _now,
  };
}

Map<String, dynamic> _externalWorkRecordRow({
  String id = 'external-work-1',
  String sourceRecordUuid = 'source-record-1',
  String originFingerprint = 'fingerprint-1',
  String? linkedProjectId = _projectId,
}) {
  return <String, dynamic>{
    'id': id,
    'import_batch_id': 'external-batch-1',
    'source_share_id': 'source-share-1',
    'source_record_uuid': sourceRecordUuid,
    'source_installation_uuid': 'source-installation-1',
    'origin_fingerprint': originFingerprint,
    'collaborator_name': '外协',
    'contact_snapshot': '甲方',
    'site_snapshot': '一号工地',
    'equipment_brand': 'CAT',
    'equipment_model': '320',
    'equipment_type': 'excavator',
    'work_date': 20260601,
    'hours_milli': 1000,
    'source_unit_price_fen': 20000,
    'local_unit_price_fen': 20000,
    'customer_unit_price_fen': 22000,
    'amount_fen': 20000,
    'project_received_fen': 0,
    'linked_project_id': linkedProjectId,
    'record_kind': 'hours',
    'status': 'active',
    'note': null,
    'created_at': _now,
    'updated_at': _now,
  };
}

class _InvalidRowCase {
  const _InvalidRowCase(this.tableName, this.invalidRow, this.errorCode);

  final String tableName;
  final Map<String, dynamic> invalidRow;
  final String errorCode;
}

class _PermissivePreviewService extends LocalBackupImportPreviewService {
  const _PermissivePreviewService();

  @override
  BackupPreview previewFromDecodedJson(Map<String, dynamic> json) {
    return BackupPreview.valid(
      appName: 'FleetLedger',
      appVersion: 'test',
      backupVersion: '2',
      schemaVersion: AppDatabase.schemaVersion,
      tableCounts: const <String, int>{},
    );
  }
}
