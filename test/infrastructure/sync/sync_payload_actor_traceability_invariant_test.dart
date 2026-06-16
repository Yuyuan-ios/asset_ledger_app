import 'dart:convert';

import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/infrastructure/local/account/account_payment_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/local/account/project_write_off_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

/// R5.25: the payload `actor` object must reflect the ActorContext used by the
/// write, carry all three keys, and never be duplicated inside `record`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
    AppDatabase.debugInitDbOverride = () {
      return openDatabase(
        inMemoryDatabasePath,
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      );
    };
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  test(
    'payload actor matches the injected ActorContext (type/id/session)',
    () async {
      final db = await AppDatabase.database;
      final actor = ActorContext(
        actorType: OperationActorType.owner,
        actorId: 'owner-123',
        sessionId: 'sess-9',
      );
      await AppDatabase.inTransaction((txn) async {
        await const AccountPaymentSyncEnqueuer().enqueue(
          txn,
          payment: const AccountPayment(
            id: 1,
            projectKey: 'k',
            ymd: 20260101,
            amount: 100,
          ),
          operation: 'create',
          status: SyncStatus.pendingUpload,
          actor: actor,
        );
      });

      final payload = await _singlePayload(db);
      expect(payload['payload_schema_version'], 1);
      expect(payload['actor'], <String, Object?>{
        'type': 'owner',
        'id': 'owner-123',
        'session_id': 'sess-9',
      });
      // actor is not duplicated inside the business record.
      final record = payload['record'] as Map<String, Object?>;
      expect(record.containsKey('actor'), isFalse);
      expect(record.containsKey('payload_schema_version'), isFalse);
      // record still carries the business fields untouched.
      expect(record['amount_fen'], 10000);
    },
  );

  test('actor session_id key is present even when null', () async {
    final db = await AppDatabase.database;
    final actor = ActorContext(
      actorType: OperationActorType.owner,
      actorId: 'owner-9',
      // sessionId omitted → null.
    );
    await AppDatabase.inTransaction((txn) async {
      await const ProjectWriteOffSyncEnqueuer().enqueueCreate(
        txn,
        ProjectWriteOff(
          id: 'wo-1',
          projectId: 'p1',
          amount: 5,
          reason: 'rounding',
          writeOffDate: '2026-01-01',
          createdAt: '2026-01-01T00:00:00.000Z',
          updatedAt: '2026-01-01T00:00:00.000Z',
        ),
        actor: actor,
      );
    });

    final actorMap =
        (await _singlePayload(db))['actor'] as Map<String, Object?>;
    expect(actorMap.containsKey('session_id'), isTrue);
    expect(actorMap['session_id'], isNull);
    expect(actorMap['id'], 'owner-9');
  });

  test(
    'no injected actor → documented owner-app fallback (owner, null id)',
    () async {
      final db = await AppDatabase.database;
      await AppDatabase.inTransaction((txn) async {
        await const AccountPaymentSyncEnqueuer().enqueue(
          txn,
          payment: const AccountPayment(
            id: 2,
            projectKey: 'k',
            ymd: 20260101,
            amount: 100,
          ),
          operation: 'create',
          status: SyncStatus.pendingUpload,
          // no actor.
        );
      });

      final actorMap =
          (await _singlePayload(db))['actor'] as Map<String, Object?>;
      expect(actorMap['type'], 'owner');
      expect(actorMap['id'], isNull);
      expect(actorMap.containsKey('session_id'), isTrue);
    },
  );
}

Future<Map<String, Object?>> _singlePayload(Database db) async {
  final rows = await db.query('sync_outbox');
  expect(rows, hasLength(1));
  return (jsonDecode(rows.single['payload_json'] as String) as Map)
      .cast<String, Object?>();
}
