import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/repositories/project_write_off_repository.dart';
import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/features/account/use_cases/project_settlement_use_case.dart';
import 'package:asset_ledger/features/account/use_cases/settle_merged_project_use_case.dart';
import 'package:asset_ledger/infrastructure/local/account/account_payment_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/local/account/local_project_settlement_repository.dart';
import 'package:asset_ledger/infrastructure/local/account/project_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/local/account/project_write_off_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/sync/entity_sync_meta.dart';
import 'package:asset_ledger/infrastructure/sync/sync_outbox_entry.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  group('ProjectSettlementUseCase', () {
    test('settles a project with a full cash payment', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db);
      await _seedPayment(db, amount: 500);
      final useCase = _useCase();

      final result = await useCase.execute(
        projectId: 'project:1',
        projectKey: '甲方||一号工地',
        receivable: 2600,
        paymentAmount: 2100,
        writeOffAmount: 0,
        writeOffReason: null,
        ymd: 20260518,
      );

      expect(result.settled, isTrue);
      expect(result.receivedAfter, 2600);
      expect(result.writeOffAfter, 0);
      expect(result.remainingAfter, 0);
      expect(await _paymentCount(db), 2);
      expect(await _paymentSum(db), 2600);
      expect(await _writeOffCount(db), 0);
      expect(await _projectStatus(db), ProjectStatus.settled);

      final paymentOutbox = await _singleOutbox(
        db,
        entityType: 'account_payment',
        operation: 'create',
      );
      final projectOutbox = await _singleOutbox(
        db,
        entityType: ProjectSyncEnqueuer.entityType,
        operation: 'update',
      );
      expect(
        await _outboxRows(
          db,
          entityType: ProjectWriteOffSyncEnqueuer.entityType,
        ),
        isEmpty,
      );
      await _expectMetaMatchesOutbox(
        db,
        paymentOutbox,
        SyncStatus.pendingUpload,
      );
      await _expectMetaMatchesOutbox(
        db,
        projectOutbox,
        SyncStatus.pendingUpdate,
      );
      final projectRecord = _payloadRecord(projectOutbox);
      expect(projectRecord['id'], 'project:1');
      expect(projectRecord['status'], ProjectStatus.settled.name);
      expect(projectRecord['settled_at'], '2026-05-18T01:02:03.000Z');
      expect(projectRecord.containsKey('settled_snapshot'), isTrue);
    });

    test(
      'settles a project with write-off only without increasing received',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProject(db);
        await _seedPayment(db, amount: 1200);
        final useCase = _useCase();

        final result = await useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 1260,
          paymentAmount: 0,
          writeOffAmount: 60,
          writeOffReason: ProjectWriteOffReason.rounding,
          ymd: 20260518,
          note: '尾款抹零',
        );

        expect(result.receivable, 1260);
        expect(result.receivedAfter, 1200);
        expect(result.writeOffAfter, 60);
        expect(result.remainingAfter, 0);
        expect(await _paymentCount(db), 1);
        expect(await _paymentSum(db), 1200);
        final writeOffs = await _writeOffRows(db);
        expect(writeOffs, hasLength(1));
        expect(writeOffs.single.amount, 60);
        expect(writeOffs.single.reason, ProjectWriteOffReason.rounding.dbValue);
        expect(writeOffs.single.note, '尾款抹零');
        expect(await _projectStatus(db), ProjectStatus.settled);

        expect(await _outboxRows(db, entityType: 'account_payment'), isEmpty);
        final writeOffOutbox = await _singleOutbox(
          db,
          entityType: ProjectWriteOffSyncEnqueuer.entityType,
          operation: 'create',
        );
        final projectOutbox = await _singleOutbox(
          db,
          entityType: ProjectSyncEnqueuer.entityType,
          operation: 'update',
        );
        await _expectMetaMatchesOutbox(
          db,
          writeOffOutbox,
          SyncStatus.pendingUpload,
        );
        await _expectMetaMatchesOutbox(
          db,
          projectOutbox,
          SyncStatus.pendingUpdate,
        );
        final writeOffRecord = _payloadRecord(writeOffOutbox);
        expect(writeOffRecord['id'], 'write-off-1');
        expect(writeOffRecord['project_id'], 'project:1');
        expect(writeOffRecord['amount_fen'], 6000);
        expect(
          writeOffRecord['reason'],
          ProjectWriteOffReason.rounding.dbValue,
        );
      },
    );

    test('settles a project with payment plus write-off', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db);
      await _seedPayment(db, amount: 5000);
      final useCase = _useCase();

      final result = await useCase.execute(
        projectId: 'project:1',
        projectKey: '甲方||一号工地',
        receivable: 20000,
        paymentAmount: 5000,
        writeOffAmount: 10000,
        writeOffReason: ProjectWriteOffReason.settlement,
        ymd: 20260518,
      );

      expect(result.receivedAfter, 10000);
      expect(result.writeOffAfter, 10000);
      expect(result.remainingAfter, 0);
      expect(await _paymentCount(db), 2);
      expect(await _paymentSum(db), 10000);
      expect(await _writeOffCount(db), 1);
      expect(await _writeOffSum(db), 10000);
      expect(await _projectStatus(db), ProjectStatus.settled);

      final outboxRows = await db.query('sync_outbox');
      expect(outboxRows, hasLength(3));
      final paymentOutbox = await _singleOutbox(
        db,
        entityType: 'account_payment',
        operation: 'create',
      );
      final paymentId = result.paymentId;
      expect(paymentOutbox['status'], SyncOutboxStatus.pending.name);
      expect(paymentOutbox['entity_id'], paymentId.toString());
      final payload = _payload(paymentOutbox);
      expect(payload['entity_type'], 'account_payment');
      expect(payload['entity_id'], paymentId.toString());
      expect(payload['operation'], 'create');
      final record = payload['record'] as Map<String, Object?>;
      expect(record['id'], paymentId);
      expect(record['project_id'], 'project:1');
      expect(record['amount_fen'], 500000);
      expect(record['source_type'], AccountPayment.sourceTypeManual);

      final writeOffOutbox = await _singleOutbox(
        db,
        entityType: ProjectWriteOffSyncEnqueuer.entityType,
        operation: 'create',
      );
      final writeOffRecord = _payloadRecord(writeOffOutbox);
      expect(writeOffRecord['id'], 'write-off-1');
      expect(writeOffRecord['project_id'], 'project:1');
      expect(writeOffRecord['amount_fen'], 1000000);
      expect(
        writeOffRecord['reason'],
        ProjectWriteOffReason.settlement.dbValue,
      );
      expect(writeOffRecord['write_off_date'], '2026-05-18');

      final projectOutbox = await _singleOutbox(
        db,
        entityType: ProjectSyncEnqueuer.entityType,
        operation: 'update',
      );
      final projectRecord = _payloadRecord(projectOutbox);
      expect(projectRecord['id'], 'project:1');
      expect(projectRecord['status'], ProjectStatus.settled.name);
      expect(projectRecord['settled_at'], '2026-05-18T01:02:03.000Z');
      expect(projectRecord.containsKey('settled_snapshot'), isTrue);

      final metaRows = await db.query('entity_sync_meta');
      expect(metaRows, hasLength(3));
      await _expectMetaMatchesOutbox(
        db,
        paymentOutbox,
        SyncStatus.pendingUpload,
      );
      await _expectMetaMatchesOutbox(
        db,
        writeOffOutbox,
        SyncStatus.pendingUpload,
      );
      await _expectMetaMatchesOutbox(
        db,
        projectOutbox,
        SyncStatus.pendingUpdate,
      );
      expect(
        (await _outboxRows(
          db,
          entityType: ProjectWriteOffSyncEnqueuer.entityType,
          operation: 'delete',
        )),
        isEmpty,
      );
    });

    test(
      'outbox write failure rolls back settlement payment and write-off',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProject(db);
        await _seedPayment(db, amount: 5000);
        final useCase = _useCase(
          repository: LocalProjectSettlementRepository(
            accountPaymentSyncEnqueuer: AccountPaymentSyncEnqueuer(
              syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
            ),
          ),
        );

        await expectLater(
          useCase.execute(
            projectId: 'project:1',
            projectKey: '甲方||一号工地',
            receivable: 20000,
            paymentAmount: 5000,
            writeOffAmount: 10000,
            writeOffReason: ProjectWriteOffReason.settlement,
            ymd: 20260518,
          ),
          throwsA(isA<StateError>()),
        );

        expect(await _paymentCount(db), 1);
        expect(await _paymentSum(db), 5000);
        expect(await _writeOffCount(db), 0);
        expect(await _projectStatus(db), ProjectStatus.active);
        expect(await db.query('sync_outbox'), isEmpty);
        expect(await db.query('entity_sync_meta'), isEmpty);
      },
    );

    test('meta write failure rolls back settlement and outbox row', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db);
      await _seedPayment(db, amount: 5000);
      final useCase = _useCase(
        repository: LocalProjectSettlementRepository(
          accountPaymentSyncEnqueuer: AccountPaymentSyncEnqueuer(
            entitySyncMetaRepository: const _ThrowingEntitySyncMetaRepository(),
          ),
        ),
      );

      await expectLater(
        useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 20000,
          paymentAmount: 5000,
          writeOffAmount: 10000,
          writeOffReason: ProjectWriteOffReason.settlement,
          ymd: 20260518,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _paymentCount(db), 1);
      expect(await _paymentSum(db), 5000);
      expect(await _writeOffCount(db), 0);
      expect(await _projectStatus(db), ProjectStatus.active);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    });

    test(
      'project write-off outbox failure rolls back settlement cluster',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProject(db);
        await _seedPayment(db, amount: 5000);
        final useCase = _useCase(
          repository: LocalProjectSettlementRepository(
            projectWriteOffSyncEnqueuer: ProjectWriteOffSyncEnqueuer(
              syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
            ),
          ),
        );

        await expectLater(
          useCase.execute(
            projectId: 'project:1',
            projectKey: '甲方||一号工地',
            receivable: 20000,
            paymentAmount: 5000,
            writeOffAmount: 10000,
            writeOffReason: ProjectWriteOffReason.settlement,
            ymd: 20260518,
          ),
          throwsA(isA<StateError>()),
        );

        expect(await _paymentCount(db), 1);
        expect(await _paymentSum(db), 5000);
        expect(await _writeOffCount(db), 0);
        expect(await _projectStatus(db), ProjectStatus.active);
        expect(await db.query('sync_outbox'), isEmpty);
        expect(await db.query('entity_sync_meta'), isEmpty);
      },
    );

    test(
      'project write-off meta failure rolls back settlement cluster',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProject(db);
        await _seedPayment(db, amount: 5000);
        final useCase = _useCase(
          repository: LocalProjectSettlementRepository(
            projectWriteOffSyncEnqueuer: ProjectWriteOffSyncEnqueuer(
              entitySyncMetaRepository:
                  const _ThrowingEntitySyncMetaRepository(),
            ),
          ),
        );

        await expectLater(
          useCase.execute(
            projectId: 'project:1',
            projectKey: '甲方||一号工地',
            receivable: 20000,
            paymentAmount: 5000,
            writeOffAmount: 10000,
            writeOffReason: ProjectWriteOffReason.settlement,
            ymd: 20260518,
          ),
          throwsA(isA<StateError>()),
        );

        expect(await _paymentCount(db), 1);
        expect(await _paymentSum(db), 5000);
        expect(await _writeOffCount(db), 0);
        expect(await _projectStatus(db), ProjectStatus.active);
        expect(await db.query('sync_outbox'), isEmpty);
        expect(await db.query('entity_sync_meta'), isEmpty);
      },
    );

    test(
      'project update outbox failure rolls back settlement cluster',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProject(db);
        await _seedPayment(db, amount: 5000);
        final useCase = _useCase(
          repository: LocalProjectSettlementRepository(
            projectSyncEnqueuer: ProjectSyncEnqueuer(
              syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
            ),
          ),
        );

        await expectLater(
          useCase.execute(
            projectId: 'project:1',
            projectKey: '甲方||一号工地',
            receivable: 20000,
            paymentAmount: 5000,
            writeOffAmount: 10000,
            writeOffReason: ProjectWriteOffReason.settlement,
            ymd: 20260518,
          ),
          throwsA(isA<StateError>()),
        );

        expect(await _paymentCount(db), 1);
        expect(await _paymentSum(db), 5000);
        expect(await _writeOffCount(db), 0);
        expect(await _projectStatus(db), ProjectStatus.active);
        expect(await db.query('sync_outbox'), isEmpty);
        expect(await db.query('entity_sync_meta'), isEmpty);
      },
    );

    test('project update meta failure rolls back settlement cluster', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db);
      await _seedPayment(db, amount: 5000);
      final useCase = _useCase(
        repository: LocalProjectSettlementRepository(
          projectSyncEnqueuer: ProjectSyncEnqueuer(
            entitySyncMetaRepository: const _ThrowingEntitySyncMetaRepository(),
          ),
        ),
      );

      await expectLater(
        useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 20000,
          paymentAmount: 5000,
          writeOffAmount: 10000,
          writeOffReason: ProjectWriteOffReason.settlement,
          ymd: 20260518,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _paymentCount(db), 1);
      expect(await _paymentSum(db), 5000);
      expect(await _writeOffCount(db), 0);
      expect(await _projectStatus(db), ProjectStatus.active);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    });

    test('requires a reason when write-off amount is positive', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db);
      final useCase = _useCase();

      await expectLater(
        useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 1000,
          paymentAmount: 900,
          writeOffAmount: 100,
          writeOffReason: null,
          ymd: 20260518,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _paymentCount(db), 0);
      expect(await _writeOffCount(db), 0);
      expect(await _projectStatus(db), ProjectStatus.active);
    });

    test('rejects payment amount above remaining', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db);
      await _seedPayment(db, amount: 400);
      final useCase = _useCase();

      await expectLater(
        useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 1000,
          paymentAmount: 700,
          writeOffAmount: 0,
          writeOffReason: null,
          ymd: 20260518,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _paymentCount(db), 1);
      expect(await _writeOffCount(db), 0);
      expect(await _projectStatus(db), ProjectStatus.active);
    });

    test('rejects negative payment and write-off amounts', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db);
      final useCase = _useCase();

      await expectLater(
        useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 1000,
          paymentAmount: -1,
          writeOffAmount: 0,
          writeOffReason: null,
          ymd: 20260518,
        ),
        throwsArgumentError,
      );
      await expectLater(
        useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 1000,
          paymentAmount: 0,
          writeOffAmount: -1,
          writeOffReason: ProjectWriteOffReason.other,
          ymd: 20260518,
        ),
        throwsArgumentError,
      );

      expect(await _paymentCount(db), 0);
      expect(await _writeOffCount(db), 0);
    });

    test('rejects repeat settlement after remaining reaches zero', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db);
      await _seedPayment(db, amount: 1000);
      final useCase = _useCase();

      await expectLater(
        useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 1000,
          paymentAmount: 1,
          writeOffAmount: 0,
          writeOffReason: null,
          ymd: 20260518,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _paymentCount(db), 1);
      expect(await _writeOffCount(db), 0);
    });

    test(
      'repeat calls do not create duplicate payment or write-off rows',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProject(db);
        await _seedPayment(db, amount: 1200);
        final useCase = _useCase();

        await useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 1260,
          paymentAmount: 0,
          writeOffAmount: 60,
          writeOffReason: ProjectWriteOffReason.rounding,
          ymd: 20260518,
        );

        await expectLater(
          useCase.execute(
            projectId: 'project:1',
            projectKey: '甲方||一号工地',
            receivable: 1260,
            paymentAmount: 0,
            writeOffAmount: 60,
            writeOffReason: ProjectWriteOffReason.rounding,
            ymd: 20260518,
          ),
          throwsA(isA<StateError>()),
        );

        expect(await _paymentCount(db), 1);
        expect(await _writeOffCount(db), 1);
        expect(await _projectStatus(db), ProjectStatus.settled);
      },
    );

    test('rejects a new write-off when the project already has one', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db);
      await _seedPayment(db, amount: 1200);
      await _seedWriteOff(db, id: 'existing-write-off', amount: 10);
      final useCase = _useCase();

      await expectLater(
        useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 1260,
          paymentAmount: 0,
          writeOffAmount: 50,
          writeOffReason: ProjectWriteOffReason.settlement,
          ymd: 20260518,
        ),
        throwsA(
          predicate(
            (error) =>
                error is StateError && error.message == '该项目已存在核销记录，请先撤销后再处理。',
          ),
        ),
      );

      expect(await _paymentCount(db), 1);
      expect(await _paymentSum(db), 1200);
      expect(await _writeOffCount(db), 1);
      expect(await _writeOffSum(db), 10);
      expect(await _projectStatus(db), ProjectStatus.active);
    });

    test(
      'deletes write-off and restores a settled project to active',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProject(db, status: ProjectStatus.settled);
        await _seedPayment(db, amount: 1200);
        await _seedWriteOff(db, amount: 60);
        final useCase = _useCase();

        final result = await useCase.deleteWriteOff(
          projectId: 'project:1',
          writeOffId: 'write-off-1',
          receivable: 1260,
        );

        expect(result.deletedAmount, 60);
        expect(result.receivable, 1260);
        expect(result.received, 1200);
        expect(result.writeOffBefore, 60);
        expect(result.writeOffAfter, 0);
        expect(result.remainingAfter, 60);
        expect(result.restoredActive, isTrue);
        expect(await _paymentCount(db), 1);
        expect(await _paymentSum(db), 1200);
        expect(await _writeOffCount(db), 0);
        expect(await _writeOffSum(db), 0);
        final project = await _projectRow(db);
        expect(project.status, ProjectStatus.active);
        expect(project.settledAt, isNull);

        final writeOffDeleteOutbox = await _singleOutbox(
          db,
          entityType: ProjectWriteOffSyncEnqueuer.entityType,
          operation: 'delete',
        );
        final writeOffRecord = _payloadRecord(writeOffDeleteOutbox);
        expect(writeOffRecord['id'], 'write-off-1');
        expect(writeOffRecord['project_id'], 'project:1');
        expect(writeOffRecord['amount_fen'], 6000);
        expect(
          writeOffRecord['reason'],
          ProjectWriteOffReason.rounding.dbValue,
        );
        final projectOutbox = await _singleOutbox(
          db,
          entityType: ProjectSyncEnqueuer.entityType,
          operation: 'update',
        );
        final projectRecord = _payloadRecord(projectOutbox);
        expect(projectRecord['id'], 'project:1');
        expect(projectRecord['status'], ProjectStatus.active.name);
        expect(projectRecord['settled_at'], isNull);
        expect(projectRecord['settled_snapshot'], isNull);
        await _expectMetaMatchesOutbox(
          db,
          writeOffDeleteOutbox,
          SyncStatus.pendingDelete,
        );
        await _expectMetaMatchesOutbox(
          db,
          projectOutbox,
          SyncStatus.pendingUpdate,
        );
        expect(
          await _outboxRows(
            db,
            entityType: 'account_payment',
            operation: 'delete',
          ),
          isEmpty,
        );
      },
    );

    test('deleting write-off does not change payments or receivable', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db, status: ProjectStatus.settled);
      await _seedPayment(db, amount: 1200);
      await _seedWriteOff(db, amount: 60);
      final useCase = _useCase();

      final result = await useCase.deleteWriteOff(
        projectId: 'project:1',
        writeOffId: 'write-off-1',
        receivable: 1260,
      );

      expect(result.receivable, 1260);
      expect(result.received, 1200);
      expect(await _paymentCount(db), 1);
      expect(await _paymentSum(db), 1200);
      expect(await _writeOffCount(db), 0);
    });

    test(
      'deleting write-off does not enqueue account payment delete outbox',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProject(db);
        await _seedPayment(db, amount: 500);
        final useCase = _useCase();
        final settlement = await useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 1000,
          paymentAmount: 400,
          writeOffAmount: 100,
          writeOffReason: ProjectWriteOffReason.settlement,
          ymd: 20260518,
        );
        expect(settlement.settled, isTrue);

        final outboxBefore = await db.query('sync_outbox');
        expect(outboxBefore, hasLength(3));

        final result = await useCase.deleteWriteOff(
          projectId: 'project:1',
          writeOffId: 'write-off-1',
          receivable: 1000,
        );

        expect(result.restoredActive, isTrue);
        expect(await _paymentCount(db), 2);
        expect(await _paymentSum(db), 900);
        expect(await _writeOffCount(db), 0);
        final outboxAfter = await db.query('sync_outbox');
        expect(outboxAfter, hasLength(5));
        expect(
          await _outboxRows(
            db,
            entityType: ProjectWriteOffSyncEnqueuer.entityType,
            operation: 'delete',
          ),
          hasLength(1),
        );
        expect(
          await _outboxRows(
            db,
            entityType: ProjectSyncEnqueuer.entityType,
            operation: 'update',
          ),
          hasLength(2),
        );
        expect(
          await db.query(
            'sync_outbox',
            where: 'entity_type = ? AND operation = ?',
            whereArgs: ['account_payment', 'delete'],
          ),
          isEmpty,
        );
      },
    );

    test('rolls back status when write-off delete target is missing', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db, status: ProjectStatus.settled);
      await _seedPayment(db, amount: 1200);
      await _seedWriteOff(db, amount: 60);
      final useCase = _useCase();

      await expectLater(
        useCase.deleteWriteOff(
          projectId: 'project:1',
          writeOffId: 'missing-write-off',
          receivable: 1260,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _writeOffCount(db), 1);
      expect(await _projectStatus(db), ProjectStatus.settled);
    });

    test(
      'project write-off delete outbox failure rolls back deleteWriteOff',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProject(db, status: ProjectStatus.settled);
        await _seedPayment(db, amount: 1200);
        await _seedWriteOff(db, amount: 60);
        final useCase = _useCase(
          repository: LocalProjectSettlementRepository(
            projectWriteOffSyncEnqueuer: ProjectWriteOffSyncEnqueuer(
              syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
            ),
          ),
        );

        await expectLater(
          useCase.deleteWriteOff(
            projectId: 'project:1',
            writeOffId: 'write-off-1',
            receivable: 1260,
          ),
          throwsA(isA<StateError>()),
        );

        expect(await _paymentCount(db), 1);
        expect(await _writeOffCount(db), 1);
        expect(await _projectStatus(db), ProjectStatus.settled);
        expect(await db.query('sync_outbox'), isEmpty);
        expect(await db.query('entity_sync_meta'), isEmpty);
      },
    );

    test('project update outbox failure rolls back deleteWriteOff', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db, status: ProjectStatus.settled);
      await _seedPayment(db, amount: 1200);
      await _seedWriteOff(db, amount: 60);
      final useCase = _useCase(
        repository: LocalProjectSettlementRepository(
          projectSyncEnqueuer: ProjectSyncEnqueuer(
            syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
          ),
        ),
      );

      await expectLater(
        useCase.deleteWriteOff(
          projectId: 'project:1',
          writeOffId: 'write-off-1',
          receivable: 1260,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _paymentCount(db), 1);
      expect(await _writeOffCount(db), 1);
      expect(await _projectStatus(db), ProjectStatus.settled);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    });

    test('project update meta failure rolls back deleteWriteOff', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db, status: ProjectStatus.settled);
      await _seedPayment(db, amount: 1200);
      await _seedWriteOff(db, amount: 60);
      final useCase = _useCase(
        repository: LocalProjectSettlementRepository(
          projectSyncEnqueuer: ProjectSyncEnqueuer(
            entitySyncMetaRepository: const _ThrowingEntitySyncMetaRepository(),
          ),
        ),
      );

      await expectLater(
        useCase.deleteWriteOff(
          projectId: 'project:1',
          writeOffId: 'write-off-1',
          receivable: 1260,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _paymentCount(db), 1);
      expect(await _writeOffCount(db), 1);
      expect(await _projectStatus(db), ProjectStatus.settled);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    });

    test(
      'rejects deleting a write-off when the project has multiple write-offs',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProject(db, status: ProjectStatus.settled);
        await _seedPayment(db, amount: 1100);
        await _seedWriteOff(db, id: 'write-off-1', amount: 60);
        await _seedWriteOff(db, id: 'write-off-2', amount: 100);
        final useCase = _useCase();

        await expectLater(
          useCase.deleteWriteOff(
            projectId: 'project:1',
            writeOffId: 'write-off-1',
            receivable: 1260,
          ),
          throwsA(
            predicate(
              (error) =>
                  error is StateError && error.message == '该项目核销记录异常，请先检查核销记录。',
            ),
          ),
        );

        expect(await _paymentCount(db), 1);
        expect(await _paymentSum(db), 1100);
        expect(await _writeOffCount(db), 2);
        expect(await _writeOffSum(db), 160);
        expect(await _projectStatus(db), ProjectStatus.settled);
      },
    );

    test(
      'revokes settled status without changing payments or write-offs',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProject(db, status: ProjectStatus.settled);
        await _seedPayment(db, amount: 1260);
        final useCase = _useCase();

        final result = await useCase.revokeSettlementStatus(
          projectId: 'project:1',
        );

        expect(result.projectId, 'project:1');
        expect(result.restoredActive, isTrue);
        expect(await _paymentCount(db), 1);
        expect(await _paymentSum(db), 1260);
        expect(await _writeOffCount(db), 0);
        final project = await _projectRow(db);
        expect(project.status, ProjectStatus.active);
        expect(project.settledAt, isNull);

        final projectOutbox = await _singleOutbox(
          db,
          entityType: ProjectSyncEnqueuer.entityType,
          operation: 'update',
        );
        final projectRecord = _payloadRecord(projectOutbox);
        expect(projectRecord['id'], 'project:1');
        expect(projectRecord['status'], ProjectStatus.active.name);
        expect(projectRecord['settled_at'], isNull);
        expect(projectRecord['settled_snapshot'], isNull);
        await _expectMetaMatchesOutbox(
          db,
          projectOutbox,
          SyncStatus.pendingUpdate,
        );
        expect(
          await _outboxRows(
            db,
            entityType: ProjectWriteOffSyncEnqueuer.entityType,
          ),
          isEmpty,
        );
        expect(await _outboxRows(db, entityType: 'account_payment'), isEmpty);
      },
    );

    test(
      'rejects settled status revoke when write-off records still exist',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProject(db, status: ProjectStatus.settled);
        await _seedPayment(db, amount: 1200);
        await _seedWriteOff(db, amount: 60);
        final useCase = _useCase();

        await expectLater(
          useCase.revokeSettlementStatus(projectId: 'project:1'),
          throwsA(
            predicate(
              (error) =>
                  error is StateError &&
                  error.message == '该项目存在核销记录，请先撤销核销后再处理。',
            ),
          ),
        );

        expect(await _paymentCount(db), 1);
        expect(await _paymentSum(db), 1200);
        expect(await _writeOffCount(db), 1);
        expect(await _projectStatus(db), ProjectStatus.settled);
        expect(await db.query('sync_outbox'), isEmpty);
        expect(await db.query('entity_sync_meta'), isEmpty);
      },
    );

    test(
      'project update outbox failure rolls back revokeSettlementStatus',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProject(db, status: ProjectStatus.settled);
        await _seedPayment(db, amount: 1260);
        final useCase = _useCase(
          repository: LocalProjectSettlementRepository(
            projectSyncEnqueuer: ProjectSyncEnqueuer(
              syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
            ),
          ),
        );

        await expectLater(
          useCase.revokeSettlementStatus(projectId: 'project:1'),
          throwsA(isA<StateError>()),
        );

        expect(await _paymentCount(db), 1);
        expect(await _writeOffCount(db), 0);
        expect(await _projectStatus(db), ProjectStatus.settled);
        expect(await db.query('sync_outbox'), isEmpty);
        expect(await db.query('entity_sync_meta'), isEmpty);
      },
    );

    test(
      'project update meta failure rolls back revokeSettlementStatus',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProject(db, status: ProjectStatus.settled);
        await _seedPayment(db, amount: 1260);
        final useCase = _useCase(
          repository: LocalProjectSettlementRepository(
            projectSyncEnqueuer: ProjectSyncEnqueuer(
              entitySyncMetaRepository:
                  const _ThrowingEntitySyncMetaRepository(),
            ),
          ),
        );

        await expectLater(
          useCase.revokeSettlementStatus(projectId: 'project:1'),
          throwsA(isA<StateError>()),
        );

        expect(await _paymentCount(db), 1);
        expect(await _writeOffCount(db), 0);
        expect(await _projectStatus(db), ProjectStatus.settled);
        expect(await db.query('sync_outbox'), isEmpty);
        expect(await db.query('entity_sync_meta'), isEmpty);
      },
    );
  });

  group('SettleMergedProjectUseCase', () {
    test(
      'settles merged project by writing write-offs to real members',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProjectWithId(db, id: 'project:1', site: '一号工地');
        await _seedProjectWithId(db, id: 'project:2', site: '二号工地');
        final useCase = _mergedUseCase();

        final result = await useCase.execute(
          mergedProject: _mergedProjectVm(remaining: 3000, receivable: 3000),
          memberProjects: [
            _memberProjectVm(
              id: 'project:1',
              key: '甲方||一号工地',
              site: '一号工地',
              receivable: 1000,
              remaining: 1000,
              minYmd: 20260501,
            ),
            _memberProjectVm(
              id: 'project:2',
              key: '甲方||二号工地',
              site: '二号工地',
              receivable: 2000,
              remaining: 2000,
              minYmd: 20260502,
            ),
          ],
          paymentAmount: 0,
          writeOffAmount: 3000,
          writeOffReason: ProjectWriteOffReason.settlement,
          ymd: 20260518,
        );

        expect(result.projectId, 'merge:7');
        expect(result.settled, isTrue);
        expect(await _writeOffCount(db), 2);
        expect(await _writeOffSumByProjectId(db, 'project:1'), 1000);
        expect(await _writeOffSumByProjectId(db, 'project:2'), 2000);
        expect(await _writeOffSumByProjectId(db, 'merge:7'), 0);
        expect(
          await _projectStatusById(db, 'project:1'),
          ProjectStatus.settled,
        );
        expect(
          await _projectStatusById(db, 'project:2'),
          ProjectStatus.settled,
        );

        final writeOffOutbox = await _outboxRows(
          db,
          entityType: ProjectWriteOffSyncEnqueuer.entityType,
          operation: 'create',
        );
        final projectOutbox = await _outboxRows(
          db,
          entityType: ProjectSyncEnqueuer.entityType,
          operation: 'update',
        );
        expect(writeOffOutbox, hasLength(2));
        expect(projectOutbox, hasLength(2));
        _expectUniqueOutboxIds([...writeOffOutbox, ...projectOutbox]);
        expect(await _outboxRows(db, entityType: 'account_payment'), isEmpty);
        expect(
          await _outboxRows(
            db,
            entityType: ProjectWriteOffSyncEnqueuer.entityType,
            operation: 'delete',
          ),
          isEmpty,
        );

        final writeOffById = {
          for (final row in writeOffOutbox) row['entity_id'] as String: row,
        };
        expect(writeOffById.keys, {'writeoff-merge-7-0', 'writeoff-merge-7-1'});
        final firstWriteOff = _payloadRecord(
          writeOffById['writeoff-merge-7-0']!,
        );
        expect(firstWriteOff['project_id'], 'project:1');
        expect(firstWriteOff['amount_fen'], 100000);
        expect(
          firstWriteOff['reason'],
          ProjectWriteOffReason.settlement.dbValue,
        );
        expect(firstWriteOff['write_off_date'], '2026-05-18');
        final secondWriteOff = _payloadRecord(
          writeOffById['writeoff-merge-7-1']!,
        );
        expect(secondWriteOff['project_id'], 'project:2');
        expect(secondWriteOff['amount_fen'], 200000);

        for (final row in writeOffOutbox) {
          await _expectMetaMatchesOutbox(db, row, SyncStatus.pendingUpload);
        }
        for (final row in projectOutbox) {
          final projectRecord = _payloadRecord(row);
          expect(projectRecord['id'], isIn(['project:1', 'project:2']));
          expect(projectRecord['status'], ProjectStatus.settled.name);
          expect(projectRecord['settled_at'], '2026-05-18T01:02:03.000Z');
          expect(projectRecord.containsKey('settled_snapshot'), isTrue);
          await _expectMetaMatchesOutbox(db, row, SyncStatus.pendingUpdate);
        }
      },
    );

    test('does not allocate write-off to a zero-remaining member', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProjectWithId(db, id: 'project:1', site: '一号工地');
      await _seedProjectWithId(db, id: 'project:2', site: '二号工地');
      await _seedPayment(db, amount: 1000);
      final useCase = _mergedUseCase();

      await useCase.execute(
        mergedProject: _mergedProjectVm(remaining: 2000, receivable: 3000),
        memberProjects: [
          _memberProjectVm(
            id: 'project:1',
            key: '甲方||一号工地',
            site: '一号工地',
            receivable: 1000,
            remaining: 0,
            minYmd: 20260501,
          ),
          _memberProjectVm(
            id: 'project:2',
            key: '甲方||二号工地',
            site: '二号工地',
            receivable: 2000,
            remaining: 2000,
            minYmd: 20260502,
          ),
        ],
        paymentAmount: 0,
        writeOffAmount: 2000,
        writeOffReason: ProjectWriteOffReason.settlement,
        ymd: 20260518,
      );

      expect(await _writeOffSumByProjectId(db, 'project:1'), 0);
      expect(await _writeOffSumByProjectId(db, 'project:2'), 2000);
      expect(await _projectStatusById(db, 'project:1'), ProjectStatus.settled);
      expect(await _projectStatusById(db, 'project:2'), ProjectStatus.settled);
    });

    test(
      'blocks merged settlement when a member already has write-off',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProjectWithId(db, id: 'project:1', site: '一号工地');
        await _seedProjectWithId(db, id: 'project:2', site: '二号工地');
        await _seedWriteOffForProject(
          db,
          id: 'existing-write-off',
          projectId: 'project:1',
          amount: 10,
        );
        final useCase = _mergedUseCase();

        await expectLater(
          useCase.execute(
            mergedProject: _mergedProjectVm(remaining: 3000, receivable: 3000),
            memberProjects: [
              _memberProjectVm(
                id: 'project:1',
                key: '甲方||一号工地',
                site: '一号工地',
                receivable: 1000,
                remaining: 1000,
                minYmd: 20260501,
              ),
              _memberProjectVm(
                id: 'project:2',
                key: '甲方||二号工地',
                site: '二号工地',
                receivable: 2000,
                remaining: 2000,
                minYmd: 20260502,
              ),
            ],
            paymentAmount: 0,
            writeOffAmount: 3000,
            writeOffReason: ProjectWriteOffReason.settlement,
            ymd: 20260518,
          ),
          throwsA(
            predicate(
              (error) =>
                  error is StateError &&
                  error.message == '合并成员项目已存在核销记录，请先处理成员项目。',
            ),
          ),
        );

        expect(await _writeOffCount(db), 1);
        expect(await _writeOffSumByProjectId(db, 'project:1'), 10);
        expect(await _projectStatusById(db, 'project:1'), ProjectStatus.active);
        expect(await _projectStatusById(db, 'project:2'), ProjectStatus.active);
      },
    );

    test(
      'rolls back merged settlement when a member project is missing',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProjectWithId(db, id: 'project:1', site: '一号工地');
        final useCase = _mergedUseCase();

        await expectLater(
          useCase.execute(
            mergedProject: _mergedProjectVm(remaining: 3000, receivable: 3000),
            memberProjects: [
              _memberProjectVm(
                id: 'project:1',
                key: '甲方||一号工地',
                site: '一号工地',
                receivable: 1000,
                remaining: 1000,
                minYmd: 20260501,
              ),
              _memberProjectVm(
                id: 'project:2',
                key: '甲方||二号工地',
                site: '二号工地',
                receivable: 2000,
                remaining: 2000,
                minYmd: 20260502,
              ),
            ],
            paymentAmount: 0,
            writeOffAmount: 3000,
            writeOffReason: ProjectWriteOffReason.settlement,
            ymd: 20260518,
          ),
          throwsA(isA<StateError>()),
        );

        expect(await _writeOffCount(db), 0);
        expect(await _projectStatusById(db, 'project:1'), ProjectStatus.active);
      },
    );

    test(
      'merged settlement write-off outbox failure rolls back cluster',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProjectWithId(db, id: 'project:1', site: '一号工地');
        await _seedProjectWithId(db, id: 'project:2', site: '二号工地');
        final useCase = _mergedUseCase(
          repository: LocalProjectSettlementRepository(
            projectWriteOffSyncEnqueuer: ProjectWriteOffSyncEnqueuer(
              syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
            ),
          ),
        );

        await expectLater(
          useCase.execute(
            mergedProject: _mergedProjectVm(remaining: 3000, receivable: 3000),
            memberProjects: [
              _memberProjectVm(
                id: 'project:1',
                key: '甲方||一号工地',
                site: '一号工地',
                receivable: 1000,
                remaining: 1000,
                minYmd: 20260501,
              ),
              _memberProjectVm(
                id: 'project:2',
                key: '甲方||二号工地',
                site: '二号工地',
                receivable: 2000,
                remaining: 2000,
                minYmd: 20260502,
              ),
            ],
            paymentAmount: 0,
            writeOffAmount: 3000,
            writeOffReason: ProjectWriteOffReason.settlement,
            ymd: 20260518,
          ),
          throwsA(isA<StateError>()),
        );

        expect(await _writeOffCount(db), 0);
        expect(await _projectStatusById(db, 'project:1'), ProjectStatus.active);
        expect(await _projectStatusById(db, 'project:2'), ProjectStatus.active);
        expect(await db.query('sync_outbox'), isEmpty);
        expect(await db.query('entity_sync_meta'), isEmpty);
      },
    );

    test(
      'merged settlement write-off meta failure rolls back cluster',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProjectWithId(db, id: 'project:1', site: '一号工地');
        await _seedProjectWithId(db, id: 'project:2', site: '二号工地');
        final useCase = _mergedUseCase(
          repository: LocalProjectSettlementRepository(
            projectWriteOffSyncEnqueuer: ProjectWriteOffSyncEnqueuer(
              entitySyncMetaRepository:
                  const _ThrowingEntitySyncMetaRepository(),
            ),
          ),
        );

        await expectLater(
          useCase.execute(
            mergedProject: _mergedProjectVm(remaining: 3000, receivable: 3000),
            memberProjects: [
              _memberProjectVm(
                id: 'project:1',
                key: '甲方||一号工地',
                site: '一号工地',
                receivable: 1000,
                remaining: 1000,
                minYmd: 20260501,
              ),
              _memberProjectVm(
                id: 'project:2',
                key: '甲方||二号工地',
                site: '二号工地',
                receivable: 2000,
                remaining: 2000,
                minYmd: 20260502,
              ),
            ],
            paymentAmount: 0,
            writeOffAmount: 3000,
            writeOffReason: ProjectWriteOffReason.settlement,
            ymd: 20260518,
          ),
          throwsA(isA<StateError>()),
        );

        expect(await _writeOffCount(db), 0);
        expect(await _projectStatusById(db, 'project:1'), ProjectStatus.active);
        expect(await _projectStatusById(db, 'project:2'), ProjectStatus.active);
        expect(await db.query('sync_outbox'), isEmpty);
        expect(await db.query('entity_sync_meta'), isEmpty);
      },
    );

    test(
      'merged settlement project outbox failure rolls back cluster',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProjectWithId(db, id: 'project:1', site: '一号工地');
        await _seedProjectWithId(db, id: 'project:2', site: '二号工地');
        final useCase = _mergedUseCase(
          repository: LocalProjectSettlementRepository(
            projectSyncEnqueuer: ProjectSyncEnqueuer(
              syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
            ),
          ),
        );

        await expectLater(
          useCase.execute(
            mergedProject: _mergedProjectVm(remaining: 3000, receivable: 3000),
            memberProjects: [
              _memberProjectVm(
                id: 'project:1',
                key: '甲方||一号工地',
                site: '一号工地',
                receivable: 1000,
                remaining: 1000,
                minYmd: 20260501,
              ),
              _memberProjectVm(
                id: 'project:2',
                key: '甲方||二号工地',
                site: '二号工地',
                receivable: 2000,
                remaining: 2000,
                minYmd: 20260502,
              ),
            ],
            paymentAmount: 0,
            writeOffAmount: 3000,
            writeOffReason: ProjectWriteOffReason.settlement,
            ymd: 20260518,
          ),
          throwsA(isA<StateError>()),
        );

        expect(await _writeOffCount(db), 0);
        expect(await _projectStatusById(db, 'project:1'), ProjectStatus.active);
        expect(await _projectStatusById(db, 'project:2'), ProjectStatus.active);
        expect(await db.query('sync_outbox'), isEmpty);
        expect(await db.query('entity_sync_meta'), isEmpty);
      },
    );

    test('merged settlement project meta failure rolls back cluster', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProjectWithId(db, id: 'project:1', site: '一号工地');
      await _seedProjectWithId(db, id: 'project:2', site: '二号工地');
      final useCase = _mergedUseCase(
        repository: LocalProjectSettlementRepository(
          projectSyncEnqueuer: ProjectSyncEnqueuer(
            entitySyncMetaRepository: const _ThrowingEntitySyncMetaRepository(),
          ),
        ),
      );

      await expectLater(
        useCase.execute(
          mergedProject: _mergedProjectVm(remaining: 3000, receivable: 3000),
          memberProjects: [
            _memberProjectVm(
              id: 'project:1',
              key: '甲方||一号工地',
              site: '一号工地',
              receivable: 1000,
              remaining: 1000,
              minYmd: 20260501,
            ),
            _memberProjectVm(
              id: 'project:2',
              key: '甲方||二号工地',
              site: '二号工地',
              receivable: 2000,
              remaining: 2000,
              minYmd: 20260502,
            ),
          ],
          paymentAmount: 0,
          writeOffAmount: 3000,
          writeOffReason: ProjectWriteOffReason.settlement,
          ymd: 20260518,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _writeOffCount(db), 0);
      expect(await _projectStatusById(db, 'project:1'), ProjectStatus.active);
      expect(await _projectStatusById(db, 'project:2'), ProjectStatus.active);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    });

    test('revokes merged settlement from real member projects', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProjectWithId(
        db,
        id: 'project:1',
        site: '一号工地',
        status: ProjectStatus.settled,
      );
      await _seedProjectWithId(
        db,
        id: 'project:2',
        site: '二号工地',
        status: ProjectStatus.settled,
      );
      await _seedWriteOffForProject(
        db,
        id: 'writeoff-merge-7-0',
        projectId: 'project:1',
        amount: 1000,
      );
      await _seedWriteOffForProject(
        db,
        id: 'writeoff-merge-7-1',
        projectId: 'project:2',
        amount: 2000,
      );
      final useCase = _mergedUseCase();
      final mergedProject = _mergedProjectVm(
        remaining: 0,
        receivable: 3000,
        writeOff: 3000,
      );
      final members = [
        _memberProjectVm(
          id: 'project:1',
          key: '甲方||一号工地',
          site: '一号工地',
          receivable: 1000,
          remaining: 0,
          writeOff: 1000,
          minYmd: 20260501,
        ),
        _memberProjectVm(
          id: 'project:2',
          key: '甲方||二号工地',
          site: '二号工地',
          receivable: 2000,
          remaining: 0,
          writeOff: 2000,
          minYmd: 20260502,
        ),
      ];

      final result = await useCase.deleteWriteOffs(
        mergedProject: mergedProject,
        memberProjects: members,
        writeOffs: await _writeOffRows(db),
      );

      expect(result.projectId, 'merge:7');
      expect(await _writeOffCount(db), 0);
      expect(await _projectStatusById(db, 'project:1'), ProjectStatus.active);
      expect(await _projectStatusById(db, 'project:2'), ProjectStatus.active);

      final writeOffDeleteOutbox = await _outboxRows(
        db,
        entityType: ProjectWriteOffSyncEnqueuer.entityType,
        operation: 'delete',
      );
      final projectOutbox = await _outboxRows(
        db,
        entityType: ProjectSyncEnqueuer.entityType,
        operation: 'update',
      );
      expect(writeOffDeleteOutbox, hasLength(2));
      expect(projectOutbox, hasLength(2));
      _expectUniqueOutboxIds([...writeOffDeleteOutbox, ...projectOutbox]);
      expect(
        await _outboxRows(
          db,
          entityType: ProjectWriteOffSyncEnqueuer.entityType,
          operation: 'create',
        ),
        isEmpty,
      );
      expect(
        await _outboxRows(
          db,
          entityType: 'account_payment',
          operation: 'delete',
        ),
        isEmpty,
      );

      for (final row in writeOffDeleteOutbox) {
        final record = _payloadRecord(row);
        expect(record['id'], row['entity_id']);
        expect(record['project_id'], isIn(['project:1', 'project:2']));
        expect(record['amount_fen'], isIn([100000, 200000]));
        expect(record['reason'], ProjectWriteOffReason.settlement.dbValue);
        await _expectMetaMatchesOutbox(db, row, SyncStatus.pendingDelete);
      }
      for (final row in projectOutbox) {
        final record = _payloadRecord(row);
        expect(record['id'], isIn(['project:1', 'project:2']));
        expect(record['status'], ProjectStatus.active.name);
        expect(record['settled_at'], isNull);
        expect(record['settled_snapshot'], isNull);
        await _expectMetaMatchesOutbox(db, row, SyncStatus.pendingUpdate);
      }
    });

    test(
      'merged write-off delete outbox failure rolls back deleteWriteOffs',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProjectWithId(
          db,
          id: 'project:1',
          site: '一号工地',
          status: ProjectStatus.settled,
        );
        await _seedProjectWithId(
          db,
          id: 'project:2',
          site: '二号工地',
          status: ProjectStatus.settled,
        );
        await _seedWriteOffForProject(
          db,
          id: 'writeoff-merge-7-0',
          projectId: 'project:1',
          amount: 1000,
        );
        await _seedWriteOffForProject(
          db,
          id: 'writeoff-merge-7-1',
          projectId: 'project:2',
          amount: 2000,
        );
        final useCase = _mergedUseCase(
          repository: LocalProjectSettlementRepository(
            projectWriteOffSyncEnqueuer: ProjectWriteOffSyncEnqueuer(
              syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
            ),
          ),
        );

        await expectLater(
          useCase.deleteWriteOffs(
            mergedProject: _mergedProjectVm(
              remaining: 0,
              receivable: 3000,
              writeOff: 3000,
            ),
            memberProjects: [
              _memberProjectVm(
                id: 'project:1',
                key: '甲方||一号工地',
                site: '一号工地',
                receivable: 1000,
                remaining: 0,
                writeOff: 1000,
                minYmd: 20260501,
              ),
              _memberProjectVm(
                id: 'project:2',
                key: '甲方||二号工地',
                site: '二号工地',
                receivable: 2000,
                remaining: 0,
                writeOff: 2000,
                minYmd: 20260502,
              ),
            ],
            writeOffs: await _writeOffRows(db),
          ),
          throwsA(isA<StateError>()),
        );

        expect(await _writeOffCount(db), 2);
        expect(
          await _projectStatusById(db, 'project:1'),
          ProjectStatus.settled,
        );
        expect(
          await _projectStatusById(db, 'project:2'),
          ProjectStatus.settled,
        );
        expect(await db.query('sync_outbox'), isEmpty);
        expect(await db.query('entity_sync_meta'), isEmpty);
      },
    );

    test(
      'merged project update outbox failure rolls back deleteWriteOffs',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProjectWithId(
          db,
          id: 'project:1',
          site: '一号工地',
          status: ProjectStatus.settled,
        );
        await _seedProjectWithId(
          db,
          id: 'project:2',
          site: '二号工地',
          status: ProjectStatus.settled,
        );
        await _seedWriteOffForProject(
          db,
          id: 'writeoff-merge-7-0',
          projectId: 'project:1',
          amount: 1000,
        );
        await _seedWriteOffForProject(
          db,
          id: 'writeoff-merge-7-1',
          projectId: 'project:2',
          amount: 2000,
        );
        final useCase = _mergedUseCase(
          repository: LocalProjectSettlementRepository(
            projectSyncEnqueuer: ProjectSyncEnqueuer(
              syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
            ),
          ),
        );

        await expectLater(
          useCase.deleteWriteOffs(
            mergedProject: _mergedProjectVm(
              remaining: 0,
              receivable: 3000,
              writeOff: 3000,
            ),
            memberProjects: [
              _memberProjectVm(
                id: 'project:1',
                key: '甲方||一号工地',
                site: '一号工地',
                receivable: 1000,
                remaining: 0,
                writeOff: 1000,
                minYmd: 20260501,
              ),
              _memberProjectVm(
                id: 'project:2',
                key: '甲方||二号工地',
                site: '二号工地',
                receivable: 2000,
                remaining: 0,
                writeOff: 2000,
                minYmd: 20260502,
              ),
            ],
            writeOffs: await _writeOffRows(db),
          ),
          throwsA(isA<StateError>()),
        );

        expect(await _writeOffCount(db), 2);
        expect(
          await _projectStatusById(db, 'project:1'),
          ProjectStatus.settled,
        );
        expect(
          await _projectStatusById(db, 'project:2'),
          ProjectStatus.settled,
        );
        expect(await db.query('sync_outbox'), isEmpty);
        expect(await db.query('entity_sync_meta'), isEmpty);
      },
    );

    test(
      'merged project update meta failure rolls back deleteWriteOffs',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProjectWithId(
          db,
          id: 'project:1',
          site: '一号工地',
          status: ProjectStatus.settled,
        );
        await _seedProjectWithId(
          db,
          id: 'project:2',
          site: '二号工地',
          status: ProjectStatus.settled,
        );
        await _seedWriteOffForProject(
          db,
          id: 'writeoff-merge-7-0',
          projectId: 'project:1',
          amount: 1000,
        );
        await _seedWriteOffForProject(
          db,
          id: 'writeoff-merge-7-1',
          projectId: 'project:2',
          amount: 2000,
        );
        final useCase = _mergedUseCase(
          repository: LocalProjectSettlementRepository(
            projectSyncEnqueuer: ProjectSyncEnqueuer(
              entitySyncMetaRepository:
                  const _ThrowingEntitySyncMetaRepository(),
            ),
          ),
        );

        await expectLater(
          useCase.deleteWriteOffs(
            mergedProject: _mergedProjectVm(
              remaining: 0,
              receivable: 3000,
              writeOff: 3000,
            ),
            memberProjects: [
              _memberProjectVm(
                id: 'project:1',
                key: '甲方||一号工地',
                site: '一号工地',
                receivable: 1000,
                remaining: 0,
                writeOff: 1000,
                minYmd: 20260501,
              ),
              _memberProjectVm(
                id: 'project:2',
                key: '甲方||二号工地',
                site: '二号工地',
                receivable: 2000,
                remaining: 0,
                writeOff: 2000,
                minYmd: 20260502,
              ),
            ],
            writeOffs: await _writeOffRows(db),
          ),
          throwsA(isA<StateError>()),
        );

        expect(await _writeOffCount(db), 2);
        expect(
          await _projectStatusById(db, 'project:1'),
          ProjectStatus.settled,
        );
        expect(
          await _projectStatusById(db, 'project:2'),
          ProjectStatus.settled,
        );
        expect(await db.query('sync_outbox'), isEmpty);
        expect(await db.query('entity_sync_meta'), isEmpty);
      },
    );

    test('revokes merged settlement status without write-off outbox', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProjectWithId(
        db,
        id: 'project:1',
        site: '一号工地',
        status: ProjectStatus.settled,
      );
      await _seedProjectWithId(
        db,
        id: 'project:2',
        site: '二号工地',
        status: ProjectStatus.settled,
      );
      final useCase = _mergedUseCase();

      final result = await useCase.revokeSettlementStatus(
        mergedProject: _mergedProjectVm(remaining: 0, receivable: 3000),
        memberProjects: [
          _memberProjectVm(
            id: 'project:1',
            key: '甲方||一号工地',
            site: '一号工地',
            receivable: 1000,
            remaining: 0,
            minYmd: 20260501,
          ),
          _memberProjectVm(
            id: 'project:2',
            key: '甲方||二号工地',
            site: '二号工地',
            receivable: 2000,
            remaining: 0,
            minYmd: 20260502,
          ),
        ],
      );

      expect(result.projectId, 'merge:7');
      expect(result.restoredActive, isTrue);
      expect(await _projectStatusById(db, 'project:1'), ProjectStatus.active);
      expect(await _projectStatusById(db, 'project:2'), ProjectStatus.active);
      expect(
        await _outboxRows(
          db,
          entityType: ProjectWriteOffSyncEnqueuer.entityType,
        ),
        isEmpty,
      );
      expect(await _outboxRows(db, entityType: 'account_payment'), isEmpty);

      final projectOutbox = await _outboxRows(
        db,
        entityType: ProjectSyncEnqueuer.entityType,
        operation: 'update',
      );
      expect(projectOutbox, hasLength(2));
      _expectUniqueOutboxIds(projectOutbox);
      for (final row in projectOutbox) {
        final record = _payloadRecord(row);
        expect(record['id'], isIn(['project:1', 'project:2']));
        expect(record['status'], ProjectStatus.active.name);
        expect(record['settled_at'], isNull);
        expect(record['settled_snapshot'], isNull);
        await _expectMetaMatchesOutbox(db, row, SyncStatus.pendingUpdate);
      }
    });

    test(
      'revoke merged settlement rejects write-offs and does not enqueue',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProjectWithId(
          db,
          id: 'project:1',
          site: '一号工地',
          status: ProjectStatus.settled,
        );
        await _seedProjectWithId(
          db,
          id: 'project:2',
          site: '二号工地',
          status: ProjectStatus.settled,
        );
        await _seedWriteOffForProject(
          db,
          id: 'writeoff-merge-7-0',
          projectId: 'project:1',
          amount: 1000,
        );
        final useCase = _mergedUseCase();

        await expectLater(
          useCase.revokeSettlementStatus(
            mergedProject: _mergedProjectVm(
              remaining: 0,
              receivable: 3000,
              writeOff: 1000,
            ),
            memberProjects: [
              _memberProjectVm(
                id: 'project:1',
                key: '甲方||一号工地',
                site: '一号工地',
                receivable: 1000,
                remaining: 0,
                writeOff: 1000,
                minYmd: 20260501,
              ),
              _memberProjectVm(
                id: 'project:2',
                key: '甲方||二号工地',
                site: '二号工地',
                receivable: 2000,
                remaining: 0,
                minYmd: 20260502,
              ),
            ],
          ),
          throwsA(
            predicate(
              (error) =>
                  error is StateError &&
                  error.message == '该项目存在核销记录，请先撤销核销后再处理。',
            ),
          ),
        );

        expect(
          await _projectStatusById(db, 'project:1'),
          ProjectStatus.settled,
        );
        expect(
          await _projectStatusById(db, 'project:2'),
          ProjectStatus.settled,
        );
        expect(await _writeOffCount(db), 1);
        expect(await db.query('sync_outbox'), isEmpty);
        expect(await db.query('entity_sync_meta'), isEmpty);
      },
    );

    test('merged revoke project outbox failure rolls back status', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProjectWithId(
        db,
        id: 'project:1',
        site: '一号工地',
        status: ProjectStatus.settled,
      );
      await _seedProjectWithId(
        db,
        id: 'project:2',
        site: '二号工地',
        status: ProjectStatus.settled,
      );
      final useCase = _mergedUseCase(
        repository: LocalProjectSettlementRepository(
          projectSyncEnqueuer: ProjectSyncEnqueuer(
            syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
          ),
        ),
      );

      await expectLater(
        useCase.revokeSettlementStatus(
          mergedProject: _mergedProjectVm(remaining: 0, receivable: 3000),
          memberProjects: [
            _memberProjectVm(
              id: 'project:1',
              key: '甲方||一号工地',
              site: '一号工地',
              receivable: 1000,
              remaining: 0,
              minYmd: 20260501,
            ),
            _memberProjectVm(
              id: 'project:2',
              key: '甲方||二号工地',
              site: '二号工地',
              receivable: 2000,
              remaining: 0,
              minYmd: 20260502,
            ),
          ],
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _projectStatusById(db, 'project:1'), ProjectStatus.settled);
      expect(await _projectStatusById(db, 'project:2'), ProjectStatus.settled);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    });

    test('merged revoke project meta failure rolls back status', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProjectWithId(
        db,
        id: 'project:1',
        site: '一号工地',
        status: ProjectStatus.settled,
      );
      await _seedProjectWithId(
        db,
        id: 'project:2',
        site: '二号工地',
        status: ProjectStatus.settled,
      );
      final useCase = _mergedUseCase(
        repository: LocalProjectSettlementRepository(
          projectSyncEnqueuer: ProjectSyncEnqueuer(
            entitySyncMetaRepository: const _ThrowingEntitySyncMetaRepository(),
          ),
        ),
      );

      await expectLater(
        useCase.revokeSettlementStatus(
          mergedProject: _mergedProjectVm(remaining: 0, receivable: 3000),
          memberProjects: [
            _memberProjectVm(
              id: 'project:1',
              key: '甲方||一号工地',
              site: '一号工地',
              receivable: 1000,
              remaining: 0,
              minYmd: 20260501,
            ),
            _memberProjectVm(
              id: 'project:2',
              key: '甲方||二号工地',
              site: '二号工地',
              receivable: 2000,
              remaining: 0,
              minYmd: 20260502,
            ),
          ],
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _projectStatusById(db, 'project:1'), ProjectStatus.settled);
      expect(await _projectStatusById(db, 'project:2'), ProjectStatus.settled);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    });
  });
}

