import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/infrastructure/cloud/api_client.dart';
import 'package:asset_ledger/infrastructure/sync/sync_manager.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_state_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

/// R5.23: pendingUpload + pendingDelete folding inside SyncManager.pushPending.
///
/// Each test exercises the real LocalSyncOutboxRepository + SyncManager pair
/// (no test doubles for the push lifecycle), so folding behavior is asserted
/// at the same layer as R5.22-B push ordering/retry/ack.
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

  SyncManager managerWith(_ProgrammableClient client) {
    return SyncManager(
      outboxRepository: LocalSyncOutboxRepository(now: () => fixedNow),
      apiClient: client,
      syncStateRepository: const LocalSyncStateRepository(),
      now: () => fixedNow,
    );
  }

  group('sync_manager_folds_create_delete_without_push', () {
    test(
      'create followed by delete for the same entity: both rows are folded, '
      'CloudApiClient is not called, second push sees nothing left',
      () async {
        final db = await AppDatabase.database;
        await _insertOutbox(
          db,
          mark: 'C',
          entityType: 'account_payment',
          entityId: '1',
          operation: 'create',
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'D',
          entityType: 'account_payment',
          entityId: '1',
          operation: 'delete',
          createdAt: '2026-06-01T00:00:02.000Z',
        );

        final client = _ProgrammableClient.alwaysSuccess();
        final result = await managerWith(client).pushPending();

        expect(client.sentMarks, isEmpty,
            reason: 'create+delete pair must not reach the cloud client');
        expect(result.pushed, 0);
        expect(result.failed, 0);
        expect(result.invalid, 0);
        expect(result.folded, 2);

        // Both rows are removed from outbox; not marked failed.
        expect(await _outboxCount(db), 0);

        // Second push must see nothing left to do.
        final client2 = _ProgrammableClient.alwaysSuccess();
        final result2 = await managerWith(client2).pushPending();
        expect(client2.sentMarks, isEmpty);
        expect(result2.pushed, 0);
        expect(result2.folded, 0);
      },
    );

    test(
      'create followed by update followed by delete for the same entity: '
      'every row is folded; entity logically vanishes for the cloud',
      () async {
        final db = await AppDatabase.database;
        await _insertOutbox(
          db,
          mark: 'C',
          entityType: 'project_write_off',
          entityId: 'wo-1',
          operation: 'create',
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'U',
          entityType: 'project_write_off',
          entityId: 'wo-1',
          operation: 'update',
          createdAt: '2026-06-01T00:00:02.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'D',
          entityType: 'project_write_off',
          entityId: 'wo-1',
          operation: 'delete',
          createdAt: '2026-06-01T00:00:03.000Z',
        );

        final client = _ProgrammableClient.alwaysSuccess();
        final result = await managerWith(client).pushPending();

        expect(client.sentMarks, isEmpty);
        expect(result.folded, 3);
        expect(result.pushed, 0);
        expect(await _outboxCount(db), 0);
      },
    );
  });

  group('sync_manager_folds_update_before_delete', () {
    test(
      'update followed by delete for the same entity: update is folded; '
      'delete pushes normally and is acked',
      () async {
        final db = await AppDatabase.database;
        await _insertOutbox(
          db,
          mark: 'U1',
          entityType: 'project',
          entityId: 'p1',
          operation: 'update',
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'U2',
          entityType: 'project',
          entityId: 'p1',
          operation: 'update',
          createdAt: '2026-06-01T00:00:02.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'D',
          entityType: 'project',
          entityId: 'p1',
          operation: 'delete',
          createdAt: '2026-06-01T00:00:03.000Z',
        );

        final client = _ProgrammableClient.alwaysSuccess();
        final result = await managerWith(client).pushPending();

        expect(client.sentMarks, <String>['D'],
            reason: 'only the delete reaches the cloud client');
        expect(result.folded, 2);
        expect(result.pushed, 1);
        expect(result.failed, 0);
        expect(await _outboxCount(db), 0);
      },
    );
  });

  group('sync_manager_folding_keeps_entities_isolated', () {
    test(
      'A: create+delete folded; B: create pushes; C: delete pushes; '
      'D: create+update untouched (R5.23 only folds delete-terminated runs)',
      () async {
        final db = await AppDatabase.database;
        // Entity A: create + delete → both folded.
        await _insertOutbox(
          db,
          mark: 'A-C',
          entityType: 'account_payment',
          entityId: 'A',
          operation: 'create',
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'A-D',
          entityType: 'account_payment',
          entityId: 'A',
          operation: 'delete',
          createdAt: '2026-06-01T00:00:02.000Z',
        );
        // Entity B: lone create.
        await _insertOutbox(
          db,
          mark: 'B-C',
          entityType: 'account_payment',
          entityId: 'B',
          operation: 'create',
          createdAt: '2026-06-01T00:00:03.000Z',
        );
        // Entity C: lone delete.
        await _insertOutbox(
          db,
          mark: 'C-D',
          entityType: 'account_payment',
          entityId: 'C',
          operation: 'delete',
          createdAt: '2026-06-01T00:00:04.000Z',
        );
        // Entity D: create + update (no delete) — folding rule does not
        // apply; both rows must push.
        await _insertOutbox(
          db,
          mark: 'D-C',
          entityType: 'account_payment',
          entityId: 'D',
          operation: 'create',
          createdAt: '2026-06-01T00:00:05.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'D-U',
          entityType: 'account_payment',
          entityId: 'D',
          operation: 'update',
          createdAt: '2026-06-01T00:00:06.000Z',
        );

        final client = _ProgrammableClient.alwaysSuccess();
        final result = await managerWith(client).pushPending();

        expect(client.sentMarks, <String>['B-C', 'C-D', 'D-C', 'D-U']);
        expect(result.folded, 2);
        expect(result.pushed, 4);
        expect(await _outboxCount(db), 0);
      },
    );
  });

  group('sync_manager_folding_respects_backoff', () {
    test(
      'a not-yet-due delete is invisible to listPending, so the earlier create '
      'is pushed normally and is not folded against the future delete',
      () async {
        final db = await AppDatabase.database;
        // Create: due now.
        await _insertOutbox(
          db,
          mark: 'C',
          entityType: 'timing_record',
          entityId: '7',
          operation: 'create',
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        // Delete: backoff in the future → excluded from listPending.
        await _insertOutbox(
          db,
          mark: 'D',
          entityType: 'timing_record',
          entityId: '7',
          operation: 'delete',
          createdAt: '2026-06-01T00:00:02.000Z',
          nextRetryAt: '2099-01-01T00:00:00.000Z',
        );

        final client = _ProgrammableClient.alwaysSuccess();
        final result = await managerWith(client).pushPending();

        // R5.23 conservative semantics: fold only within the due snapshot.
        // The create pushes; the delete waits for its backoff.
        expect(client.sentMarks, <String>['C']);
        expect(result.folded, 0);
        expect(result.pushed, 1);
        // Delete row survives, still pending in the future.
        final remaining = await _rowByMark(db, 'D');
        expect(remaining, isNotNull);
        expect(remaining!['status'], 'pending');
      },
    );

    test(
      'a not-yet-due create is invisible to listPending, so the later delete '
      'pushes normally instead of waiting for a fold pair',
      () async {
        final db = await AppDatabase.database;
        await _insertOutbox(
          db,
          mark: 'C',
          entityType: 'timing_record',
          entityId: '8',
          operation: 'create',
          createdAt: '2026-06-01T00:00:01.000Z',
          nextRetryAt: '2099-01-01T00:00:00.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'D',
          entityType: 'timing_record',
          entityId: '8',
          operation: 'delete',
          createdAt: '2026-06-01T00:00:02.000Z',
        );

        final client = _ProgrammableClient.alwaysSuccess();
        final result = await managerWith(client).pushPending();

        // Only the delete is due → push it. No fold; the create stays in
        // backoff and survives this push.
        expect(client.sentMarks, <String>['D']);
        expect(result.folded, 0);
        expect(result.pushed, 1);
        final stillPending = await _rowByMark(db, 'C');
        expect(stillPending, isNotNull);
        expect(stillPending!['status'], 'pending');
      },
    );
  });

  group('sync_manager_folding_with_transaction_group', () {
    test(
      'ungrouped create + ungrouped delete fold cleanly (group invariant '
      'untouched)',
      () async {
        final db = await AppDatabase.database;
        await _insertOutbox(
          db,
          mark: 'C',
          entityType: 'external_work_record',
          entityId: 'e1',
          operation: 'create',
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'D',
          entityType: 'external_work_record',
          entityId: 'e1',
          operation: 'delete',
          createdAt: '2026-06-01T00:00:02.000Z',
        );

        final client = _ProgrammableClient.alwaysSuccess();
        final result = await managerWith(client).pushPending();

        expect(client.sentMarks, isEmpty);
        expect(result.folded, 2);
        expect(result.invalid, 0,
            reason: 'no invalid metadata: ungrouped rows have no sequence');
      },
    );

    test(
      'two single-row groups (create in group A, delete in group B) fold '
      'safely: each group disappears whole, surviving groups push without '
      'invalid-metadata',
      () async {
        final db = await AppDatabase.database;
        await _insertOutbox(
          db,
          mark: 'CA',
          entityType: 'account_payment',
          entityId: '1',
          operation: 'create',
          groupId: 'txn-A',
          seq: 1,
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'DB',
          entityType: 'account_payment',
          entityId: '1',
          operation: 'delete',
          groupId: 'txn-B',
          seq: 1,
          createdAt: '2026-06-01T00:00:02.000Z',
        );
        // Bystander entity in its own group must still push.
        await _insertOutbox(
          db,
          mark: 'X',
          entityType: 'project',
          entityId: 'p9',
          operation: 'update',
          groupId: 'txn-X',
          seq: 1,
          createdAt: '2026-06-01T00:00:03.000Z',
        );

        final client = _ProgrammableClient.alwaysSuccess();
        final result = await managerWith(client).pushPending();

        expect(client.sentMarks, <String>['X']);
        expect(result.folded, 2);
        expect(result.pushed, 1);
        expect(result.invalid, 0);

        // CA and DB are gone; X is acked and gone too.
        expect(await _outboxCount(db), 0);
      },
    );

    test(
      'mixed group (settlement cluster): folding aborts for the entity '
      'whose create+delete would gap a group; the cluster pushes intact, no '
      'invalid_metadata',
      () async {
        // Simulate a single-tx settlement cluster: payment(1) → writeOff(2) →
        // project status update(3). Then a later tx logically deletes the
        // payment as a single ungrouped row. R5.23 must NOT fold the payment
        // pair because doing so would leave group txn-S with sequence [2, 3]
        // — a 1..n gap that R5.22-B treats as invalid_metadata.
        final db = await AppDatabase.database;
        await _insertOutbox(
          db,
          mark: 'S-PAY',
          entityType: 'account_payment',
          entityId: '42',
          operation: 'create',
          groupId: 'txn-S',
          seq: 1,
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'S-WO',
          entityType: 'project_write_off',
          entityId: 'wo-7',
          operation: 'create',
          groupId: 'txn-S',
          seq: 2,
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'S-PRJ',
          entityType: 'project',
          entityId: 'p1',
          operation: 'update',
          groupId: 'txn-S',
          seq: 3,
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        // Later: a standalone payment delete for the same payment entity.
        await _insertOutbox(
          db,
          mark: 'LATER-DEL',
          entityType: 'account_payment',
          entityId: '42',
          operation: 'delete',
          createdAt: '2026-06-01T00:00:05.000Z',
        );

        final client = _ProgrammableClient.alwaysSuccess();
        final result = await managerWith(client).pushPending();

        // No fold for the payment (would gap group txn-S). Every row pushes
        // in the existing causal order; no invalid_metadata is recorded.
        expect(
          client.sentMarks,
          <String>['S-PAY', 'S-WO', 'S-PRJ', 'LATER-DEL'],
        );
        expect(result.folded, 0);
        expect(result.pushed, 4);
        expect(result.invalid, 0);
      },
    );
  });

  group('sync_manager_folding_entity_sync_meta_breadcrumb', () {
    test(
      'create+delete fold clears the outbox so meta-driven re-push cannot '
      'happen; meta row is intentionally untouched (deferred deleted-entity '
      'meta lifecycle)',
      () async {
        final db = await AppDatabase.database;
        await _insertOutbox(
          db,
          mark: 'C',
          entityType: 'account_payment',
          entityId: '101',
          operation: 'create',
          createdAt: '2026-06-01T00:00:01.000Z',
        );
        await _insertOutbox(
          db,
          mark: 'D',
          entityType: 'account_payment',
          entityId: '101',
          operation: 'delete',
          createdAt: '2026-06-01T00:00:02.000Z',
        );
        // Realistically the enqueue side leaves meta at pendingDelete after
        // the second enqueue (R5.22-B already deferred the
        // deleted-entity meta lifecycle).
        await _insertMeta(
          db,
          entityType: 'account_payment',
          localId: '101',
          status: 'pendingDelete',
        );

        final client = _ProgrammableClient.alwaysSuccess();
        final result = await managerWith(client).pushPending();
        expect(result.folded, 2);
        expect(await _outboxCount(db), 0);

        // R5.23 keeps the existing meta state — outbox absence is the
        // authoritative signal that no push is owed.
        expect(
          await _metaStatus(db, 'account_payment', '101'),
          'pendingDelete',
          reason:
              'folding does not yet clean the deleted-entity meta row; see '
              'R5.22-B deferred note. The next pushPending sees 0 outbox '
              'rows and does nothing.',
        );

        // Confirm: a second pushPending is a true no-op (no client call, no
        // re-fabrication of outbox).
        final client2 = _ProgrammableClient.alwaysSuccess();
        final result2 = await managerWith(client2).pushPending();
        expect(client2.sentMarks, isEmpty);
        expect(result2.pushed, 0);
        expect(result2.folded, 0);
      },
    );
  });
}

// ── helpers (mirror sync_manager_push_test.dart for consistency) ───────────

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

Future<Map<String, Object?>?> _rowByMark(Database db, String mark) async {
  final rows = await db.query(
    'sync_outbox',
    where: 'id = ?',
    whereArgs: ['outbox-$mark'],
  );
  return rows.isEmpty ? null : rows.single;
}

class _ProgrammableClient implements CloudApiClient {
  _ProgrammableClient._all(this._failAll);

  factory _ProgrammableClient.alwaysSuccess() =>
      _ProgrammableClient._all(false);

  final bool _failAll;

  final List<String> sentMarks = [];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final mark = (jsonDecode(request.bodyJson!) as Map)['mark'] as String;
    sentMarks.add(mark);
    if (_failAll) {
      return const ApiResponse(
        statusCode: 500,
        error: ApiError(code: 'server_error', message: 'boom', retryable: true),
      );
    }
    return const ApiResponse(statusCode: 200);
  }
}
