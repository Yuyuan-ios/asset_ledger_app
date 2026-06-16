import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/infrastructure/local/account/account_payment_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/sync/entity_sync_meta.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

/// R5.25: entity_sync_meta.updated_by is written from the actor id on every
/// enqueue, last-write-wins, while the preserving upsert keeps long-lived
/// fields (server_id / version / source).
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

  AccountPayment payment() =>
      AccountPayment(id: 1, projectKey: 'k', ymd: 20260101, amount: 100);

  ActorContext owner(String id) =>
      ActorContext(actorType: OperationActorType.owner, actorId: id);

  Future<void> enqueue(String operation, SyncStatus status, ActorContext a) {
    return AppDatabase.inTransaction((txn) async {
      await const AccountPaymentSyncEnqueuer().enqueue(
        txn,
        payment: payment(),
        operation: operation,
        status: status,
        actor: a,
      );
    });
  }

  test('create/update/delete write updated_by = actor.id', () async {
    final db = await AppDatabase.database;

    await enqueue('create', SyncStatus.pendingUpload, owner('owner-A'));
    expect(await _updatedBy(db), 'owner-A');
    expect(await _syncStatus(db), SyncStatus.pendingUpload.name);

    await enqueue('update', SyncStatus.pendingUpdate, owner('owner-B'));
    expect(await _updatedBy(db), 'owner-B', reason: 'last write wins');
    expect(await _syncStatus(db), SyncStatus.pendingUpdate.name);

    await enqueue('delete', SyncStatus.pendingDelete, owner('owner-C'));
    expect(await _updatedBy(db), 'owner-C');
    expect(await _syncStatus(db), SyncStatus.pendingDelete.name);
  });

  test(
    'preserving upsert keeps server_id/version/source while setting updated_by',
    () async {
      final db = await AppDatabase.database;

      // Pre-seed a meta row as if the cloud had backfilled it.
      await const LocalEntitySyncMetaRepository().upsert(
        const EntitySyncMeta(
          entityType: AccountPaymentSyncEnqueuer.entityType,
          localId: '1',
          serverId: 'srv-1',
          syncStatus: SyncStatus.synced,
          version: 5,
          source: 'cloud',
        ),
      );

      await enqueue('update', SyncStatus.pendingUpdate, owner('owner-Z'));

      final rows = await db.query(
        'entity_sync_meta',
        where: 'entity_type = ? AND local_id = ?',
        whereArgs: [AccountPaymentSyncEnqueuer.entityType, '1'],
      );
      expect(rows, hasLength(1));
      final row = rows.single;
      // updated_by reflects the latest actor.
      expect(row['updated_by'], 'owner-Z');
      // sync_status moves to the new pending state.
      expect(row['sync_status'], SyncStatus.pendingUpdate.name);
      // Long-lived fields preserved by the merge.
      expect(row['server_id'], 'srv-1');
      expect(row['version'], 5);
      expect(row['source'], 'cloud');
    },
  );
}

Future<Object?> _updatedBy(Database db) async {
  final rows = await db.query('entity_sync_meta');
  expect(rows, hasLength(1));
  return rows.single['updated_by'];
}

Future<Object?> _syncStatus(Database db) async {
  final rows = await db.query('entity_sync_meta');
  return rows.single['sync_status'];
}
