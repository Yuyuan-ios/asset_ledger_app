import 'dart:convert';
import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/services/local_backup_export_service.dart';
import 'package:asset_ledger/data/services/local_backup_restore_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory documentsDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp(
      'asset_ledger_display_end_backup_test_',
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
    if (await documentsDir.exists()) {
      await documentsDir.delete(recursive: true);
    }
  });

  test(
    'backup export includes display_end_date and restore preserves it',
    () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDeviceAndProject(db);
      await db.insert(
        'timing_records',
        _record(deviceId: deviceId, displayEndDate: 20260630).toMap(),
      );

      final export = await LocalBackupExportService.exportJsonBackup();
      expect(export.success, isTrue);
      final file = File(export.filePath!);
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      addTearDown(() async {
        if (await file.exists()) await file.delete();
      });

      final data = decoded['data'] as Map<String, dynamic>;
      final timings = data['timing_records'] as List<dynamic>;
      expect(timings.single, containsPair('display_end_date', 20260630));

      final result = await _restoreService().restoreFromDecodedJson(decoded);
      expect(result.success, isTrue);

      final restored = TimingRecord.fromMap(
        (await db.query('timing_records')).single,
      );
      expect(restored.displayEndDate, 20260630);
      expect(restored.allocationCutoffDate, isNull);
    },
  );

  test('restore legacy backup missing display_end_date keeps null', () async {
    final db = await AppDatabase.database;
    final result = await _restoreService().restoreFromDecodedJson(
      _backupJson(timingRecord: _recordMap()),
    );

    expect(result.success, isTrue);
    final restored = TimingRecord.fromMap(
      (await db.query('timing_records')).single,
    );
    expect(restored.displayEndDate, isNull);
  });

  test('restore rejects non-int allocation_cutoff_date', () async {
    final result = await _restoreService().restoreFromDecodedJson(
      _backupJson(
        timingRecord: {..._recordMap(), 'allocation_cutoff_date': 'not-an-int'},
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'invalid_timing_records_allocation_cutoff_date');
  });
}

LocalBackupRestoreService _restoreService() {
  return LocalBackupRestoreService(
    exportBackup: () async {
      return const LocalBackupExportResult(
        success: true,
        filePath: '/tmp/pre_restore.json',
        fileName: 'pre_restore.json',
      );
    },
  );
}

Future<int> _seedDeviceAndProject(Database db) async {
  final deviceId = await db.insert(
    'devices',
    Device(
      name: 'SANY 1#',
      brand: 'SANY',
      defaultUnitPrice: 100,
      baseMeterHours: 0,
    ).toMap(),
  );
  await db.insert(
    'projects',
    const Project(
      id: 'project:alpha',
      contact: '甲方',
      site: 'alpha',
      status: ProjectStatus.active,
      createdAt: '2026-06-01T00:00:00.000Z',
      updatedAt: '2026-06-01T00:00:00.000Z',
    ).toMap(),
  );
  return deviceId;
}

TimingRecord _record({required int deviceId, int? displayEndDate}) {
  return TimingRecord(
    deviceId: deviceId,
    startDate: 20260601,
    displayEndDate: displayEndDate,
    projectId: 'project:alpha',
    contact: '甲方',
    site: 'alpha',
    type: TimingType.rent,
    startMeter: 0,
    endMeter: 0,
    hours: 0,
    income: 1000,
  );
}

Map<String, dynamic> _backupJson({required Map<String, Object?> timingRecord}) {
  return {
    'meta': {
      'export_format_version': 2,
      'schema_version': AppDatabase.schemaVersion,
      'exported_at': '2026-06-01T00:00:00.000Z',
      'app_version': 'test',
      'app_name': 'FleetLedger',
    },
    'summary': {
      'table_counts': {
        'projects': 1,
        'devices': 1,
        'timing_records': 1,
        'fuel_logs': 0,
        'maintenance_records': 0,
        'account_payments': 0,
        'project_device_rates': 0,
      },
    },
    'data': {
      'projects': [
        {
          'id': 'project:alpha',
          'contact': '甲方',
          'site': 'alpha',
          'status': 'active',
          'created_at': '2026-06-01T00:00:00.000Z',
          'updated_at': '2026-06-01T00:00:00.000Z',
          'legacy_project_key': '甲方||alpha',
        },
      ],
      'devices': [
        Device(
          id: 1,
          name: 'SANY 1#',
          brand: 'SANY',
          defaultUnitPrice: 100,
          baseMeterHours: 0,
        ).toMap(),
      ],
      'timing_records': [timingRecord],
      'fuel_logs': [],
      'maintenance_records': [],
      'account_payments': [],
      'project_device_rates': [],
    },
  };
}

Map<String, Object?> _recordMap() {
  return {
    'id': 1,
    'project_id': 'project:alpha',
    'device_id': 1,
    'start_date': 20260601,
    'contact': '甲方',
    'site': 'alpha',
    'type': 'rent',
    'start_meter': 0.0,
    'end_meter': 0.0,
    'hours': 0.0,
    'income_fen': 100000,
    'exclude_from_fuel_eff': 0,
    'is_breaking': 0,
  };
}
