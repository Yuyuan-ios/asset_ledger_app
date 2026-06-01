import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/core/operations/operation_confirmation_token.dart';
import 'package:asset_ledger/core/operations/operation_models.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/operation_token_record.dart';
import 'package:asset_ledger/data/repositories/operation_token_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

final _createdAt = DateTime.utc(2026, 6, 1, 12, 0, 0);
final _expiresAt = DateTime.utc(2026, 6, 1, 12, 30, 0);
final _now = DateTime.utc(2026, 6, 1, 12, 10, 0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late SqfliteOperationTokenRepository repository;

  setUp(() async {
    await AppDatabase.resetForTest();
    await _openCurrentInMemoryDb();
    repository = SqfliteOperationTokenRepository();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  test('insert + findById round-trips a token record', () async {
    await repository.insert(_record(id: 'tok-1', operationId: 'op-1'));
    final found = await repository.findById('tok-1');
    expect(found, isNotNull);
    expect(found!.id, 'tok-1');
    expect(found.operationId, 'op-1');
    expect(found.status, OperationConfirmationTokenStatus.issued);
  });

  test('findById returns null when missing; rejects empty id', () async {
    expect(await repository.findById('missing'), isNull);
    expect(() => repository.findById('  '), throwsArgumentError);
  });

  test('duplicate id is aborted and keeps the original row', () async {
    await repository.insert(_record(id: 'dup', operationId: 'op-a'));
    await expectLater(
      repository.insert(_record(id: 'dup', operationId: 'op-b')),
      throwsA(isA<DatabaseException>()),
    );
    final found = await repository.findById('dup');
    expect(found!.operationId, 'op-a');
  });

  test('listByOperationId returns records in created_at ASC order', () async {
    await repository.insert(_record(
      id: 't-late',
      operationId: 'op-x',
      createdAt: DateTime.utc(2026, 6, 1, 12, 0, 2),
      expiresAt: DateTime.utc(2026, 6, 1, 13, 0, 0),
    ));
    await repository.insert(_record(
      id: 't-early',
      operationId: 'op-x',
      createdAt: DateTime.utc(2026, 6, 1, 12, 0, 0),
      expiresAt: DateTime.utc(2026, 6, 1, 13, 0, 0),
    ));
    final list = await repository.listByOperationId('op-x');
    expect(list.map((r) => r.id).toList(), ['t-early', 't-late']);
  });

  group('listActiveByActorSession', () {
    setUp(() async {
      await repository.insert(_record(id: 'owner-active')); // owner, null actor/session, issued
      await repository.insert(_record(
        id: 'owner-with-actor',
        actorType: OperationActorType.owner,
        actorId: 'owner-7',
      ));
      await repository.insert(_record(
        id: 'driver-active',
        actorType: OperationActorType.driver,
        actorId: 'driver-1',
        sessionId: 'sess-1',
      ));
      await repository.insert(_record(
        id: 'owner-expired',
        createdAt: DateTime.utc(2026, 6, 1, 11, 0, 0),
        expiresAt: DateTime.utc(2026, 6, 1, 11, 30, 0), // before _now
      ));
      // a consumed owner token
      final consumed = _record(id: 'owner-consumed').asConsumed(_now);
      await repository.insert(consumed);
    });

    test('returns only issued, unexpired, matching owner-null-session tokens', () async {
      final active = await repository.listActiveByActorSession(
        actorType: OperationActorType.owner,
        actorId: null,
        sessionId: null,
        now: _now,
      );
      expect(active.map((r) => r.id).toList(), ['owner-active']);
    });

    test('matches driver actor + session exactly', () async {
      final active = await repository.listActiveByActorSession(
        actorType: OperationActorType.driver,
        actorId: 'driver-1',
        sessionId: 'sess-1',
        now: _now,
      );
      expect(active.map((r) => r.id).toList(), ['driver-active']);
    });

    test('limit <= 0 returns empty', () async {
      final active = await repository.listActiveByActorSession(
        actorType: OperationActorType.owner,
        now: _now,
        limit: 0,
      );
      expect(active, isEmpty);
    });
  });

  group('claimForConsume', () {
    test('issued + unexpired claims successfully and marks consumed', () async {
      await repository.insert(_record(id: 'c-1'));
      final ok = await repository.claimForConsume(id: 'c-1', now: _now);
      expect(ok, isTrue);
      final after = await repository.findById('c-1');
      expect(after!.status, OperationConfirmationTokenStatus.consumed);
      expect(after.consumedAt, isNotNull);
    });

    test('second claim returns false (no double consume)', () async {
      await repository.insert(_record(id: 'c-2'));
      expect(await repository.claimForConsume(id: 'c-2', now: _now), isTrue);
      expect(await repository.claimForConsume(id: 'c-2', now: _now), isFalse);
      final after = await repository.findById('c-2');
      expect(after!.status, OperationConfirmationTokenStatus.consumed);
    });

    test('expired token cannot be claimed', () async {
      await repository.insert(_record(
        id: 'c-exp',
        createdAt: DateTime.utc(2026, 6, 1, 11, 0, 0),
        expiresAt: DateTime.utc(2026, 6, 1, 11, 30, 0),
      ));
      final ok = await repository.claimForConsume(id: 'c-exp', now: _now);
      expect(ok, isFalse);
      final after = await repository.findById('c-exp');
      expect(after!.status, OperationConfirmationTokenStatus.issued);
    });

    test('cancelled token cannot be claimed', () async {
      await repository.insert(_record(id: 'c-cancel'));
      await repository.markCancelled(id: 'c-cancel', cancelledAt: _now);
      expect(await repository.claimForConsume(id: 'c-cancel', now: _now), isFalse);
    });

    test('claimForConsumeWithExecutor rolls back with the transaction', () async {
      await repository.insert(_record(id: 'c-rollback'));
      final db = await AppDatabase.database;
      await expectLater(
        db.transaction((txn) async {
          final ok = await repository.claimForConsumeWithExecutor(
            txn,
            id: 'c-rollback',
            now: _now,
          );
          expect(ok, isTrue);
          throw StateError('boom'); // force rollback
        }),
        throwsA(isA<StateError>()),
      );
      final after = await repository.findById('c-rollback');
      expect(after!.status, OperationConfirmationTokenStatus.issued);
      expect(after.consumedAt, isNull);
    });

    test('claimForConsumeWithExecutor commits inside a successful transaction', () async {
      await repository.insert(_record(id: 'c-commit'));
      final db = await AppDatabase.database;
      final ok = await db.transaction((txn) {
        return repository.claimForConsumeWithExecutor(
          txn,
          id: 'c-commit',
          now: _now,
        );
      });
      expect(ok, isTrue);
      final after = await repository.findById('c-commit');
      expect(after!.status, OperationConfirmationTokenStatus.consumed);
    });
  });

  group('markCancelled', () {
    test('issued -> cancelled succeeds', () async {
      await repository.insert(_record(id: 'mc-1'));
      final ok = await repository.markCancelled(
        id: 'mc-1',
        cancelledAt: _now,
        reason: 'user_cancelled',
      );
      expect(ok, isTrue);
      final after = await repository.findById('mc-1');
      expect(after!.status, OperationConfirmationTokenStatus.cancelled);
      expect(after.cancelledAt, isNotNull);
      expect(after.lastError, 'user_cancelled');
    });

    test('consumed token cannot be cancelled', () async {
      await repository.insert(_record(id: 'mc-2'));
      await repository.claimForConsume(id: 'mc-2', now: _now);
      final ok = await repository.markCancelled(id: 'mc-2', cancelledAt: _now);
      expect(ok, isFalse);
      final after = await repository.findById('mc-2');
      expect(after!.status, OperationConfirmationTokenStatus.consumed);
    });
  });

  group('markExpiredBefore', () {
    test('only issued tokens with expires_at <= now become expired', () async {
      await repository.insert(_record(
        id: 'e-old',
        createdAt: DateTime.utc(2026, 6, 1, 11, 0, 0),
        expiresAt: DateTime.utc(2026, 6, 1, 11, 30, 0), // <= now
      ));
      await repository.insert(_record(id: 'e-future')); // expires 12:30 > now
      await repository.insert(_record(id: 'e-consumed'));
      await repository.claimForConsume(id: 'e-consumed', now: _now);

      final count = await repository.markExpiredBefore(_now);
      expect(count, 1);
      expect((await repository.findById('e-old'))!.status,
          OperationConfirmationTokenStatus.expired);
      expect((await repository.findById('e-future'))!.status,
          OperationConfirmationTokenStatus.issued);
      expect((await repository.findById('e-consumed'))!.status,
          OperationConfirmationTokenStatus.consumed);
    });
  });
}

OperationTokenRecord _record({
  required String id,
  String operationId = 'op-1',
  OperationActorType actorType = OperationActorType.owner,
  String? actorId,
  String? sessionId,
  DateTime? createdAt,
  DateTime? expiresAt,
}) {
  return OperationTokenRecord(
    token: OperationConfirmationToken(
      tokenId: id,
      operationId: operationId,
      operationType: OperationType.saveTimingRecord,
      actorType: actorType,
      actorId: actorId,
      sessionId: sessionId,
      createdAt: createdAt ?? _createdAt,
      expiresAt: expiresAt ?? _expiresAt,
      inputHash: 'h-input',
      fullAnalysisHash: 'h-full',
      actorScopeHash: 'h-scope',
    ),
  );
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
