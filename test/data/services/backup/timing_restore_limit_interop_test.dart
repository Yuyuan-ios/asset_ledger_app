import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/account_project_merge_repository.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/project_rate_repository.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/repositories/timing_calculation_history_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/data/services/local_backup_export_service.dart';
import 'package:asset_ledger/data/services/local_backup_import_preview_service.dart';
import 'package:asset_ledger/data/services/local_backup_restore_service.dart';
import 'package:asset_ledger/data/services/project_resolver.dart';
import 'package:asset_ledger/features/timing/use_cases/save_timing_record_with_impact_use_case.dart';
import 'package:asset_ledger/infrastructure/local/account/project_settlement_impact_service.dart';
import 'package:asset_ledger/infrastructure/local/timing/local_save_timing_record_with_impact_use_case.dart';
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

  test(
    'local restore can import 30+ timing records but Free cannot add more',
    () async {
      final restoreService = LocalBackupRestoreService(
        previewService: const LocalBackupImportPreviewService(),
        exportBackup: () async => const LocalBackupExportResult(
          success: true,
          filePath: '/tmp/pre-restore-stub.json',
          fileName: 'pre-restore-stub.json',
        ),
      );

      final restore = await restoreService.restoreFromDecodedJson(
        _backupWithTimingRecords(31),
      );

      expect(restore.success, isTrue, reason: restore.message);
      final db = await AppDatabase.database;
      expect(await db.query('timing_records'), hasLength(31));

      final timingRepository = SqfliteTimingRepository();
      final projectRepository = SqfliteProjectRepository();
      final useCase = LocalSaveTimingRecordWithImpactUseCase(
        timingRepository: timingRepository,
        timingCalculationHistoryRepository:
            SqfliteTimingCalculationHistoryRepository(),
        mergeRepository: SqfliteAccountProjectMergeRepository(),
        deviceRepository: SqfliteDeviceRepository(),
        projectRateRepository: SqfliteProjectRateRepository(),
        projectRepository: projectRepository,
        projectResolver: ProjectResolver(projectRepository: projectRepository),
        impactService: ProjectSettlementImpactService(
          projectRepository: projectRepository,
        ),
        now: () => DateTime.utc(2026, 6, 26),
      );

      await expectLater(
        useCase.execute(
          editing: null,
          record: TimingRecord(
            deviceId: 7,
            startDate: 20260710,
            projectId: 'project:restore',
            contact: '甲方',
            site: '回灌工地',
            type: TimingType.hours,
            startMeter: 1000,
            endMeter: 1001,
            hours: 1,
            income: 100,
          ),
        ),
        throwsA(isA<TimingRecordLimitExceededException>()),
      );
      expect(await db.query('timing_records'), hasLength(31));
    },
  );
}

Map<String, dynamic> _backupWithTimingRecords(int count) {
  return <String, dynamic>{
    'meta': <String, dynamic>{
      'app_name': 'FleetLedger',
      'app_version': 'test',
      'export_format_version': 2,
      'schema_version': AppDatabase.schemaVersion,
      'exported_at': '2026-06-26T00:00:00.000Z',
    },
    'data': <String, dynamic>{
      'projects': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'project:restore',
          'contact': '甲方',
          'site': '回灌工地',
          'status': 'active',
          'created_at': '2026-06-26T00:00:00.000Z',
          'updated_at': '2026-06-26T00:00:00.000Z',
          'legacy_project_key': '甲方||回灌工地',
        },
      ],
      'devices': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 7,
          'name': 'SANY 7#',
          'brand': 'SANY',
          'model': null,
          'default_unit_price_fen': 10000,
          'breaking_unit_price_fen': null,
          'base_meter_hours': 0.0,
          'is_active': 1,
          'custom_avatar_path': null,
          'equipment_type': 'excavator',
          'lifecycle_initial_cost_fen': null,
          'lifecycle_estimated_residual_fen': null,
        },
      ],
      'timing_records': List.generate(
        count,
        (index) => <String, dynamic>{
          'id': index + 1,
          'project_id': 'project:restore',
          'device_id': 7,
          'start_date': 20260601 + index,
          'contact': '甲方',
          'site': '回灌工地',
          'type': 'hours',
          'start_meter': index.toDouble(),
          'end_meter': index + 1.0,
          'hours': 1.0,
          'income_fen': 10000,
          'unit': 'HOUR',
          'quantity_scaled': 1000,
          'exclude_from_fuel_eff': 0,
          'is_breaking': 0,
        },
      ),
      'fuel_logs': <Map<String, dynamic>>[],
      'maintenance_records': <Map<String, dynamic>>[],
      'account_payments': <Map<String, dynamic>>[],
      'project_write_offs': <Map<String, dynamic>>[],
      'project_device_rates': <Map<String, dynamic>>[],
      'timing_calculation_history': <Map<String, dynamic>>[],
      'account_project_merge_groups': <Map<String, dynamic>>[],
      'account_project_merge_members': <Map<String, dynamic>>[],
      'external_import_batches': <Map<String, dynamic>>[],
      'external_work_records': <Map<String, dynamic>>[],
    },
  };
}
