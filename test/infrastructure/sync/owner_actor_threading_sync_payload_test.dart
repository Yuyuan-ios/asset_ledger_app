import 'dart:convert';

import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/infrastructure/local/account/account_payment_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/local/account/local_account_payment_write_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

/// R5.25-Hardening: when the production composition root threads a
/// SyncActorProvider into `LocalAccountPaymentWriteUseCase`, every enqueued
/// `account_payment` payload carries `actor.id = <persisted owner id>` and
/// `entity_sync_meta.updated_by` matches. The legacy/test fallback (no
/// provider) keeps `actor.id = null` so a production regression is visible.
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

  AccountPayment newPayment({String key = 'k', int ymd = 20260101}) =>
      AccountPayment(
        projectKey: key,
        ymd: ymd,
        amount: 100,
        createdAt: '2026-01-01T00:00:00.000Z',
      );

  ActorContext fixedOwner({String? sessionId}) => ActorContext(
        actorType: OperationActorType.owner,
        actorId: 'owner-123',
        sessionId: sessionId,
      );

  test(
    'production wiring threads persisted owner id into outbox payload + meta',
    () async {
      // Arrange: simulate composition root threading a persistent owner actor
      // via the SyncActorProvider seam.
      final useCase = LocalAccountPaymentWriteUseCase(
        paymentRepository: SqfliteAccountPaymentRepository(),
        actorProvider: fixedOwner,
      );

      // Act: trigger a single account_payment create.
      final id = await useCase.create(newPayment());

      // Assert: outbox payload carries the owner actor; record stays intact.
      final db = await AppDatabase.database;
      final outboxRows = await db.query('sync_outbox');
      expect(outboxRows, hasLength(1));
      final payload =
          (jsonDecode(outboxRows.single['payload_json'] as String) as Map)
              .cast<String, Object?>();
      expect(payload['payload_schema_version'], 1);
      final actor = payload['actor'] as Map<String, Object?>;
      expect(actor['type'], 'owner');
      expect(actor['id'], 'owner-123');
      expect(actor.containsKey('session_id'), isTrue,
          reason: 'session_id key must always be present even when null');
      expect(actor['session_id'], isNull);
      // record stays untouched: no version/actor leakage.
      final record = payload['record'] as Map<String, Object?>;
      expect(record.containsKey('payload_schema_version'), isFalse);
      expect(record.containsKey('actor'), isFalse);
      expect(record['amount_fen'], 10000);

      // Assert: entity_sync_meta.updated_by mirrors the same actor id.
      final metaRows = await db.query(
        'entity_sync_meta',
        where: 'entity_type = ? AND local_id = ?',
        whereArgs: [AccountPaymentSyncEnqueuer.entityType, id.toString()],
      );
      expect(metaRows, hasLength(1));
      expect(metaRows.single['updated_by'], 'owner-123');
    },
  );

  test(
    'sessionId on the threaded actor propagates into payload.actor.session_id',
    () async {
      final useCase = LocalAccountPaymentWriteUseCase(
        paymentRepository: SqfliteAccountPaymentRepository(),
        actorProvider: () => fixedOwner(sessionId: 'sess-abc'),
      );

      await useCase.create(newPayment(key: 'k2'));

      final db = await AppDatabase.database;
      final payload =
          (jsonDecode((await db.query('sync_outbox')).single['payload_json']
                  as String) as Map)
              .cast<String, Object?>();
      final actor = payload['actor'] as Map<String, Object?>;
      expect(actor['id'], 'owner-123');
      expect(actor['session_id'], 'sess-abc');
    },
  );

  test(
    'no SyncActorProvider → documented legacy fallback (owner, null id)',
    () async {
      // Legacy/test wiring without provider must keep working but leave the
      // null-id breadcrumb, so a production regression is visible at glance.
      final useCase = LocalAccountPaymentWriteUseCase(
        paymentRepository: SqfliteAccountPaymentRepository(),
      );

      final id = await useCase.create(newPayment(key: 'k3'));

      final db = await AppDatabase.database;
      final payload =
          (jsonDecode((await db.query('sync_outbox')).single['payload_json']
                  as String) as Map)
              .cast<String, Object?>();
      final actor = payload['actor'] as Map<String, Object?>;
      expect(actor['type'], 'owner');
      expect(actor['id'], isNull,
          reason:
              'Documented owner-app fallback must surface null actor.id when '
              'the composition-root provider is absent, so a production '
              'regression is detectable.');
      expect(actor.containsKey('session_id'), isTrue);

      final metaRows = await db.query(
        'entity_sync_meta',
        where: 'entity_type = ? AND local_id = ?',
        whereArgs: [AccountPaymentSyncEnqueuer.entityType, id.toString()],
      );
      expect(metaRows.single['updated_by'], isNull);
    },
  );
}
