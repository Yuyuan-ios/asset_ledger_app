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
    'rent create payload carries display_end_date and schema version stays 1',
    () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDeviceAndProject(db);
      final providers = _providers();

      final result = await providers.saveUseCase.executeWithToken(
        editing: null,
        record: _record(
          deviceId: deviceId,
          type: TimingType.rent,
          displayEndDate: 20260630,
        ),
      );

      expect(result.impact.savedRecord.displayEndDate, 20260630);
      expect(result.impact.savedRecord.allocationCutoffDate, isNull);

      final recordPayload = await _singleOutboxRecordPayload(db);
      expect(recordPayload['payload_schema_version'], 1);
      final record = recordPayload['record'] as Map<String, Object?>;
      expect(record['display_end_date'], 20260630);
      expect(record.containsKey('allocation_cutoff_date'), isFalse);
    },
  );

  test(
    'rent update clear payload carries explicit display_end_date null',
    () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDeviceAndProject(db);
      final existing = _record(
        deviceId: deviceId,
        type: TimingType.rent,
        displayEndDate: 20260630,
      );
      final existingId = await db.insert('timing_records', existing.toMap());
      final editing = existing.copyWith(id: existingId);
      final providers = _providers();

      final result = await providers.saveUseCase.executeWithToken(
        editing: editing,
        record: editing.copyWith(displayEndDate: null),
      );

      expect(result.impact.savedRecord.displayEndDate, isNull);
      final row = (await db.query(
        'timing_records',
        where: 'id = ?',
        whereArgs: [existingId],
      )).single;
      expect(row['display_end_date'], isNull);

      final payload = await _singleOutboxRecordPayload(db);
      expect(payload['operation'], 'update');
      expect(payload['payload_schema_version'], 1);
      final record = payload['record'] as Map<String, Object?>;
      expect(record.containsKey('display_end_date'), isTrue);
      expect(record['display_end_date'], isNull);
    },
  );

  test(
    'hours payload keeps allocation cutoff and omits display_end_date',
    () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDeviceAndProject(db);
      final providers = _providers();

      final result = await providers.saveUseCase.executeWithToken(
        editing: null,
        record: _record(
          deviceId: deviceId,
          type: TimingType.hours,
          allocationCutoffDate: 20260610,
        ),
      );

      expect(result.impact.savedRecord.allocationCutoffDate, 20260610);
      expect(result.impact.savedRecord.displayEndDate, isNull);

      final payload = await _singleOutboxRecordPayload(db);
      expect(payload['payload_schema_version'], 1);
      final record = payload['record'] as Map<String, Object?>;
      expect(record['allocation_cutoff_date'], 20260610);
      expect(record.containsKey('display_end_date'), isFalse);
    },
  );
}

Future<int> _seedDeviceAndProject(Database db) async {
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
  return deviceId;
}

TimingSaveProviders _providers() {
  return TimingSaveProviders.build(
    projectResolver: ProjectResolver(
      projectRepository: SqfliteProjectRepository(),
    ),
    actorContext: ActorContext(
      actorType: OperationActorType.owner,
      actorId: 'owner-display-end',
    ),
  );
}

TimingRecord _record({
  required int deviceId,
  required TimingType type,
  int? allocationCutoffDate,
  int? displayEndDate,
}) {
  return TimingRecord(
    deviceId: deviceId,
    startDate: 20260601,
    allocationCutoffDate: allocationCutoffDate,
    displayEndDate: displayEndDate,
    projectId: 'project:alpha',
    contact: '甲方',
    site: 'alpha',
    type: type,
    startMeter: 0,
    endMeter: type == TimingType.hours ? 2 : 0,
    hours: type == TimingType.hours ? 2 : 0,
    income: type == TimingType.hours ? 200 : 1000,
  );
}

Future<Map<String, Object?>> _singleOutboxRecordPayload(Database db) async {
  final outboxRows = await db.query('sync_outbox');
  expect(outboxRows, hasLength(1));
  return jsonDecode(outboxRows.single['payload_json'] as String)
      as Map<String, Object?>;
}
