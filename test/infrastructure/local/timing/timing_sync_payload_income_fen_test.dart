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
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

/// R5.26-B3：timing_record sync payload 携带 income_fen。
///
/// 因 TimingRecord.toMap 双写 income_fen，新入队 timing_record 的 payload.record
/// 会包含 income_fen == round(income*100)。顶层 payload_schema_version 仍为 1
/// （本轮不 bump：R6 真实云未接、income_fen 是 record 内 additive 字段、旧 outbox
/// 不回填、新 payloadHash 变化属预期）；income_fen 在 record 内，不在顶层，actor /
/// payload_schema_version 不进 record。
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
    'timing_record outbox payload.record carries income_fen == round(income*100) '
    'while top-level schema version stays 1',
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
      final providers = TimingSaveProviders.build(
        projectResolver: ProjectResolver(
          projectRepository: SqfliteProjectRepository(),
        ),
        actorContext: ActorContext(
          actorType: OperationActorType.owner,
          actorId: 'owner-b3',
        ),
      );

      await providers.saveUseCase.executeWithToken(
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

      final outboxRows = await db.query('sync_outbox');
      expect(outboxRows, hasLength(1));
      final payload =
          jsonDecode(outboxRows.single['payload_json'] as String)
              as Map<String, Object?>;

      // 顶层 schema version 仍为 1（本轮不 bump）。
      expect(payload['payload_schema_version'], 1);

      final record = payload['record'] as Map<String, Object?>;
      // Track A / A4-7：record 只携带 income_fen。
      expect(record.containsKey('income'), isFalse);
      expect(record['income_fen'], 20000);
      // 顶层字段不渗入 record。
      expect(record.containsKey('payload_schema_version'), isFalse);
      expect(record.containsKey('actor'), isFalse);

      // entity_sync_meta.payload_hash 与 outbox 行一致（payloadHash 含新字段）。
      final metaRows = await db.query('entity_sync_meta');
      expect(metaRows, hasLength(1));
      expect(
        metaRows.single['payload_hash'],
        outboxRows.single['payload_hash'],
      );
    },
  );
}
