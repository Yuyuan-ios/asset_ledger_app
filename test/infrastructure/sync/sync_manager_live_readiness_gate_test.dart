import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/infrastructure/cloud/api_client.dart';
import 'package:asset_ledger/infrastructure/sync/sync_live_readiness_gate.dart';
import 'package:asset_ledger/infrastructure/sync/sync_manager.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_state_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  final fixedNow = DateTime.utc(2026, 6, 1, 12, 0, 0);

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

  SyncManager managerWith({
    required CloudApiClient client,
    required SyncLiveReadinessGate liveReadinessGate,
    SyncStateRepository syncStateRepository = const LocalSyncStateRepository(),
  }) {
    return SyncManager(
      outboxRepository: LocalSyncOutboxRepository(now: () => fixedNow),
      apiClient: client,
      syncStateRepository: syncStateRepository,
      liveReadinessGate: liveReadinessGate,
      now: () => fixedNow,
    );
  }

  group('sync_manager_live_blocks_when_readiness_missing', () {
    test(
      'default live readiness blocks before send or outbox/meta mutation',
      () async {
        final db = await AppDatabase.database;
        await _insertOutbox(
          db,
          mark: 'BLOCKED',
          entityType: 'account_payment',
          entityId: 'blocked-1',
          operation: 'update',
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertMeta(
          db,
          entityType: 'account_payment',
          localId: 'blocked-1',
          status: 'pendingUpdate',
        );

        final beforeOutbox = await _outboxSnapshot(db);
        final beforeMeta = await _metaSnapshot(db);
        final client = _RecordingClient.alwaysSuccess();
        final manager = managerWith(
          client: client,
          liveReadinessGate: const DefaultSyncLiveReadinessGate(),
        );

        await expectLater(
          manager.pushPending(mode: SyncPushMode.live),
          throwsA(
            isA<SyncPushBlockedException>()
                .having(
                  (e) => e.reason,
                  'reason',
                  contains('missing prerequisites'),
                )
                .having(
                  (e) => e.reason,
                  'reason',
                  contains('money-fen-primary-storage-not-ready'),
                )
                .having(
                  (e) => e.reason,
                  'reason',
                  contains('real-cloud-transport-not-configured'),
                ),
          ),
        );

        expect(client.sentMarks, isEmpty);
        expect(await _outboxSnapshot(db), beforeOutbox);
        expect(await _metaSnapshot(db), beforeMeta);

        final row = await _rowByMark(db, 'BLOCKED');
        expect(row, isNotNull);
        expect(row!['status'], 'pending');
        expect(row['retry_count'], 0);
        expect(row['last_error'], isNull);
        expect(row['next_retry_at'], isNull);
      },
    );
  });

  group('sync_manager_dry_run_ignores_live_readiness_gate', () {
    test('blocking live readiness still allows dry-run preview', () async {
      final db = await AppDatabase.database;
      await _insertOutbox(
        db,
        mark: 'DRY',
        createdAt: '2026-06-01T00:00:01.000Z',
      );
      await _insertMeta(
        db,
        entityType: 'timing_record',
        localId: 'DRY',
        status: 'pendingUpload',
      );

      final beforeOutbox = await _outboxSnapshot(db);
      final beforeMeta = await _metaSnapshot(db);
      final client = _RecordingClient.alwaysSuccess();
      final manager = managerWith(
        client: client,
        liveReadinessGate: const DefaultSyncLiveReadinessGate(),
      );

      final result = await manager.pushPending(mode: SyncPushMode.dryRun);

      expect(result.isDryRun, isTrue);
      expect(result.invalid, 0);
      expect(result.wouldPush, 1);
      expect(result.plannedOutboxIds, <String>['outbox-DRY']);
      expect(client.sentMarks, isEmpty);
      expect(await _outboxSnapshot(db), beforeOutbox);
      expect(await _metaSnapshot(db), beforeMeta);
    });
  });

  group('sync_manager_live_runs_when_readiness_ready', () {
    test(
      'ready test gate preserves live send ack delete and meta ack',
      () async {
        final db = await AppDatabase.database;
        await _insertOutbox(
          db,
          mark: 'LIVE',
          entityType: 'account_payment',
          entityId: 'live-1',
          operation: 'create',
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertMeta(
          db,
          entityType: 'account_payment',
          localId: 'live-1',
          status: 'pendingUpload',
        );

        final client = _RecordingClient.alwaysSuccess();
        final manager = managerWith(
          client: client,
          liveReadinessGate: const StaticSyncLiveReadinessGate.readyForTest(),
        );

        final result = await manager.pushPending(mode: SyncPushMode.live);

        expect(result.mode, SyncPushMode.live);
        expect(result.isDryRun, isFalse);
        expect(result.pushed, 1);
        expect(result.failed, 0);
        expect(result.wouldPush, 0);
        expect(client.sentMarks, <String>['LIVE']);
        expect(await _outboxCount(db), 0);
        expect(await _metaStatus(db, 'account_payment', 'live-1'), 'synced');
      },
    );
  });

  group('sync_manager_restore_gate_still_blocks_before_or_with_readiness', () {
    test(
      'restore gate blocks live and dry-run before readiness or mutation',
      () async {
        final db = await AppDatabase.database;
        await _insertOutbox(
          db,
          mark: 'GATED',
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertMeta(
          db,
          entityType: 'timing_record',
          localId: 'GATED',
          status: 'pendingUpload',
        );

        final beforeOutbox = await _outboxSnapshot(db);
        final beforeMeta = await _metaSnapshot(db);
        final gateRepo = LocalSyncStateRepository(now: () => fixedNow);
        await AppDatabase.inTransaction<void>(
          (txn) => gateRepo.markPushGateRestorePendingWithExecutor(txn),
        );

        final readinessGate = _CountingReadinessGate(
          const SyncCloudReadinessResult(
            completedPrerequisites: ['would-be-ready'],
          ),
        );
        final client = _RecordingClient.alwaysSuccess();
        final manager = managerWith(
          client: client,
          syncStateRepository: gateRepo,
          liveReadinessGate: readinessGate,
        );

        for (final mode in [SyncPushMode.live, SyncPushMode.dryRun]) {
          await expectLater(
            manager.pushPending(mode: mode),
            throwsA(
              isA<SyncPushBlockedException>().having(
                (e) => e.reason,
                'reason',
                SyncStateRepository.gateRestorePending,
              ),
            ),
          );
        }

        expect(readinessGate.checkCallCount, 0);
        expect(client.sentMarks, isEmpty);
        expect(await _outboxSnapshot(db), beforeOutbox);
        expect(await _metaSnapshot(db), beforeMeta);
      },
    );
  });
}

Future<void> _insertOutbox(
  Database db, {
  required String mark,
  required String createdAt,
  String entityType = 'timing_record',
  String? entityId,
  String operation = 'create',
}) async {
  await db.insert('sync_outbox', {
    'id': 'outbox-$mark',
    'entity_type': entityType,
    'entity_id': entityId ?? mark,
    'operation': operation,
    'payload_json': jsonEncode({'mark': mark}),
    'payload_hash': 'hash-$mark',
    'status': 'pending',
    'retry_count': 0,
    'last_error': null,
    'next_retry_at': null,
    'transaction_group_id': null,
    'local_sequence': null,
    'created_at': createdAt,
    'updated_at': createdAt,
  });
}

Future<void> _insertMeta(
  Database db, {
  required String entityType,
  required String localId,
  required String status,
}) async {
  await db.insert('entity_sync_meta', {
    'entity_type': entityType,
    'local_id': localId,
    'sync_status': status,
    'version': 0,
    'source': 'owner_app',
  });
}

Future<List<Map<String, Object?>>> _outboxSnapshot(Database db) async {
  final rows = await db.query('sync_outbox', orderBy: 'id ASC');
  return rows.map(Map<String, Object?>.from).toList(growable: false);
}

Future<List<Map<String, Object?>>> _metaSnapshot(Database db) async {
  final rows = await db.query(
    'entity_sync_meta',
    orderBy: 'entity_type ASC, local_id ASC',
  );
  return rows.map(Map<String, Object?>.from).toList(growable: false);
}

Future<Map<String, Object?>?> _rowByMark(Database db, String mark) async {
  final rows = await db.query(
    'sync_outbox',
    where: 'id = ?',
    whereArgs: ['outbox-$mark'],
  );
  return rows.isEmpty ? null : rows.single;
}

Future<int> _outboxCount(Database db) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM sync_outbox');
  return (rows.single['c'] as num).toInt();
}

Future<Object?> _metaStatus(
  Database db,
  String entityType,
  String localId,
) async {
  final rows = await db.query(
    'entity_sync_meta',
    where: 'entity_type = ? AND local_id = ?',
    whereArgs: [entityType, localId],
  );
  return rows.isEmpty ? null : rows.single['sync_status'];
}

class _CountingReadinessGate implements SyncLiveReadinessGate {
  _CountingReadinessGate(this._result);

  final SyncCloudReadinessResult _result;
  int checkCallCount = 0;

  @override
  Future<SyncCloudReadinessResult> check() async {
    checkCallCount += 1;
    return _result;
  }
}

class _RecordingClient implements CloudApiClient {
  _RecordingClient._({required this.failAll});

  factory _RecordingClient.alwaysSuccess() =>
      _RecordingClient._(failAll: false);

  final bool failAll;
  final List<String> sentMarks = [];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final mark = (jsonDecode(request.bodyJson!) as Map)['mark'] as String;
    sentMarks.add(mark);
    if (failAll) {
      return const ApiResponse(
        statusCode: 500,
        error: ApiError(code: 'server_error', message: 'boom', retryable: true),
      );
    }
    return const ApiResponse(statusCode: 200);
  }
}