ProjectSettlementUseCase _useCase({
  LocalProjectSettlementRepository repository =
      const LocalProjectSettlementRepository(),
}) {
  return ProjectSettlementUseCase(
    repository: repository,
    now: () => DateTime.utc(2026, 5, 18, 1, 2, 3),
    writeOffIdFactory: (_, _) => 'write-off-1',
  );
}

SettleMergedProjectUseCase _mergedUseCase({
  LocalProjectSettlementRepository repository =
      const LocalProjectSettlementRepository(),
}) {
  return SettleMergedProjectUseCase(
    repository: repository,
    now: () => DateTime.utc(2026, 5, 18, 1, 2, 3),
    writeOffIdFactory:
        ({
          required int mergeGroupId,
          required String projectId,
          required int index,
          required DateTime now,
        }) {
          return 'writeoff-merge-$mergeGroupId-$index';
        },
  );
}

AccountProjectVM _mergedProjectVm({
  required double receivable,
  required double remaining,
  double writeOff = 0,
}) {
  return AccountProjectVM(
    projectId: 'merge:7',
    projectKey: 'merge:7',
    displayName: '甲方 + 合并2项目',
    kind: AccountProjectKind.merged,
    mergeGroupId: 7,
    memberProjectKeys: const ['甲方||一号工地', '甲方||二号工地'],
    memberProjectIds: const ['project:1', 'project:2'],
    includedSites: const ['一号工地', '二号工地'],
    minYmd: 20260501,
    deviceIds: const [1],
    hoursByDevice: const {1: 30},
    rentIncomeTotal: 0,
    minRate: 100,
    isMultiDevice: false,
    isMultiMode: false,
    receivable: receivable,
    received: 0,
    writeOff: writeOff,
    remaining: remaining,
    ratio: receivable <= 0 ? null : 0,
    settlementRatio: receivable <= 0 ? null : writeOff / receivable,
    payments: const [],
  );
}

