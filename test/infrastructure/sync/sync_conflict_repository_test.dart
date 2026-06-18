import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/infrastructure/sync/remote_change.dart';
import 'package:asset_ledger/infrastructure/sync/sync_conflict_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  final fixedNow = DateTime.utc(2026, 6, 16, 8);

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

  test('insertIfAbsent stores each remote conflict once', () async {
    final repository = LocalSyncConflictRepository(now: () => fixedNow);
    final conflict = SyncConflict.fromRemoteChange(
      change: _change(serverSeq: 7),
      reason: 'remote_newer_local_dirty',
      detectedAt: fixedNow,
    );

    expect(await repository.insertIfAbsent(conflict), isTrue);
    expect(await repository.insertIfAbsent(conflict), isFalse);

    final pending = await repository.listPending();
    expect(pending, hasLength(1));
    expect(pending.single.id, 'timing_record:101:7');
    expect(pending.single.remoteServerSeq, 7);
    expect(pending.single.remoteBaseVersion, 1);
    expect(pending.single.remoteNewVersion, 2);
    expect(pending.single.remotePayloadJson, '{"record":{"id":101}}');
    expect(pending.single.remoteDeleted, isFalse);
    expect(pending.single.status, SyncConflictStatus.pending);
    expect(pending.single.toRemoteChange().serverSeq, 7);
  });

  test(
    'listPending orders by detected time then remote server sequence',
    () async {
      final repository = LocalSyncConflictRepository(now: () => fixedNow);
      await repository.insertIfAbsent(
        SyncConflict.fromRemoteChange(
          change: _change(serverSeq: 20),
          reason: 'remote_newer_local_dirty',
          detectedAt: DateTime.utc(2026, 6, 16, 9),
        ),
      );
      await repository.insertIfAbsent(
        SyncConflict.fromRemoteChange(
          change: _change(serverSeq: 8, entityId: '102'),
          reason: 'remote_newer_local_dirty',
          detectedAt: DateTime.utc(2026, 6, 16, 8),
        ),
      );

      final pending = await repository.listPending();

      expect(pending.map((conflict) => conflict.remoteServerSeq), [8, 20]);
    },
  );

  test('earliestPendingServerSeq returns the smallest pending seq', () async {
    final repository = LocalSyncConflictRepository(now: () => fixedNow);
    expect(await repository.earliestPendingServerSeq(), isNull);

    await repository.insertIfAbsent(
      SyncConflict.fromRemoteChange(
        change: _change(serverSeq: 20),
        reason: 'remote_newer_local_dirty',
        detectedAt: fixedNow,
      ),
    );
    await repository.insertIfAbsent(
      SyncConflict.fromRemoteChange(
        change: _change(serverSeq: 8, entityId: '102'),
        reason: 'remote_newer_local_dirty',
        detectedAt: fixedNow,
      ),
    );

    expect(await repository.earliestPendingServerSeq(), 8);

    // 解决最早一条后,游标应回退到下一条未决冲突。
    await repository.markResolved(
      id: 'timing_record:102:8',
      resolution: SyncConflictResolution.remote,
    );
    expect(await repository.earliestPendingServerSeq(), 20);
  });

  test('markResolved removes conflict from pending list', () async {
    final repository = LocalSyncConflictRepository(now: () => fixedNow);
    final conflict = SyncConflict.fromRemoteChange(
      change: _change(serverSeq: 7),
      reason: 'remote_newer_local_dirty',
      detectedAt: fixedNow,
    );
    await repository.insertIfAbsent(conflict);

    final updated = await repository.markResolved(
      id: conflict.id,
      resolution: SyncConflictResolution.remote,
      now: DateTime.utc(2026, 6, 16, 9),
    );

    expect(updated, 1);
    expect(await repository.listPending(), isEmpty);
    final db = await AppDatabase.database;
    final row = (await db.query('sync_conflicts')).single;
    expect(row['status'], SyncConflictStatus.resolved.name);
    expect(row['resolution'], SyncConflictResolution.remote.name);
    expect(row['resolved_at'], '2026-06-16T09:00:00.000Z');
  });
}

RemoteChange _change({required int serverSeq, String entityId = '101'}) {
  return RemoteChange(
    serverSeq: serverSeq,
    entityType: 'timing_record',
    entityId: entityId,
    baseVersion: 1,
    newVersion: 2,
    payloadJson: '{"record":{"id":101}}',
    payloadHash: 'remote-hash-$serverSeq',
    deleted: false,
  );
}
