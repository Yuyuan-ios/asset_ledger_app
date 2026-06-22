import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/sync/sync_conflict_review_controller.dart';
import 'package:asset_ledger/infrastructure/sync/local_timing_conflict_summary_reader.dart';
import 'package:asset_ledger/infrastructure/sync/remote_change_applier.dart';
import 'package:asset_ledger/infrastructure/sync/sync_conflict_repository.dart';
import 'package:asset_ledger/infrastructure/sync/sync_conflict_resolution_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

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

  group('LocalTimingConflictSummaryReader', () {
    const reader = LocalTimingConflictSummaryReader();

    test(
      'returns null for non-timing conflicts and missing local rows',
      () async {
        expect(
          await reader.localSummary(_conflict(entityType: 'project')),
          isNull,
        );
        expect(await reader.localSummary(_conflict(entityId: '404')), isNull);
      },
    );

    test(
      'reads local timing row fields without deriving display labels',
      () async {
        final db = await AppDatabase.database;
        await _seedTimingRecord(
          db,
          id: 101,
          deviceId: 7,
          startDate: 20260602,
          hours: 1.5,
          incomeFen: 12345,
        );

        final summary = await reader.localSummary(_conflict(entityId: '101'));

        expect(summary, isNotNull);
        expect(summary!.deviceId, 7);
        expect(summary.startDate, 20260602);
        expect(summary.hours, 1.5);
        expect(summary.incomeFen, 12345);
        expect(summary.deleted, isFalse);
        expect(summary.dateLabel, '2026-06-02');
        expect(summary.hoursLabel, '1.5');
        expect(summary.amountLabel, '123.45');
      },
    );

    test('invalid local entity id is treated as a missing row', () async {
      final db = await AppDatabase.database;
      await _seedTimingRecord(db, id: 101);

      expect(
        await reader.localSummary(_conflict(entityId: 'not-an-int')),
        isNull,
      );
    });

    test('remoteSummary unwraps record payload and accepts numeric ints', () {
      final summary = reader.remoteSummary(
        _conflict(
          remotePayloadJson:
              '{"record":{"device_id":8,"start_date":20260603,'
              '"hours":2,"income_fen":30000}}',
        ),
      );

      expect(summary.deviceId, 8);
      expect(summary.startDate, 20260603);
      expect(summary.hours, 2.0);
      expect(summary.incomeFen, 30000);
      expect(summary.deleted, isFalse);
    });

    test('remoteSummary accepts flat payload shape', () {
      final summary = reader.remoteSummary(
        _conflict(
          remotePayloadJson:
              '{"device_id":9,"start_date":20260604,'
              '"hours":2.25,"income_fen":45678}',
        ),
      );

      expect(summary.deviceId, 9);
      expect(summary.startDate, 20260604);
      expect(summary.hours, 2.25);
      expect(summary.incomeFen, 45678);
    });

    test('remote deletion returns deleted placeholder summary', () {
      final summary = reader.remoteSummary(
        _conflict(remoteDeleted: true, remotePayloadJson: 'not-json'),
      );

      expect(summary.deviceId, 0);
      expect(summary.startDate, 0);
      expect(summary.hours, 0);
      expect(summary.incomeFen, 0);
      expect(summary.deleted, isTrue);
    });

    test('remoteSummary throws for malformed payloads and missing fields', () {
      expect(
        () => reader.remoteSummary(_conflict(remotePayloadJson: '[]')),
        throwsFormatException,
      );
      expect(
        () => reader.remoteSummary(
          _conflict(remotePayloadJson: '{"device_id":1,"hours":1}'),
        ),
        throwsFormatException,
      );
      expect(
        () => reader.remoteSummary(
          _conflict(
            remotePayloadJson:
                '{"device_id":1,"start_date":20260601,'
                '"hours":"1","income_fen":10000}',
          ),
        ),
        throwsFormatException,
      );
    });
  });

  test(
    'controller preserves pending conflict order while enriching summaries',
    () async {
      final db = await AppDatabase.database;
      await _seedTimingRecord(db, id: 101, deviceId: 1, startDate: 20260601);
      await _seedTimingRecord(db, id: 102, deviceId: 2, startDate: 20260602);

      final controller = SyncConflictReviewController(
        conflictRepository: _FakeConflictRepository([
          _conflict(entityId: '102', remoteServerSeq: 20),
          _conflict(entityId: '101', remoteServerSeq: 10),
          _conflict(entityType: 'project', entityId: 'p1', remoteServerSeq: 5),
        ]),
        summaryReader: const LocalTimingConflictSummaryReader(),
        conflictResolver: _NoopResolver(),
      );

      await controller.load();

      expect(controller.error, isNull);
      expect(controller.items.map((item) => item.conflict.entityId), [
        '102',
        '101',
      ]);
      expect(controller.items.map((item) => item.local?.deviceId), [2, 1]);
    },
  );
}