AccountProjectVM _memberProjectVm({
  required String id,
  required String key,
  required String site,
  required double receivable,
  required double remaining,
  required int minYmd,
  double writeOff = 0,
}) {
  return AccountProjectVM(
    projectId: id,
    projectKey: key,
    displayName: '甲方 + $site',
    minYmd: minYmd,
    deviceIds: const [1],
    hoursByDevice: const {1: 10},
    rentIncomeTotal: 0,
    minRate: 100,
    isMultiDevice: false,
    isMultiMode: false,
    receivable: receivable,
    received: receivable - remaining - writeOff,
    writeOff: writeOff,
    remaining: remaining,
    ratio: receivable <= 0 ? null : 0,
    settlementRatio: receivable <= 0 ? null : writeOff / receivable,
    payments: const [],
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

Future<void> _seedProject(
  Database db, {
  ProjectStatus status = ProjectStatus.active,
}) async {
  await db.insert(
    SqfliteProjectRepository.table,
    Project(
      id: 'project:1',
      contact: '甲方',
      site: '一号工地',
      status: status,
      settledAt: status == ProjectStatus.settled
          ? '2026-05-18T00:00:00.000Z'
          : null,
      createdAt: '2026-05-01T00:00:00.000Z',
      updatedAt: '2026-05-01T00:00:00.000Z',
      legacyProjectKey: '甲方||一号工地',
    ).toMap(),
  );
}

Future<void> _seedProjectWithId(
  Database db, {
  required String id,
  required String site,
  ProjectStatus status = ProjectStatus.active,
}) async {
  await db.insert(
    SqfliteProjectRepository.table,
    Project(
      id: id,
      contact: '甲方',
      site: site,
      status: status,
      settledAt: status == ProjectStatus.settled
          ? '2026-05-18T00:00:00.000Z'
          : null,
      createdAt: '2026-05-01T00:00:00.000Z',
      updatedAt: '2026-05-01T00:00:00.000Z',
      legacyProjectKey: '甲方||$site',
    ).toMap(),
  );
}

Future<void> _seedWriteOff(
  Database db, {
  String id = 'write-off-1',
  required double amount,
}) async {
  await db.insert(
    SqfliteProjectWriteOffRepository.table,
    ProjectWriteOff(
      id: id,
      projectId: 'project:1',
      amount: amount,
      reason: ProjectWriteOffReason.rounding.dbValue,
      writeOffDate: '2026-05-18',
      createdAt: '2026-05-18T00:00:00.000Z',
      updatedAt: '2026-05-18T00:00:00.000Z',
    ).toMap(),
  );
}

Future<void> _seedWriteOffForProject(
  Database db, {
  required String id,
  required String projectId,
  required double amount,
}) async {
  await db.insert(
    SqfliteProjectWriteOffRepository.table,
    ProjectWriteOff(
      id: id,
      projectId: projectId,
      amount: amount,
      reason: ProjectWriteOffReason.settlement.dbValue,
      writeOffDate: '2026-05-18',
      createdAt: '2026-05-18T00:00:00.000Z',
      updatedAt: '2026-05-18T00:00:00.000Z',
    ).toMap(),
  );
}

Future<void> _seedPayment(Database db, {required double amount}) async {
  await db.insert(
    SqfliteAccountPaymentRepository.table,
    AccountPayment(
      projectId: 'project:1',
      projectKey: '甲方||一号工地',
      ymd: 20260501,
      amount: amount,
      createdAt: '2026-05-01T00:00:00.000Z',
    ).toMap(),
  );
}

Future<int> _paymentCount(Database db) async {
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS count FROM ${SqfliteAccountPaymentRepository.table}',
  );
  return (rows.single['count'] as num).toInt();
}

Future<double> _paymentSum(Database db) async {
  final rows = await db.rawQuery(
    'SELECT COALESCE(SUM(amount), 0) AS total FROM ${SqfliteAccountPaymentRepository.table}',
  );
  return (rows.single['total'] as num?)?.toDouble() ?? 0.0;
}

Future<int> _writeOffCount(Database db) async {
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS count FROM ${SqfliteProjectWriteOffRepository.table}',
  );
  return (rows.single['count'] as num).toInt();
}

