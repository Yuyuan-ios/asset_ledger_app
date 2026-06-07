import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/infrastructure/cloud/api_client.dart';
import 'package:asset_ledger/infrastructure/sync/sync_manager.dart';
import 'package:asset_ledger/infrastructure/sync/sync_outbox_entry.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_state_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

/// R5.27-A: SyncManager dry-run push preview must reuse the real pending,
/// folding, ordering, and invalid-metadata decisions without mutating outbox,
/// meta, or CloudApiClient.
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

  SyncManager managerWith(CloudApiClient client) {
    return SyncManager(
      outboxRepository: LocalSyncOutboxRepository(now: () => fixedNow),
      apiClient: client,
      syncStateRepository: LocalSyncStateRepository(now: () => fixedNow),
      now: () => fixedNow,
    );
  }

  group('sync_manager_dry_run_does_not_mutate_outbox', () {
    test('dry-run reads due pending rows and reports a stable preview without '
        'calling CloudApiClient or changing outbox/meta', () async {
      final db = await AppDatabase.database;
      await _insertOutbox(
        db,
        mark: 'A',
        entityType: 'account_payment',
        entityId: '1',
        operation: 'create',
        createdAt: '2026-06-01T00:00:01.000Z',
      );
      await _insertOutbox(
        db,
        mark: 'B',
        entityType: 'project',
        entityId: 'p1',
        operation: 'update',
        createdAt: '2026-06-01T00:00:02.000Z',
      );
      await _insertMeta(
        db,
        entityType: 'account_payment',
        localId: '1',
        status: 'pendingUpload',
      );

      final beforeOutbox = await _outboxSnapshot(db);
      final beforeMeta = await _metaSnapshot(db);

      final client = _RecordingClient.alwaysSuccess();
      final result = await managerWith(
        client,
      ).pushPending(mode: SyncPushMode.dryRun);

      expect(result.mode, SyncPushMode.dryRun);
      expect(result.isDryRun, isTrue);
      expect(result.pushed, 0);
      expect(result.failed, 0);
      expect(result.skipped, 0);
      expect(result.invalid, 0);
      expect(result.folded, 0);
      expect(result.attempted, 0);
      expect(result.wouldPush, 2);
      expect(result.wouldFold, 0);
      expect(result.plannedOutboxIds, <String>['outbox-A', 'outbox-B']);
      expect(result.toString(), contains('dryRun: true'));
      expect(client.sentMarks, isEmpty);
      expect(await _outboxSnapshot(db), beforeOutbox);
      expect(await _metaSnapshot(db), beforeMeta);

      final secondClient = _RecordingClient.alwaysSuccess();
      final secondResult = await managerWith(
        secondClient,
      ).pushPending(mode: SyncPushMode.dryRun);

      _expectSameDryRunPreview(secondResult, result);
      expect(secondClient.sentMarks, isEmpty);
      expect(await _outboxSnapshot(db), beforeOutbox);
      expect(await _metaSnapshot(db), beforeMeta);
    });
  });

  group('sync_manager_dry_run_reports_folding_without_deleting', () {
    test(
      'dry-run reports update-delete folding preview without deleteSuperseded; '
      'live mode still folds and pushes normally',
      () async {
        final db = await AppDatabase.database;
        await _insertOutbox(
          db,
          mark: 'U',
          entityType: 'project',
          entityId: 'p-fold',
          operation: 'update',
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'D',
          entityType: 'project',
          entityId: 'p-fold',
          operation: 'delete',
          createdAt: '2026-06-01T00:00:02.000Z',
        );

        final beforeOutbox = await _outboxSnapshot(db);
        final dryClient = _RecordingClient.alwaysSuccess();
        final dryRun = await managerWith(
          dryClient,
        ).pushPending(mode: SyncPushMode.dryRun);

        expect(dryClient.sentMarks, isEmpty);
        expect(dryRun.folded, 0);
        expect(dryRun.wouldFold, 1);
        expect(dryRun.wouldPush, 1);
        expect(dryRun.plannedOutboxIds, <String>['outbox-D']);
        expect(await _outboxSnapshot(db), beforeOutbox);

        final liveClient = _RecordingClient.alwaysSuccess();
        final live = await managerWith(liveClient).pushPending();

        expect(live.mode, SyncPushMode.live);
        expect(liveClient.sentMarks, <String>['D']);
        expect(live.folded, 1);
        expect(live.pushed, 1);
        expect(await _outboxCount(db), 0);
      },
    );
  });

  group('sync_manager_dry_run_reports_order_without_sending', () {
    test(
      'dry-run planned ids reflect transaction_group local_sequence order even '
      'when rows were inserted out of order',
      () async {
        final db = await AppDatabase.database;
        await _insertOutbox(
          db,
          mark: 'A2',
          groupId: 'txn-a',
          seq: 2,
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'A1',
          groupId: 'txn-a',
          seq: 1,
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'U',
          createdAt: '2026-06-01T00:00:02.000Z',
        );

        final beforeOutbox = await _outboxSnapshot(db);
        final client = _RecordingClient.alwaysSuccess();
        final result = await managerWith(
          client,
        ).pushPending(mode: SyncPushMode.dryRun);

        expect(result.wouldPush, 3);
        expect(result.plannedOutboxIds, <String>[
          'outbox-A1',
          'outbox-A2',
          'outbox-U',
        ]);
        expect(client.sentMarks, isEmpty);
        expect(await _outboxSnapshot(db), beforeOutbox);
      },
    );
  });

  group('sync_manager_dry_run_invalid_metadata_no_terminal_failed', () {
    test(
      'dry-run identifies invalid metadata without terminal failing rows; live '
      'mode still terminal fails the invalid group',
      () async {
        final db = await AppDatabase.database;
        await _insertOutbox(
          db,
          mark: 'BAD1',
          groupId: 'txn-bad',
          seq: 1,
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'BAD2',
          groupId: 'txn-bad',
          seq: 1,
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'OK',
          createdAt: '2026-06-01T00:00:02.000Z',
        );

        final beforeOutbox = await _outboxSnapshot(db);
        final dryClient = _RecordingClient.alwaysSuccess();
        final dryRun = await managerWith(
          dryClient,
        ).pushPending(mode: SyncPushMode.dryRun);

        expect(dryClient.sentMarks, isEmpty);
        expect(dryRun.invalid, 2);
        expect(dryRun.wouldPush, 1);
        expect(dryRun.plannedOutboxIds, <String>['outbox-OK']);
        expect(await _outboxSnapshot(db), beforeOutbox);
        for (final mark in ['BAD1', 'BAD2']) {
          final row = await _rowByMark(db, mark);
          expect(row, isNotNull);
          expect(row!['status'], 'pending');
          expect(row['retry_count'], 0);
          expect(row['next_retry_at'], isNull);
          expect(row['last_error'], isNull);
        }

        final liveClient = _RecordingClient.alwaysSuccess();
        final live = await managerWith(liveClient).pushPending();

        expect(live.mode, SyncPushMode.live);
        expect(live.invalid, 2);
        expect(live.pushed, 1);
        expect(liveClient.sentMarks, <String>['OK']);
        for (final mark in ['BAD1', 'BAD2']) {
          final row = await _rowByMark(db, mark);
          expect(row, isNotNull);
          expect(row!['status'], 'failed');
          expect(row['retry_count'], 0);
          expect(row['next_retry_at'], isNull);
          expect(row['last_error'].toString(), contains('invalid_metadata'));
        }
        expect(await _rowByMark(db, 'OK'), isNull);
      },
    );
  });

  group('sync_manager_dry_run_respects_push_gate', () {
    test(
      'dry-run is blocked before listPending/send/mutation when restore gate '
      'is set',
      () async {
        final gateRepo = LocalSyncStateRepository(now: () => fixedNow);
        await AppDatabase.inTransaction<void>(
          (txn) => gateRepo.markPushGateRestorePendingWithExecutor(txn),
        );

        final outbox = _FailingOutboxPushRepository();
        final client = _RecordingClient.alwaysSuccess();
        final manager = SyncManager(
          outboxRepository: outbox,
          apiClient: client,
          syncStateRepository: gateRepo,
          now: () => fixedNow,
        );

        await expectLater(
          manager.pushPending(mode: SyncPushMode.dryRun),
          throwsA(
            isA<SyncPushBlockedException>().having(
              (e) => e.reason,
              'reason',
              SyncStateRepository.gateRestorePending,
            ),
          ),
        );

        expect(outbox.listPendingCallCount, 0);
        expect(outbox.mutationCallCount, 0);
        expect(client.sentMarks, isEmpty);
      },
    );
  });

  group('sync_manager_live_mode_regression', () {
    test(
      'default mode remains live and still sends, acks, and clears meta',
      () async {
        final db = await AppDatabase.database;
        await _insertOutbox(
          db,
          mark: 'L',
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
        final result = await managerWith(client).pushPending();

        expect(result.mode, SyncPushMode.live);
        expect(result.isDryRun, isFalse);
        expect(result.pushed, 1);
        expect(result.wouldPush, 0);
        expect(result.wouldFold, 0);
        expect(client.sentMarks, <String>['L']);
        expect(await _outboxCount(db), 0);
        expect(await _metaStatus(db, 'account_payment', 'live-1'), 'synced');
      },
    );
  });
}

