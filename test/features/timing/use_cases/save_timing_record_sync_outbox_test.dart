import 'dart:convert';

import 'package:asset_ledger/app/providers/timing_save_providers.dart';
import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/services/project_resolver.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
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
    'executeWithToken 成功确认后写入 audit.token_id、sync_outbox 和 entity_sync_meta',
    () async {
      final db = await AppDatabase.database;
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
      await _seedAlphaProjectRate(db, deviceId);
      final actorContext = ActorContext(
        actorType: OperationActorType.owner,
        actorId: 'owner-r5-token',
      );
      final providers = TimingSaveProviders.build(
        projectResolver: ProjectResolver(
          projectRepository: SqfliteProjectRepository(),
        ),
        actorContext: actorContext,
      );

      final result = await providers.saveUseCase.executeWithToken(
        editing: null,
        record: TimingRecord(
          deviceId: deviceId,
          startDate: 20260601,
          allocationCutoffDate: 20260610,
          projectId: 'project:alpha',
          contact: '甲方',
          site: 'alpha',
          type: TimingType.hours,
          startMeter: 0,
          endMeter: 2,
          hours: 2,
          income: 200,
        ),
      );

      final savedId = result.impact.savedRecord.id.toString();
      final auditRows = await db.query('operation_audit_logs');
      expect(auditRows, hasLength(1));
      expect(auditRows.single['token_id'], isNotNull);
      expect(auditRows.single['actor_id'], 'owner-r5-token');

      final outboxRows = await db.query('sync_outbox');
      expect(outboxRows, hasLength(1));
      expect(outboxRows.single['entity_type'], 'timing_record');
      expect(outboxRows.single['entity_id'], savedId);
      expect(outboxRows.single['operation'], 'create');
      expect(outboxRows.single['status'], SyncOutboxStatus.pending.name);
      final payload =
          jsonDecode(outboxRows.single['payload_json'] as String)
              as Map<String, Object?>;
      expect(payload['operation'], 'create');
      expect(
        (payload['record'] as Map<String, Object?>)['id'],
        result.impact.savedRecord.id,
      );
      expect(
        (payload['record'] as Map<String, Object?>)['allocation_cutoff_date'],
        20260610,
      );

      final metaRows = await db.query('entity_sync_meta');
      expect(metaRows, hasLength(1));
      expect(metaRows.single['entity_type'], 'timing_record');
      expect(metaRows.single['local_id'], savedId);
      expect(metaRows.single['sync_status'], SyncStatus.pendingUpload.name);
      expect(
        metaRows.single['payload_hash'],
        outboxRows.single['payload_hash'],
      );
    },
  );

  test(
    'create with null allocation cutoff keeps legacy outbox payload clean',
    () async {
      final db = await AppDatabase.database;
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
      await _seedAlphaProjectRate(db, deviceId);
      final providers = TimingSaveProviders.build(
        projectResolver: ProjectResolver(
          projectRepository: SqfliteProjectRepository(),
        ),
        actorContext: ActorContext(
          actorType: OperationActorType.owner,
          actorId: 'owner-r5-token',
        ),
      );

      final result = await providers.saveUseCase.executeWithToken(
        editing: null,
        record: TimingRecord(
          deviceId: deviceId,
          startDate: 20260601,
          projectId: 'project:alpha',
          contact: '甲方',
          site: 'alpha',
          type: TimingType.hours,
          startMeter: 0,
          endMeter: 2,
          hours: 2,
          income: 200,
        ),
      );

      final row = (await db.query(
        'timing_records',
        where: 'id = ?',
        whereArgs: [result.impact.savedRecord.id],
      )).single;
      expect(row['allocation_cutoff_date'], isNull);

      final outboxRows = await db.query('sync_outbox');
      expect(outboxRows, hasLength(1));
      final payload =
          jsonDecode(outboxRows.single['payload_json'] as String)
              as Map<String, Object?>;
      final recordPayload = payload['record'] as Map<String, Object?>;
      expect(recordPayload.containsKey('allocation_cutoff_date'), isFalse);
    },
  );

  test(
    'cutoff clear update writes null to DB and expresses null in outbox payload',
    () async {
      final db = await AppDatabase.database;
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
      await _seedAlphaProjectRate(db, deviceId);
      final existing = TimingRecord(
        deviceId: deviceId,
        startDate: 20260601,
        allocationCutoffDate: 20260610,
        projectId: 'project:alpha',
        contact: '甲方',
        site: 'alpha',
        type: TimingType.hours,
        startMeter: 0,
        endMeter: 2,
        hours: 2,
        income: 200,
      );
      final existingId = await db.insert('timing_records', existing.toMap());
      final editing = existing.copyWith(id: existingId);
      final providers = TimingSaveProviders.build(
        projectResolver: ProjectResolver(
          projectRepository: SqfliteProjectRepository(),
        ),
        actorContext: ActorContext(
          actorType: OperationActorType.owner,
          actorId: 'owner-r5-token',
        ),
      );

      final result = await providers.saveUseCase.executeWithToken(
        editing: editing,
        record: editing.copyWith(allocationCutoffDate: null),
      );

      expect(result.impact.savedRecord.allocationCutoffDate, isNull);
      final row = (await db.query(
        'timing_records',
        where: 'id = ?',
        whereArgs: [existingId],
      )).single;
      expect(row['allocation_cutoff_date'], isNull);

      final outboxRows = await db.query('sync_outbox');
      expect(outboxRows, hasLength(1));
      expect(outboxRows.single['operation'], 'update');
      final payload =
          jsonDecode(outboxRows.single['payload_json'] as String)
              as Map<String, Object?>;
      final recordPayload = payload['record'] as Map<String, Object?>;
      expect(recordPayload.containsKey('allocation_cutoff_date'), isTrue);
      expect(recordPayload['allocation_cutoff_date'], isNull);
    },
  );
}

Future<void> _seedAlphaProjectRate(Database db, int deviceId) async {
  await db.insert(
    'project_device_rates',
    ProjectDeviceRate(
      projectId: 'project:alpha',
      projectKey: '甲方||alpha',
      deviceId: deviceId,
      rate: 100,
    ).toMap(),
  );
}