Future<double> _writeOffSum(Database db) async {
  final rows = await db.rawQuery(
    'SELECT COALESCE(SUM(amount), 0) AS total FROM ${SqfliteProjectWriteOffRepository.table}',
  );
  return (rows.single['total'] as num?)?.toDouble() ?? 0.0;
}

Future<double> _writeOffSumByProjectId(Database db, String projectId) async {
  final rows = await db.rawQuery(
    'SELECT COALESCE(SUM(amount), 0) AS total '
    'FROM ${SqfliteProjectWriteOffRepository.table} WHERE project_id = ?',
    [projectId],
  );
  return (rows.single['total'] as num?)?.toDouble() ?? 0.0;
}

Future<List<ProjectWriteOff>> _writeOffRows(Database db) async {
  final rows = await db.query(SqfliteProjectWriteOffRepository.table);
  return rows.map(ProjectWriteOff.fromMap).toList();
}

Future<ProjectStatus> _projectStatus(Database db) async {
  return (await _projectRow(db)).status;
}

Future<ProjectStatus> _projectStatusById(Database db, String projectId) async {
  final rows = await db.query(
    SqfliteProjectRepository.table,
    where: 'id = ?',
    whereArgs: [projectId],
  );
  return Project.fromMap(rows.single).status;
}

