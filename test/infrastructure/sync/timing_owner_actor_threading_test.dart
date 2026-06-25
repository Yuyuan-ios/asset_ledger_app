import 'dart:convert';

import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/data/repositories/account_project_merge_repository.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/external_work_record_repository.dart';
import 'package:asset_ledger/data/repositories/fuel_repository.dart';
import 'package:asset_ledger/data/repositories/maintenance_repository.dart';
import 'package:asset_ledger/data/repositories/project_rate_repository.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/repositories/project_write_off_repository.dart';
import 'package:asset_ledger/data/repositories/timing_calculation_history_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/data/services/project_resolver.dart';
import 'package:asset_ledger/infrastructure/local/account/project_settlement_impact_service.dart';
import 'package:asset_ledger/infrastructure/local/timing/local_delete_timing_record_with_impact_use_case.dart';
import 'package:asset_ledger/infrastructure/local/timing/local_save_timing_record_with_impact_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

/// R5.25-Hardening: timing_record save / delete inline payloads must carry
/// the persisted owner actor when the composition root threads a
/// SyncActorProvider. Both payload.actor.id and entity_sync_meta.updated_by
/// must come from the same actor; record stays untouched.
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

  ActorContext fixedOwner({String id = 'owner-XYZ', String? sessionId}) =>
      ActorContext(
        actorType: OperationActorType.owner,
        actorId: id,
        sessionId: sessionId,
      );

  LocalSaveTimingRecordWithImpactUseCase buildSaveUseCase({
    ActorContext Function()? actorProvider,
  }) {
    final projectRepository = SqfliteProjectRepository();
    return LocalSaveTimingRecordWithImpactUseCase(
      timingRepository: SqfliteTimingRepository(),
      timingCalculationHistoryRepository:
          SqfliteTimingCalculationHistoryRepository(),
      mergeRepository: SqfliteAccountProjectMergeRepository(),
      deviceRepository: SqfliteDeviceRepository(),
      projectRateRepository: SqfliteProjectRateRepository(),
      projectResolver: ProjectResolver(projectRepository: projectRepository),
      impactService: ProjectSettlementImpactService(
        projectRepository: projectRepository,
      ),
      actorProvider: actorProvider,
      now: () => DateTime.utc(2026, 5, 26, 12),
    );
  }

  LocalDeleteTimingRecordWithImpactUseCase buildDeleteUseCase({
    ActorContext Function()? actorProvider,
  }) {
    return LocalDeleteTimingRecordWithImpactUseCase(
      timingRepository: SqfliteTimingRepository(),
      paymentRepository: SqfliteAccountPaymentRepository(),
      mergeRepository: SqfliteAccountProjectMergeRepository(),
      deviceRepository: SqfliteDeviceRepository(),
      externalWorkRecordRepository: SqfliteExternalWorkRecordRepository(),
      fuelRepository: SqfliteFuelRepository(),
      maintenanceRepository: SqfliteMaintenanceRepository(),
      writeOffRepository: SqfliteProjectWriteOffRepository(),
      projectRepository: SqfliteProjectRepository(),
      actorProvider: actorProvider,
      now: () => DateTime.utc(2026, 5, 26, 12),
    );
  }

  Future<int> seedDevice(Database db) async {
    return db.insert(
      'devices',
      Device(
        name: 'Device',
        brand: 'brand',
        defaultUnitPrice: 100,
        baseMeterHours: 0,
      ).toMap(),
    );
  }

  Future<void> seedProject(Database db, String projectId) async {
    await db.insert(
      'projects',
      Project(
        id: projectId,
        contact: '甲方',
        site: projectId.split(':').last,
        status: ProjectStatus.active,
        legacyProjectKey: '甲方||${projectId.split(':').last}',
        createdAt: '2026-05-18T00:00:00.000Z',
        updatedAt: '2026-05-18T00:00:00.000Z',
      ).toMap(),
    );
  }

  Future<void> seedProjectRate(
    Database db, {
    required String projectId,
    required int deviceId,
  }) async {
    final site = projectId.split(':').last;
    await db.insert(
      'project_device_rates',
      ProjectDeviceRate(
        projectId: projectId,
        projectKey: '甲方||$site',
        deviceId: deviceId,
        rate: 100,
      ).toMap(),
    );
  }

  test(
    'SaveTimingRecord inline payload + meta both carry the threaded owner id',
    () async {
      final db = await AppDatabase.database;
      final deviceId = await seedDevice(db);
      await seedProject(db, 'project:alpha');
      await seedProjectRate(db, projectId: 'project:alpha', deviceId: deviceId);

      final useCase = buildSaveUseCase(actorProvider: () => fixedOwner());

      final result = await useCase.execute(
        editing: null,
        record: TimingRecord(
          deviceId: deviceId,
          startDate: 20260520,
          projectId: 'project:alpha',
          contact: '甲方',
          site: 'alpha',
          type: TimingType.hours,
          startMeter: 0,
          endMeter: 1,
          hours: 1,
          income: 100,
        ),
      );
      final recordId = result.savedRecord.id!;

      final outbox = await db.query('sync_outbox');
      expect(outbox, hasLength(1));
      final payload =
          (jsonDecode(outbox.single['payload_json'] as String) as Map)
              .cast<String, Object?>();
      expect(payload['operation'], 'create');
      final actor = payload['actor'] as Map<String, Object?>;
      expect(actor['type'], 'owner');
      expect(actor['id'], 'owner-XYZ');
      expect(actor.containsKey('session_id'), isTrue);

      // record stays a plain business snapshot; no actor/version leakage.
      final record = payload['record'] as Map<String, Object?>;
      expect(record.containsKey('actor'), isFalse);
      expect(record.containsKey('payload_schema_version'), isFalse);

      final meta = await db.query(
        'entity_sync_meta',
        where: 'entity_type = ? AND local_id = ?',
        whereArgs: ['timing_record', recordId.toString()],
      );
      expect(meta.single['updated_by'], 'owner-XYZ');
    },
  );

  test(
    'SaveTimingRecord without provider falls back to legacy null actor id',
    () async {
      final db = await AppDatabase.database;
      final deviceId = await seedDevice(db);
      await seedProject(db, 'project:alpha');
      await seedProjectRate(db, projectId: 'project:alpha', deviceId: deviceId);

      final useCase = buildSaveUseCase();

      await useCase.execute(
        editing: null,
        record: TimingRecord(
          deviceId: deviceId,
          startDate: 20260520,
          projectId: 'project:alpha',
          contact: '甲方',
          site: 'alpha',
          type: TimingType.hours,
          startMeter: 0,
          endMeter: 1,
          hours: 1,
          income: 100,
        ),
      );

      final payload =
          (jsonDecode(
                    (await db.query('sync_outbox')).single['payload_json']
                        as String,
                  )
                  as Map)
              .cast<String, Object?>();
      final actor = payload['actor'] as Map<String, Object?>;
      expect(actor['type'], 'owner');
      expect(
        actor['id'],
        isNull,
        reason: 'Legacy/test fallback (no provider) must surface null id.',
      );
    },
  );

  test(
    'DeleteTimingRecord inline payload + meta both carry the threaded owner id',
    () async {
      final db = await AppDatabase.database;
      final deviceId = await seedDevice(db);
      await seedProject(db, 'project:alpha');

      // Seed a single record so the delete path can resolve it inside the
      // transaction.
      final recordId = await db.insert(
        'timing_records',
        TimingRecord(
          deviceId: deviceId,
          startDate: 20260520,
          projectId: 'project:alpha',
          contact: '甲方',
          site: 'alpha',
          type: TimingType.hours,
          startMeter: 0,
          endMeter: 1,
          hours: 1,
          income: 100,
        ).toMap(),
      );

      final useCase = buildDeleteUseCase(
        actorProvider: () => fixedOwner(id: 'owner-DEL', sessionId: 'sess-d'),
      );

      await useCase.executeDeleteWithImpact(recordId);

      final outbox = await db.query('sync_outbox', orderBy: 'id ASC');
      // The delete path enqueues exactly the timing_record delete here (no
      // payments / writeoffs / external work to cascade).
      expect(outbox, hasLength(1));
      final payload =
          (jsonDecode(outbox.single['payload_json'] as String) as Map)
              .cast<String, Object?>();
      expect(payload['operation'], 'delete');
      final actor = payload['actor'] as Map<String, Object?>;
      expect(actor['type'], 'owner');
      expect(actor['id'], 'owner-DEL');
      expect(actor['session_id'], 'sess-d');

      final meta = await db.query(
        'entity_sync_meta',
        where: 'entity_type = ? AND local_id = ?',
        whereArgs: ['timing_record', recordId.toString()],
      );
      expect(meta.single['updated_by'], 'owner-DEL');
    },
  );
}
