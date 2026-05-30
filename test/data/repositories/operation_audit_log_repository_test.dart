import 'package:asset_ledger/core/operations/operation_models.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/operation_audit_log.dart';
import 'package:asset_ledger/data/repositories/operation_audit_log_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late SqfliteOperationAuditLogRepository repository;

  setUp(() async {
    await AppDatabase.resetForTest();
    await _openCurrentInMemoryDb();
    repository = SqfliteOperationAuditLogRepository();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  test('insert + findById round-trips a log', () async {
    final log = _log(id: 'audit-1', operationId: 'op-1');
    await repository.insert(log);

    final found = await repository.findById('audit-1');
    expect(found, isNotNull);
    expect(found!.id, 'audit-1');
    expect(found.operationId, 'op-1');
    expect(found.actorType, OperationAuditActorType.owner);
    expect(found.confirmed, isTrue);
    expect(found.result, OperationAuditResult.success);
  });

  test('findById returns null when not present', () async {
    expect(await repository.findById('missing'), isNull);
  });

  test('findById rejects empty id', () async {
    expect(() => repository.findById('   '), throwsArgumentError);
  });

  test('listByOperationId returns logs in created_at ASC order', () async {
    await repository.insert(_log(
      id: 'a-c',
      operationId: 'op-1',
      createdAt: DateTime.utc(2026, 6, 1, 12, 0, 2),
    ));
    await repository.insert(_log(
      id: 'a-a',
      operationId: 'op-1',
      createdAt: DateTime.utc(2026, 6, 1, 12, 0, 0),
    ));
    await repository.insert(_log(
      id: 'a-b',
      operationId: 'op-1',
      createdAt: DateTime.utc(2026, 6, 1, 12, 0, 1),
    ));
    await repository.insert(_log(id: 'a-other', operationId: 'op-2'));

    final rows = await repository.listByOperationId('op-1');
    expect(rows.map((r) => r.id).toList(), ['a-a', 'a-b', 'a-c']);
  });

  test('listRecent orders by created_at DESC and respects limit', () async {
    await repository.insert(_log(
      id: '1',
      operationId: 'op-1',
      createdAt: DateTime.utc(2026, 6, 1, 0, 0, 0),
    ));
    await repository.insert(_log(
      id: '2',
      operationId: 'op-2',
      createdAt: DateTime.utc(2026, 6, 1, 0, 0, 1),
    ));
    await repository.insert(_log(
      id: '3',
      operationId: 'op-3',
      createdAt: DateTime.utc(2026, 6, 1, 0, 0, 2),
    ));

    final recent = await repository.listRecent(limit: 2);
    expect(recent.map((r) => r.id).toList(), ['3', '2']);

    expect(await repository.listRecent(limit: 0), isEmpty);
    expect(await repository.listRecent(limit: -1), isEmpty);
  });

  test('duplicate id is aborted (no silent replace)', () async {
    await repository.insert(_log(id: 'dup', operationId: 'op-1'));
    expect(
      () => repository.insert(_log(
        id: 'dup',
        operationId: 'op-1',
        // 不同字段也不应覆盖。
        confirmed: false,
        result: OperationAuditResult.failure,
        errorMessage: '冲突',
      )),
      throwsA(isA<DatabaseException>()),
    );

    final found = await repository.findById('dup');
    expect(found!.confirmed, isTrue);
    expect(found.result, OperationAuditResult.success);
  });

  test('insertWithExecutor commits when transaction succeeds', () async {
    final db = await AppDatabase.database;
    await db.transaction((txn) async {
      await repository.insertWithExecutor(
        txn,
        _log(id: 'txn-ok', operationId: 'op-1'),
      );
    });

    expect(await repository.findById('txn-ok'), isNotNull);
  });

  test('insertWithExecutor rolls back with the transaction', () async {
    final db = await AppDatabase.database;
    Object? thrown;
    try {
      await db.transaction((txn) async {
        await repository.insertWithExecutor(
          txn,
          _log(id: 'txn-rollback', operationId: 'op-1'),
        );
        throw StateError('boom');
      });
    } catch (e) {
      thrown = e;
    }
    expect(thrown, isA<StateError>());

    // 业务回滚后审计也必须随之回滚。
    expect(await repository.findById('txn-rollback'), isNull);
  });

}

Future<Database> _openCurrentInMemoryDb() {
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
  return AppDatabase.database;
}

OperationAuditLog _log({
  required String id,
  required String operationId,
  bool confirmed = true,
  OperationAuditResult result = OperationAuditResult.success,
  String? errorMessage,
  DateTime? createdAt,
}) {
  return OperationAuditLog(
    id: id,
    operationId: operationId,
    operationType: OperationType.saveTimingRecord,
    actorType: OperationAuditActorType.owner,
    source: OperationAuditSource.app,
    createdAt: createdAt ?? DateTime.utc(2026, 6, 1, 12, 0, 0),
    entityRefs: const [
      OperationEntityRef(entityType: 'timing_record', entityId: 't-1'),
    ],
    confirmed: confirmed,
    result: result,
    errorMessage: errorMessage,
  );
}