Future<void> _insertOutbox(
  Database db, {
  required String mark,
  String? groupId,
  int? seq,
  required String createdAt,
  String entityType = 'timing_record',
  String? entityId,
  String operation = 'create',
  String? nextRetryAt,
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
    'next_retry_at': nextRetryAt,
    'transaction_group_id': groupId,
    'local_sequence': seq,
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

Future<int> _outboxCount(Database db) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM sync_outbox');
  return (rows.single['c'] as num).toInt();
}

Future<Map<String, Object?>?> _rowByMark(Database db, String mark) async {
  final rows = await db.query(
    'sync_outbox',
    where: 'id = ?',
    whereArgs: ['outbox-$mark'],
  );
  return rows.isEmpty ? null : rows.single;
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

void _expectSameDryRunPreview(SyncPushResult actual, SyncPushResult expected) {
  expect(actual.mode, expected.mode);
  expect(actual.pushed, expected.pushed);
  expect(actual.failed, expected.failed);
  expect(actual.skipped, expected.skipped);
  expect(actual.invalid, expected.invalid);
  expect(actual.folded, expected.folded);
  expect(actual.wouldPush, expected.wouldPush);
  expect(actual.wouldFold, expected.wouldFold);
  expect(actual.plannedOutboxIds, expected.plannedOutboxIds);
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

class _FailingOutboxPushRepository implements SyncOutboxPushRepository {
  int listPendingCallCount = 0;
  int mutationCallCount = 0;

  @override
  Future<List<SyncOutboxEntry>> listPending({int limit = 50}) async {
    listPendingCallCount += 1;
    throw StateError('listPending must not be called while push gate is set');
  }

  @override
  Future<void> deleteAcknowledged(String id) async {
    mutationCallCount += 1;
    throw StateError('deleteAcknowledged must not be called in this test');
  }

  @override
  Future<void> deleteSuperseded(String id) async {
    mutationCallCount += 1;
    throw StateError('deleteSuperseded must not be called in this test');
  }

  @override
  Future<void> markFailed({
    required String id,
    required String lastError,
    required String nextRetryAtIso,
  }) async {
    mutationCallCount += 1;
    throw StateError('markFailed must not be called in this test');
  }

  @override
  Future<void> markTerminalFailed({
    required String id,
    required String lastError,
  }) async {
    mutationCallCount += 1;
    throw StateError('markTerminalFailed must not be called in this test');
  }
}
