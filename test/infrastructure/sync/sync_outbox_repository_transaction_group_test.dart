import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
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

  test(
    'enqueue without group/sequence stores NULL transaction_group_id and '
    'local_sequence (ordinary single-row enqueue is unchanged)',
    () async {
      const outbox = LocalSyncOutboxRepository();
      final entry = await outbox.enqueue(
        entityType: 'timing_record',
        entityId: '1',
        operation: 'create',
        payload: const {'id': 1},
      );

      expect(entry.transactionGroupId, isNull);
      expect(entry.localSequence, isNull);

      final db = await AppDatabase.database;
      final rows = await db.query('sync_outbox');
      expect(rows, hasLength(1));
      expect(rows.single['transaction_group_id'], isNull);
      expect(rows.single['local_sequence'], isNull);

      // listPending round-trips NULL metadata.
      final pending = await outbox.listPending();
      expect(pending.single.transactionGroupId, isNull);
      expect(pending.single.localSequence, isNull);
    },
  );

  test(
    'enqueue with explicit transactionGroupId/localSequence is read back by '
    'listPending and persisted to the row',
    () async {
      const outbox = LocalSyncOutboxRepository();
      await outbox.enqueue(
        entityType: 'account_payment',
        entityId: '10',
        operation: 'create',
        payload: const {'id': 10},
        transactionGroupId: 'txn-abc',
        localSequence: 1,
      );
      await outbox.enqueue(
        entityType: 'project',
        entityId: 'project:1',
        operation: 'update',
        payload: const {'id': 'project:1'},
        transactionGroupId: 'txn-abc',
        localSequence: 2,
      );

      final pending = await outbox.listPending();
      expect(pending, hasLength(2));
      for (final entry in pending) {
        expect(entry.transactionGroupId, 'txn-abc');
      }
      final sequences = pending.map((e) => e.localSequence).toList()..sort();
      expect(sequences, <int>[1, 2]);

      // Metadata is NOT folded into the business payload.
      for (final entry in pending) {
        expect(entry.payloadJson.contains('transaction_group_id'), isFalse);
        expect(entry.payloadJson.contains('local_sequence'), isFalse);
      }
    },
  );

  test('enqueueWithExecutor threads group/sequence inside a transaction', () async {
    final db = await AppDatabase.database;
    const outbox = LocalSyncOutboxRepository();

    await AppDatabase.inTransaction((txn) async {
      await outbox.enqueueWithExecutor(
        txn,
        entityType: 'external_work_record',
        entityId: 'ew-1',
        operation: 'create',
        payload: const {'id': 'ew-1'},
        transactionGroupId: 'txn-xyz',
        localSequence: 1,
      );
    });

    final rows = await db.query('sync_outbox');
    expect(rows, hasLength(1));
    expect(rows.single['transaction_group_id'], 'txn-xyz');
    expect(rows.single['local_sequence'], 1);
  });
}