Future<Project> _projectRow(Database db) async {
  final rows = await db.query(
    SqfliteProjectRepository.table,
    where: 'id = ?',
    whereArgs: ['project:1'],
  );
  return Project.fromMap(rows.single);
}

Future<List<Map<String, Object?>>> _outboxRows(
  Database db, {
  String? entityType,
  String? operation,
}) async {
  final rows = await db.query('sync_outbox', orderBy: 'created_at ASC, id ASC');
  return rows
      .where((row) {
        if (entityType != null && row['entity_type'] != entityType) {
          return false;
        }
        if (operation != null && row['operation'] != operation) return false;
        return true;
      })
      .toList(growable: false);
}

Future<Map<String, Object?>> _singleOutbox(
  Database db, {
  required String entityType,
  required String operation,
}) async {
  final rows = await _outboxRows(
    db,
    entityType: entityType,
    operation: operation,
  );
  expect(
    rows,
    hasLength(1),
    reason: 'Expected one $entityType/$operation outbox row',
  );
  return rows.single;
}

Map<String, Object?> _payload(Map<String, Object?> outbox) {
  return (jsonDecode(outbox['payload_json'] as String) as Map)
      .cast<String, Object?>();
}

Map<String, Object?> _payloadRecord(Map<String, Object?> outbox) {
  return (_payload(outbox)['record'] as Map).cast<String, Object?>();
}

