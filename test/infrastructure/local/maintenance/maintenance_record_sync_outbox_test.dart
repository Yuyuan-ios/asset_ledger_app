import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/maintenance_record.dart';
import 'package:asset_ledger/data/repositories/maintenance_repository.dart';
import 'package:asset_ledger/features/maintenance/state/maintenance_store.dart';
import 'package:asset_ledger/infrastructure/local/maintenance/local_maintenance_record_write_use_case.dart';
import 'package:asset_ledger/infrastructure/local/maintenance/maintenance_record_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
import 'package:asset_ledger/infrastructure/sync/sync_transaction_group.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late SqfliteMaintenanceRepository repository;
  late LocalMaintenanceRecordWriteUseCase writeUseCase;
  late MaintenanceStore store;

  MaintenanceRecord record({
    int? id,
    int? deviceId,
    int ymd = 20260601,
    String item = '保养',
    int amountFen = 50000,
    String? note = '例行',
  }) {
    return MaintenanceRecord(
      id: id,
      deviceId: deviceId,
      ymd: ymd,
      item: item,
      amount: 0,
      amountFen: amountFen,
      note: note,
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
    repository = SqfliteMaintenanceRepository();
    writeUseCase = LocalMaintenanceRecordWriteUseCase(
      maintenanceRepository: repository,
    );
    store = MaintenanceStore(repository, writeUseCase: writeUseCase);
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  test(
    'insert writes public row and enqueues maintenance_record create payload',
    () async {
      final db = await AppDatabase.database;

      await store.save(record(deviceId: null, note: null));

      final businessRow = (await db.query('maintenance_records')).single;
      final id = businessRow['id'] as int;
      expect(businessRow['device_id'], isNull);
      expect(businessRow['ymd'], 20260601);
      expect(businessRow['item'], '保养');
      expect(businessRow['amount_fen'], 50000);
      expect(businessRow['note'], isNull);

      final outbox = (await db.query('sync_outbox')).single;
      expect(outbox['entity_type'], MaintenanceRecordSyncEnqueuer.entityType);
      expect(outbox['entity_id'], id.toString());
      expect(outbox['operation'], 'create');

      final payload = _decodePayload(outbox);
      expect(payload['payload_schema_version'], 1);
      expect(payload['entity_type'], MaintenanceRecordSyncEnqueuer.entityType);
      expect(payload['entity_id'], id.toString());
      expect(payload['operation'], 'create');
      expect(payload['record'], {
        'id': id,
        'device_id': null,
        'ymd': 20260601,
        'item': '保养',
        'amount_fen': 50000,
        'note': null,
      });
      _expectMeta(
        await _singleMeta(db),
        localId: id.toString(),
        status: SyncStatus.pendingUpload,
        payloadHash: outbox['payload_hash'] as String,
      );
    },
  );

  test(
    'update writes row and enqueues maintenance_record update payload',
    () async {
      final db = await AppDatabase.database;
      final id = await repository.insert(
        record(deviceId: 11, amountFen: 40000),
      );
      await store.loadAll();

      await store.save(
        record(id: id, deviceId: 11, item: '年检', amountFen: 65000, note: '补检'),
      );

      final businessRow = (await db.query('maintenance_records')).single;
      expect(businessRow['device_id'], 11);
      expect(businessRow['item'], '年检');
      expect(businessRow['amount_fen'], 65000);
      expect(businessRow['note'], '补检');

      final outbox = (await db.query('sync_outbox')).single;
      expect(outbox['entity_type'], MaintenanceRecordSyncEnqueuer.entityType);
      expect(outbox['entity_id'], id.toString());
      expect(outbox['operation'], 'update');

      final payload = _decodePayload(outbox);
      expect(payload['operation'], 'update');
      expect(payload['record'], {
        'id': id,
        'device_id': 11,
        'ymd': 20260601,
        'item': '年检',
        'amount_fen': 65000,
        'note': '补检',
      });
      _expectMeta(
        await _singleMeta(db),
        localId: id.toString(),
        status: SyncStatus.pendingUpdate,
        payloadHash: outbox['payload_hash'] as String,
      );
    },
  );

  test(
    'delete removes public row and enqueues maintenance_record delete payload',
    () async {
      final db = await AppDatabase.database;
      final id = await repository.insert(record(deviceId: null, note: null));
      await store.loadAll();

      await store.deleteById(id);

      expect(await db.query('maintenance_records'), isEmpty);
      final outbox = (await db.query('sync_outbox')).single;
      expect(outbox['entity_type'], MaintenanceRecordSyncEnqueuer.entityType);
      expect(outbox['entity_id'], id.toString());
      expect(outbox['operation'], 'delete');

      final payload = _decodePayload(outbox);
      expect(payload['operation'], 'delete');
      expect(payload['record'], {
        'id': id,
        'device_id': null,
        'ymd': 20260601,
        'item': '保养',
        'amount_fen': 50000,
        'note': null,
      });
      _expectMeta(
        await _singleMeta(db),
        localId: id.toString(),
        status: SyncStatus.pendingDelete,
        payloadHash: outbox['payload_hash'] as String,
      );
    },
  );

  test(
    'deleteByDeviceId enqueues one maintenance_record delete per deleted row',
    () async {
      final db = await AppDatabase.database;
      final first = await repository.insert(
        record(deviceId: 11, ymd: 20260601),
      );
      final second = await repository.insert(
        record(deviceId: 11, ymd: 20260602, amountFen: 66000),
      );
      await repository.insert(record(deviceId: null, ymd: 20260603));

      await AppDatabase.inTransaction((txn) async {
        final group = SyncTransactionGroup.create();
        final deleted = await writeUseCase.deleteByDeviceIdWithExecutor(
          txn,
          11,
          group: group,
        );
        expect(deleted, 2);
      });

      final remaining = await db.query('maintenance_records');
      expect(remaining, hasLength(1));
      expect(remaining.single['device_id'], isNull);

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
  expect(meta['entity_type'], MaintenanceRecordSyncEnqueuer.entityType);
  expect(meta['local_id'], localId);
  expect(meta['sync_status'], status.name);
  expect(meta['version'], 0);
  expect(meta['source'], MaintenanceRecordSyncEnqueuer.ownerAppSource);
  expect(meta['payload_hash'], payloadHash);
}
