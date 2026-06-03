import 'dart:convert';

import 'package:asset_ledger/app/providers/timing_save_providers.dart';
import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project.dart';
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
        const Device(
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
}