Future<void> _expectMetaMatchesOutbox(
  Database db,
  Map<String, Object?> outbox,
  SyncStatus syncStatus,
) async {
  final rows = await db.query(
    'entity_sync_meta',
    where: 'entity_type = ? AND local_id = ?',
    whereArgs: [outbox['entity_type'], outbox['entity_id']],
  );
  expect(
    rows,
    hasLength(1),
    reason:
        'Expected one meta row for '
        '${outbox['entity_type']}/${outbox['entity_id']}',
  );
  final meta = rows.single;
  expect(meta['sync_status'], syncStatus.name);
  expect(meta['payload_hash'], outbox['payload_hash']);
}

void _expectUniqueOutboxIds(List<Map<String, Object?>> rows) {
  expect(rows.map((row) => row['id']).toSet(), hasLength(rows.length));
}

class _ThrowingSyncOutboxRepository implements SyncOutboxRepository {
  const _ThrowingSyncOutboxRepository();

  @override
  Future<SyncOutboxEntry> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    throw StateError('注入的失败：sync_outbox 写入失败');
  }

  @override
  Future<SyncOutboxEntry> enqueueWithExecutor(
    DatabaseExecutor executor, {
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    throw StateError('注入的失败：sync_outbox 写入失败');
  }

  @override
  Future<List<SyncOutboxEntry>> listPending({int limit = 50}) async {
    return const [];
  }
}

class _ThrowingEntitySyncMetaRepository implements EntitySyncMetaRepository {
  const _ThrowingEntitySyncMetaRepository();

  @override
  Future<void> upsert(EntitySyncMeta meta) {
    throw StateError('注入的失败：entity_sync_meta 写入失败');
  }

  @override
  Future<void> upsertWithExecutor(
    DatabaseExecutor executor,
    EntitySyncMeta meta,
  ) {
    throw StateError('注入的失败：entity_sync_meta 写入失败');
  }

  @override
  Future<EntitySyncMeta?> find({
    required String entityType,
    required String localId,
  }) async {
    return null;
  }
}
