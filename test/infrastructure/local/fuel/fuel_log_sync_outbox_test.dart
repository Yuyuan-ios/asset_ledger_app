import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/data/repositories/fuel_repository.dart';
import 'package:asset_ledger/features/fuel/state/fuel_store.dart';
import 'package:asset_ledger/infrastructure/local/fuel/fuel_log_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/local/fuel/local_fuel_log_write_use_case.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
import 'package:asset_ledger/infrastructure/sync/sync_transaction_group.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late SqfliteFuelRepository repository;
  late LocalFuelLogWriteUseCase writeUseCase;
  late FuelStore store;

  FuelLog log({
    int? id,
    int deviceId = 11,
    int date = 20260601,
    String supplier = '张三',
    double liters = 20.5,
    int costFen = 12345,
  }) {
    return FuelLog(
      id: id,
      deviceId: deviceId,
      date: date,
      supplier: supplier,
      liters: liters,
      cost: 0,
      costFen: costFen,
    );
  }

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
    repository = SqfliteFuelRepository();
    writeUseCase = LocalFuelLogWriteUseCase(fuelRepository: repository);
    store = FuelStore(repository, writeUseCase: writeUseCase);
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  test('insert writes row and enqueues fuel_log create payload', () async {
    final db = await AppDatabase.database;

    await store.insert(log());

    final businessRow = (await db.query('fuel_logs')).single;
    final id = businessRow['id'] as int;
    expect(businessRow['device_id'], 11);
    expect(businessRow['date'], 20260601);
    expect(businessRow['supplier'], '张三');
    expect(businessRow['liters'], 20.5);
    expect(businessRow['cost_fen'], 12345);

    final outbox = (await db.query('sync_outbox')).single;
    expect(outbox['entity_type'], FuelLogSyncEnqueuer.entityType);
    expect(outbox['entity_id'], id.toString());
    expect(outbox['operation'], 'create');

    final payload = _decodePayload(outbox);
    expect(payload['payload_schema_version'], 1);
    expect(payload['entity_type'], FuelLogSyncEnqueuer.entityType);
    expect(payload['entity_id'], id.toString());
    expect(payload['operation'], 'create');
    expect(payload['record'], {
      'id': id,
      'device_id': 11,
      'date': 20260601,
      'supplier': '张三',
      'liters': 20.5,
      'cost_fen': 12345,
    });
    _expectMeta(
      await _singleMeta(db),
      localId: id.toString(),
      status: SyncStatus.pendingUpload,
      payloadHash: outbox['payload_hash'] as String,
    );
  });

  test('update writes row and enqueues fuel_log update payload', () async {
    final db = await AppDatabase.database;
    final id = await repository.insert(log(costFen: 10000));
    await store.loadAll();

    await store.update(
      log(id: id, supplier: '李四', liters: 25.75, costFen: 15000),
    );

    final businessRow = (await db.query('fuel_logs')).single;
    expect(businessRow['supplier'], '李四');
    expect(businessRow['liters'], 25.75);
    expect(businessRow['cost_fen'], 15000);

    final outbox = (await db.query('sync_outbox')).single;
    expect(outbox['entity_type'], FuelLogSyncEnqueuer.entityType);
    expect(outbox['entity_id'], id.toString());
    expect(outbox['operation'], 'update');

    final payload = _decodePayload(outbox);
    expect(payload['operation'], 'update');
    expect(payload['record'], {
      'id': id,
      'device_id': 11,
      'date': 20260601,
      'supplier': '李四',
      'liters': 25.75,
      'cost_fen': 15000,
    });
    _expectMeta(
      await _singleMeta(db),
      localId: id.toString(),
      status: SyncStatus.pendingUpdate,
      payloadHash: outbox['payload_hash'] as String,
    );
  });

  test('delete removes row and enqueues fuel_log delete payload', () async {
    final db = await AppDatabase.database;
    final id = await repository.insert(log(costFen: 18000));
    await store.loadAll();

    await store.deleteById(id);

    expect(await db.query('fuel_logs'), isEmpty);
    final outbox = (await db.query('sync_outbox')).single;
    expect(outbox['entity_type'], FuelLogSyncEnqueuer.entityType);
    expect(outbox['entity_id'], id.toString());
    expect(outbox['operation'], 'delete');

    final payload = _decodePayload(outbox);
    expect(payload['operation'], 'delete');
    expect(payload['record'], {
      'id': id,
      'device_id': 11,
      'date': 20260601,
      'supplier': '张三',
      'liters': 20.5,
      'cost_fen': 18000,
    });
    _expectMeta(
      await _singleMeta(db),
      localId: id.toString(),
      status: SyncStatus.pendingDelete,
      payloadHash: outbox['payload_hash'] as String,
    );
  });

  test(
    'deleteByDeviceId enqueues one fuel_log delete per deleted row',
    () async {
      final db = await AppDatabase.database;
      final first = await repository.insert(log(date: 20260601));
      final second = await repository.insert(
        log(date: 20260602, costFen: 22000),
      );
      await repository.insert(log(deviceId: 12, date: 20260603));

      await AppDatabase.inTransaction((txn) async {
        final group = SyncTransactionGroup.create();
        final deleted = await writeUseCase.deleteByDeviceIdWithExecutor(
          txn,
          11,
          group: group,
        );
        expect(deleted, 2);
      });

      final remaining = await db.query('fuel_logs');
      expect(remaining, hasLength(1));
      expect(remaining.single['device_id'], 12);

      final outboxRows = await db.query(
        'sync_outbox',
        orderBy: 'local_sequence ASC',
      );
      expect(outboxRows, hasLength(2));
      expect(outboxRows.map((row) => row['entity_id']), [
        second.toString(),
        first.toString(),
      ]);
      expect(outboxRows.map((row) => row['operation']), ['delete', 'delete']);
      expect(outboxRows.map((row) => row['local_sequence']), [1, 2]);
      expect(
        outboxRows.map((row) => row['transaction_group_id']).toSet(),
        hasLength(1),
      );

      final metaRows = await db.query(
        'entity_sync_meta',
        orderBy: 'local_id ASC',
      );
      expect(metaRows, hasLength(2));
      expect(metaRows.map((row) => row['local_id']), [
        first.toString(),
        second.toString(),
      ]);
      expect(metaRows.map((row) => row['sync_status']).toSet(), {
        SyncStatus.pendingDelete.name,
      });
    },
  );
}

Map<String, Object?> _decodePayload(Map<String, Object?> row) {
  return (jsonDecode(row['payload_json'] as String) as Map)
      .cast<String, Object?>();
}

Future<Map<String, Object?>> _singleMeta(Database db) async {
  return (await db.query('entity_sync_meta')).single;
}

void _expectMeta(
  Map<String, Object?> meta, {
  required String localId,
  required SyncStatus status,
  required String payloadHash,
}) {
  expect(meta['entity_type'], FuelLogSyncEnqueuer.entityType);
  expect(meta['local_id'], localId);
  expect(meta['sync_status'], status.name);
  expect(meta['version'], 0);
  expect(meta['source'], FuelLogSyncEnqueuer.ownerAppSource);
  expect(meta['payload_hash'], payloadHash);
}