SyncConflict _conflict({
  String entityType = TimingRecordRemoteChangeApplier.entityType,
  String entityId = '101',
  int remoteServerSeq = 7,
  String remotePayloadJson =
      '{"record":{"device_id":1,"start_date":20260601,'
      '"hours":1,"income_fen":10000}}',
  bool remoteDeleted = false,
}) {
  return SyncConflict(
    id: '$entityType:$entityId:$remoteServerSeq',
    entityType: entityType,
    entityId: entityId,
    remoteServerSeq: remoteServerSeq,
    remoteBaseVersion: 1,
    remoteNewVersion: 2,
    remotePayloadJson: remotePayloadJson,
    remotePayloadHash: 'remote-hash-$remoteServerSeq',
    remoteDeleted: remoteDeleted,
    conflictReason: 'remote_newer_local_dirty',
    detectedAt: '2026-06-16T09:00:00.000Z',
    status: SyncConflictStatus.pending,
  );
}

Future<void> _seedTimingRecord(
  Database db, {
  required int id,
  int deviceId = 1,
  int startDate = 20260601,
  double hours = 1,
  int incomeFen = 10000,
}) async {
  final record = TimingRecord(
    id: id,
    projectId: 'project-$id',
    deviceId: deviceId,
    startDate: startDate,
    contact: '甲方$id',
    site: '工地$id',
    type: TimingType.hours,
    startMeter: 0,
    endMeter: hours,
    hours: hours,
    income: incomeFen / 100,
    incomeFen: incomeFen,
  );
  await db.insert(
    'projects',
    Project(
      id: record.effectiveProjectId,
      contact: record.contact,
      site: record.site,
      createdAt: '2026-06-01T00:00:00.000Z',
      updatedAt: '2026-06-01T00:00:00.000Z',
    ).toMap(),
  );
  await db.insert(
    'timing_records',
    record.toMap(
      includeNullAllocationCutoffDate: true,
      includeNullDisplayEndDate: true,
    ),
  );
}

class _FakeConflictRepository implements SyncConflictRepository {
  const _FakeConflictRepository(this.conflicts);

  final List<SyncConflict> conflicts;

  @override
  Future<bool> insertIfAbsent(SyncConflict conflict) async => false;

  @override
  Future<bool> insertIfAbsentWithExecutor(
    DatabaseExecutor executor,
    SyncConflict conflict,
  ) async => false;

  @override
  Future<List<SyncConflict>> listPending({int limit = 50}) async => conflicts;

  @override
  Future<int?> earliestPendingServerSeq() async => null;

  @override
  Future<int> markResolved({
    required String id,
    required SyncConflictResolution resolution,
    DateTime? now,
  }) async => 0;

  @override
  Future<int> markResolvedWithExecutor(
    DatabaseExecutor executor, {
    required String id,
    required SyncConflictResolution resolution,
    DateTime? now,
  }) async => 0;
}

class _NoopResolver implements SyncConflictResolver {
  @override
  Future<void> useLocal(SyncConflict conflict) async {}

  @override
  Future<void> useRemote(SyncConflict conflict) async {}
}
