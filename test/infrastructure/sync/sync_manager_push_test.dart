import 'dart:convert';
import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/infrastructure/cloud/api_client.dart';
import 'package:asset_ledger/infrastructure/sync/sync_manager.dart';
import 'package:asset_ledger/infrastructure/sync/sync_live_readiness_gate.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_state_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

/// R5.22-B SyncManager push algorithm: ordering, success ack/delete,
/// failure retry/backoff, same-group stop-on-failure, invalid-metadata defense.
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
      syncStateRepository: const LocalSyncStateRepository(),
      liveReadinessGate: const StaticSyncLiveReadinessGate.readyForTest(),
      now: () => fixedNow,
    );
  }

  group('sync_manager_push_ordering_transaction_group', () {
    test(
      'sends grouped rows by local_sequence ASC and groups by min created_at, '
      'acks each success so they are not re-pushed',
      () async {
        final db = await AppDatabase.database;
        // Group A: insert seq 2 BEFORE seq 1 to prove sequence-based ordering.
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
        // Group B: single row, later min created_at than A.
        await _insertOutbox(
          db,
          mark: 'B1',
          groupId: 'txn-b',
          seq: 1,
          createdAt: '2026-06-01T00:00:02.000Z',
        );
        // Ungrouped row, latest.
        await _insertOutbox(
          db,
          mark: 'U',
          createdAt: '2026-06-01T00:00:03.000Z',
        );

        final client = _ProgrammableClient.alwaysSuccess();
        final result = await managerWith(client).pushPending();

        // Within group A: A1 before A2. Group order: A (01) → B (02) → U (03).
        expect(client.sentMarks, <String>['A1', 'A2', 'B1', 'U']);
        expect(result.pushed, 4);
        expect(result.failed, 0);

        // All acked → deleted → a second push sends nothing.
        expect(await _outboxCount(db), 0);
        final client2 = _ProgrammableClient.alwaysSuccess();
        final result2 = await managerWith(client2).pushPending();
        expect(client2.sentMarks, isEmpty);
        expect(result2.pushed, 0);
      },
    );
  });

  group('sync_manager_push_success_ack_deletes_pending', () {
    test(
      'a successful push deletes the pending row and is not re-sent',
      () async {
        final db = await AppDatabase.database;
        await _insertOutbox(
          db,
          mark: 'X',
          createdAt: '2026-06-01T00:00:01.000Z',
        );

        final client = _ProgrammableClient.alwaysSuccess();
        final result = await managerWith(client).pushPending();
        expect(result.pushed, 1);
        expect(await _outboxCount(db), 0);

        // Second push: nothing left.
        final client2 = _ProgrammableClient.alwaysSuccess();
        final result2 = await managerWith(client2).pushPending();
        expect(client2.sentMarks, isEmpty);
        expect(result2.pushed, 0);
      },
    );

    test('sends entity_sync_meta.version as base_version and applies accepted '
        'new_version plus server_seq cursor', () async {
      final db = await AppDatabase.database;
      await _insertOutbox(
        db,
        mark: 'V',
        entityType: 'timing_record',
        entityId: '7',
        operation: 'update',
        createdAt: '2026-06-01T00:00:01.000Z',
      );
      await _insertMeta(
        db,
        entityType: 'timing_record',
        localId: '7',
        status: 'pendingUpdate',
        version: 5,
      );

      final client = _VersionAckClient(serverSeq: 9, newVersion: 6);
      final result = await managerWith(client).pushPending();

      expect(result.pushed, 1);
      expect(result.failed, 0);
      expect(client.sentMarks, <String>['V']);
      expect(client.sentBaseVersions, <int>[5]);
      expect(await _outboxCount(db), 0);
      final metaRows = await db.query('entity_sync_meta');
      expect(metaRows.single['sync_status'], 'synced');
      expect(metaRows.single['version'], 6);
      final cursorRows = await db.query(
        'sync_state',
        where: 'scope = ?',
        whereArgs: const [SyncStateRepository.kPullCursorScope],
      );
      expect(cursorRows.single['pull_cursor'], 9);
    });
  });

  group('sync_manager_push_failure_bumps_retry_backoff', () {
    test(
      'failure keeps the row, bumps retry_count, writes last_error and '
      'next_retry_at = 60s / 5min / 30min, and skips the un-due row',
      () async {
        final db = await AppDatabase.database;
        await _insertOutbox(
          db,
          mark: 'F',
          createdAt: '2026-06-01T00:00:01.000Z',
        );

        final client = _ProgrammableClient.alwaysFail();
        final result = await managerWith(client).pushPending();
        expect(result.failed, 1);
        expect(result.pushed, 0);

        var row = await _singleRow(db);
        expect(row['status'], 'pending', reason: 'failed row stays pending');
        expect(row['retry_count'], 1);
        expect(row['last_error'], isNotNull);
        expect(
          row['next_retry_at'],
          fixedNow.add(const Duration(seconds: 60)).toIso8601String(),
          reason: '1st failure → now + 60s',
        );

        // Immediately retry at the same clock: row is not yet due → skipped.
        final client2 = _ProgrammableClient.alwaysFail();
        await managerWith(client2).pushPending();
        expect(
          client2.sentMarks,
          isEmpty,
          reason: 'un-due row must be skipped',
        );
        row = await _singleRow(db);
        expect(row['retry_count'], 1, reason: 'skipped row is untouched');

        // Force it due → 2nd failure → 5min.
        await _forceDue(db);
        await managerWith(_ProgrammableClient.alwaysFail()).pushPending();
        row = await _singleRow(db);
        expect(row['retry_count'], 2);
        expect(
          row['next_retry_at'],
          fixedNow.add(const Duration(minutes: 5)).toIso8601String(),
        );

        // Force due → 3rd failure → 30min (and stays 30min after).
        await _forceDue(db);
        await managerWith(_ProgrammableClient.alwaysFail()).pushPending();
        row = await _singleRow(db);
        expect(row['retry_count'], 3);
        expect(
          row['next_retry_at'],
          fixedNow.add(const Duration(minutes: 30)).toIso8601String(),
        );
      },
    );
  });

  group('sync_manager_group_failure_stops_following_same_group', () {
    test(
      'a failure inside a group stops the rest of that group but other groups '
      'continue',
      () async {
        final db = await AppDatabase.database;
        // Group G: seq1 success, seq2 fail, seq3 must NOT be sent.
        await _insertOutbox(
          db,
          mark: 'G1',
          groupId: 'txn-g',
          seq: 1,
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'G2',
          groupId: 'txn-g',
          seq: 2,
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'G3',
          groupId: 'txn-g',
          seq: 3,
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        // Independent group H continues.
        await _insertOutbox(
          db,
          mark: 'H1',
          groupId: 'txn-h',
          seq: 1,
          createdAt: '2026-06-01T00:00:02.000Z',
        );

        final client = _ProgrammableClient(failMarks: {'G2'});
        final result = await managerWith(client).pushPending();

        // G3 was never sent; H1 still sent.
        expect(client.sentMarks, <String>['G1', 'G2', 'H1']);
        expect(result.pushed, 2, reason: 'G1 + H1');
        expect(result.failed, 1, reason: 'G2');
        expect(result.skipped, 1, reason: 'G3 skipped after G2 failed');

        // G1 acked/deleted, H1 acked/deleted; G2 retried; G3 untouched pending.
        expect(await _rowByMark(db, 'G1'), isNull);
        expect(await _rowByMark(db, 'H1'), isNull);
        final g2 = await _rowByMark(db, 'G2');
        expect(g2, isNotNull);
        expect(g2!['retry_count'], 1);
        expect(g2['next_retry_at'], isNotNull);
        final g3 = await _rowByMark(db, 'G3');
        expect(g3, isNotNull);
        expect(
          g3!['retry_count'],
          0,
          reason: 'skipped row keeps retry_count 0',
        );
        expect(g3['next_retry_at'], isNull);
      },
    );
  });

  group('sync_manager_invalid_transaction_group_metadata', () {
    test(
      'an invalid group becomes terminal failed (not infinite backoff), is not '
      'sent, is not re-processed, while valid groups still push',
      () async {
        final db = await AppDatabase.database;
        // Invalid group: duplicate sequence (1,1) — only possible via legacy/bad
        // data inserted directly, since the repository validates on enqueue.
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
        // A valid independent ungrouped row.
        await _insertOutbox(
          db,
          mark: 'OK',
          createdAt: '2026-06-01T00:00:02.000Z',
        );

        final client = _ProgrammableClient.alwaysSuccess();
        final result = await managerWith(client).pushPending();

        // The invalid group is never sent; the valid row is.
        expect(client.sentMarks, <String>['OK']);
        expect(result.invalid, 2);
        expect(result.pushed, 1);

        // Valid row acked/deleted; invalid rows retained with diagnostic error.
        expect(await _rowByMark(db, 'OK'), isNull);
        final bad1 = await _rowByMark(db, 'BAD1');
        final bad2 = await _rowByMark(db, 'BAD2');
        expect(bad1, isNotNull);
        expect(bad2, isNotNull);
        // R5.22-B-Hardening: terminal failed, not transient backoff.
        expect(bad1!['status'], 'failed');
        expect(bad1['next_retry_at'], isNull, reason: 'no future retry window');
        expect(bad1['retry_count'], 0, reason: 'terminal, not a backoff retry');
        expect(bad1['last_error'].toString(), contains('invalid_metadata'));
        expect(bad2!['status'], 'failed');
        expect(bad2['last_error'].toString(), contains('invalid_metadata'));

        // A second push must NOT re-process the terminal-failed rows (they are
        // no longer pending) and must not call the client again.
        final client2 = _ProgrammableClient.alwaysSuccess();
        final result2 = await managerWith(client2).pushPending();
        expect(client2.sentMarks, isEmpty);
        expect(result2.invalid, 0);
        expect(result2.pushed, 0);
        // Even forcing next_retry_at to the past keeps them out (status=failed).
        await _forceDue(db);
        final client3 = _ProgrammableClient.alwaysSuccess();
        final result3 = await managerWith(client3).pushPending();
        expect(client3.sentMarks, isEmpty);
        expect(result3.invalid, 0);
      },
    );

    test('a grouped row missing local_sequence is terminal failed', () async {
      final db = await AppDatabase.database;
      await _insertOutbox(
        db,
        mark: 'NOSEQ',
        groupId: 'txn-z',
        seq: null,
        createdAt: '2026-06-01T00:00:01.000Z',
      );

      final client = _ProgrammableClient.alwaysSuccess();
      final result = await managerWith(client).pushPending();
      expect(client.sentMarks, isEmpty);
      expect(result.invalid, 1);
      final row = await _rowByMark(db, 'NOSEQ');
      expect(row, isNotNull);
      expect(row!['status'], 'failed');
      expect(row['next_retry_at'], isNull);
      expect(row['last_error'].toString(), contains('invalid_metadata'));
    });
  });

  group('sync_manager_pushPending_production_caller_lock', () {
    test(
      'lib/ only calls SyncManager.pushPending from the gated production caller',
      () {
        final libDir = Directory('${Directory.current.path}/lib');
        final callers = <String>[];
        for (final entity in libDir.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final rel = entity.path
              .substring(Directory.current.path.length + 1)
              .replaceAll('\\', '/');
          if (rel == 'lib/infrastructure/sync/sync_manager.dart') continue;
          if (entity.readAsStringSync().contains('pushPending(')) {
            callers.add(rel);
          }
        }
        expect(
          callers,
          ['lib/app/sync_production_caller.dart'],
          reason:
              'SyncManager.pushPending must remain behind the B6.4 '
              'config/readiness-gated production caller.\n'
              '${callers.join('\n')}',
        );
        final callerSource = File(
          '${Directory.current.path}/lib/app/sync_production_caller.dart',
        ).readAsStringSync();
        expect(callerSource, contains('_liveReadinessGate.check()'));
        expect(
          callerSource.indexOf('_liveReadinessGate.check()'),
          lessThan(
            callerSource.indexOf('pushPending(mode: SyncPushMode.live)'),
          ),
        );
      },
    );
  });

  group('sync_manager_push_success_meta_ack', () {
    test(
      'create/update success clears pendingUpload/pendingUpdate meta to synced; '
      'delete leaves meta untouched; no meta is fabricated',
      () async {
        final db = await AppDatabase.database;
        // Seed outbox rows + matching entity_sync_meta in pending states.
        await _insertOutbox(
          db,
          mark: 'C',
          entityType: 'account_payment',
          entityId: '1',
          operation: 'create',
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertMeta(
          db,
          entityType: 'account_payment',
          localId: '1',
          status: 'pendingUpload',
        );
        await _insertOutbox(
          db,
          mark: 'U',
          entityType: 'account_payment',
          entityId: '2',
          operation: 'update',
          createdAt: '2026-06-01T00:00:02.000Z',
        );
        await _insertMeta(
          db,
          entityType: 'account_payment',
          localId: '2',
          status: 'pendingUpdate',
        );
        await _insertOutbox(
          db,
          mark: 'D',
          entityType: 'account_payment',
          entityId: '3',
          operation: 'delete',
          createdAt: '2026-06-01T00:00:03.000Z',
        );
        await _insertMeta(
          db,
          entityType: 'account_payment',
          localId: '3',
          status: 'pendingDelete',
        );
        // A create whose meta row does NOT exist → must not be fabricated.
        await _insertOutbox(
          db,
          mark: 'N',
          entityType: 'account_payment',
          entityId: '4',
          operation: 'create',
          createdAt: '2026-06-01T00:00:04.000Z',
        );

        final result = await managerWith(
          _ProgrammableClient.alwaysSuccess(),
        ).pushPending();
        expect(result.pushed, 4);
        expect(await _outboxCount(db), 0, reason: 'all acked/deleted');

        // create/update meta flipped to synced.
        expect(await _metaStatus(db, 'account_payment', '1'), 'synced');
        expect(await _metaStatus(db, 'account_payment', '2'), 'synced');
        // delete meta left untouched (deferred deleted-entity lifecycle).
        expect(await _metaStatus(db, 'account_payment', '3'), 'pendingDelete');
        // no meta fabricated for entity 4.
        expect(await _metaStatus(db, 'account_payment', '4'), isNull);
      },
    );
  });
}

// ── helpers ──────────────────────────────────────────────────────────────

Future<void> _insertOutbox(
  Database db, {
  required String mark,
  String? groupId,
  int? seq,
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
  int version = 0,
}) async {
  await db.insert('entity_sync_meta', {
    'entity_type': entityType,
    'local_id': localId,
    'sync_status': status,
    'version': version,
    'source': 'owner_app',
  });
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

Future<int> _outboxCount(Database db) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM sync_outbox');
  return (rows.single['c'] as num).toInt();
}

Future<Map<String, Object?>> _singleRow(Database db) async {
  final rows = await db.query('sync_outbox');
  expect(rows, hasLength(1));
  return rows.single;
}

Future<Map<String, Object?>?> _rowByMark(Database db, String mark) async {
  final rows = await db.query(
    'sync_outbox',
    where: 'id = ?',
    whereArgs: ['outbox-$mark'],
  );
  return rows.isEmpty ? null : rows.single;
}

/// Force all rows' next_retry_at into the past so the next push retries them.
Future<void> _forceDue(Database db) async {
  await db.rawUpdate(
    "UPDATE sync_outbox SET next_retry_at = '2000-01-01T00:00:00.000Z'",
  );
}

class _ProgrammableClient implements CloudApiClient {
  _ProgrammableClient({Set<String> failMarks = const {}})
    : _failMarks = failMarks,
      _failAll = false;
  _ProgrammableClient._all(this._failAll) : _failMarks = const {};

  factory _ProgrammableClient.alwaysSuccess() =>
      _ProgrammableClient._all(false);
  factory _ProgrammableClient.alwaysFail() => _ProgrammableClient._all(true);

  final Set<String> _failMarks;
  final bool _failAll;

  final List<String> sentMarks = [];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final mark = _markFromPushRequest(request);
    sentMarks.add(mark);
    final fail = _failAll || _failMarks.contains(mark);
    if (fail) {
      return const ApiResponse(
        statusCode: 500,
        error: ApiError(code: 'server_error', message: 'boom', retryable: true),
      );
    }
    return const ApiResponse(statusCode: 200);
  }
}

String _markFromPushRequest(ApiRequest request) {
  final decoded = jsonDecode(request.bodyJson!) as Map;
  final changes = decoded['changes'] as List;
  final change = changes.single as Map;
  final payload = change['payload'] as Map;
  return payload['mark'] as String;
}

class _VersionAckClient implements CloudApiClient {
  _VersionAckClient({required this.serverSeq, required this.newVersion});

  final int serverSeq;
  final int newVersion;
  final List<String> sentMarks = [];
  final List<int> sentBaseVersions = [];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final decoded = jsonDecode(request.bodyJson!) as Map;
    final changes = decoded['changes'] as List;
    final change = changes.single as Map;
    final payload = change['payload'] as Map;
    sentMarks.add(payload['mark'] as String);
    sentBaseVersions.add((change['base_version'] as num).toInt());
    return ApiResponse(
      statusCode: 200,
      bodyJson: jsonEncode({
        'accepted': [
          {
            'entity_type': change['entity_type'],
            'entity_id': change['entity_id'],
            'server_seq': serverSeq,
            'new_version': newVersion,
          },
        ],
        'conflicts': const [],
      }),
    );
  }
}
