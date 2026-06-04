import 'dart:convert';

import 'package:asset_ledger/core/errors/external_work_errors.dart';
import 'package:asset_ledger/core/money/amount_policy.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/external_import_batch.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/repositories/external_import_repository.dart';
import 'package:asset_ledger/data/repositories/external_work_record_repository.dart';
import 'package:asset_ledger/infrastructure/local/timing/external_work_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/sync/entity_sync_meta.dart';
import 'package:asset_ledger/infrastructure/sync/sync_outbox_entry.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  group('SqfliteExternalWorkRecordRepository', () {
    test(
      'linked_project_id may be null and records do not enter timing',
      () async {
        final db = await _openCurrentInMemoryDb();
        final importRepo = SqfliteExternalImportRepository();
        final recordRepo = SqfliteExternalWorkRecordRepository();

        await importRepo.insertBatch(_batch());
        await recordRepo.insertRecord(_record(linkedProjectId: null));

        final records = await recordRepo.listByBatchId('batch-1');
        expect(records, hasLength(1));
        expect(records.single.linkedProjectId, isNull);
        expect(await db.query('timing_records'), isEmpty);
        expect(await db.rawQuery('PRAGMA foreign_key_check;'), isEmpty);
      },
    );

    test(
      'linked_project_id FK rejects orphans and restricts project delete',
      () async {
        final db = await _openCurrentInMemoryDb();
        final importRepo = SqfliteExternalImportRepository();
        final recordRepo = SqfliteExternalWorkRecordRepository();
        final project = _project();

        await importRepo.insertBatch(_batch());
        await expectLater(
          recordRepo.insertRecord(
            _record(id: 'external-record-orphan', linkedProjectId: 'missing'),
          ),
          throwsA(isA<DatabaseException>()),
        );

        await db.insert('projects', project.toMap());
        await recordRepo.insertRecord(_record(linkedProjectId: project.id));

        await expectLater(
          db.delete('projects', where: 'id = ?', whereArgs: [project.id]),
          throwsA(isA<DatabaseException>()),
        );
        expect(await db.rawQuery('PRAGMA foreign_key_check;'), isEmpty);
      },
    );

    test('status changes are soft updates, not hard deletes', () async {
      await _openCurrentInMemoryDb();
      final importRepo = SqfliteExternalImportRepository();
      final recordRepo = SqfliteExternalWorkRecordRepository();

      await importRepo.insertBatch(_batch());
      await recordRepo.insertRecords([
        _record(id: 'external-record-ignored', sourceRecordUuid: 'source-1'),
        _record(id: 'external-record-archived', sourceRecordUuid: 'source-2'),
        _record(id: 'external-record-voided', sourceRecordUuid: 'source-3'),
      ]);

      await recordRepo.updateLocalFields(
        recordId: 'external-record-ignored',
        status: ExternalWorkRecordStatus.ignored,
        updatedAt: '2026-05-18T01:00:00.000Z',
      );
      await recordRepo.updateLocalFields(
        recordId: 'external-record-archived',
        status: ExternalWorkRecordStatus.archived,
        updatedAt: '2026-05-18T01:00:00.000Z',
      );
      await recordRepo.updateLocalFields(
        recordId: 'external-record-voided',
        status: ExternalWorkRecordStatus.voided,
        updatedAt: '2026-05-18T01:00:00.000Z',
      );

      final records = await recordRepo.listByBatchId('batch-1');

      expect(records, hasLength(3));
      expect(records.map((record) => record.status).toSet(), {
        ExternalWorkRecordStatus.ignored,
        ExternalWorkRecordStatus.archived,
        ExternalWorkRecordStatus.voided,
      });
    });

    test('local updates do not overwrite source facts', () async {
      final db = await _openCurrentInMemoryDb();
      final importRepo = SqfliteExternalImportRepository();
      final recordRepo = SqfliteExternalWorkRecordRepository();

      await db.insert('projects', _project().toMap());
      await importRepo.insertBatch(_batch());
      await recordRepo.insertRecord(
        _record(sourceUnitPriceFen: 30000, localUnitPriceFen: 30000),
      );

      await recordRepo.updateLocalFields(
        recordId: 'external-record-1',
        localUnitPriceFen: 38000,
        linkedProjectId: 'project:linked',
        note: '本机确认',
        updatedAt: '2026-05-18T02:00:00.000Z',
      );

      final records = await recordRepo.listByBatchId('batch-1');
      final record = records.single;
      final expectedAmount = AmountPolicy.calculateAmount(
        hours: const WorkHours(1500),
        unitPrice: const UnitPrice(38000),
      ).fen;

      expect(record.sourceUnitPriceFen, 30000);
      expect(record.localUnitPriceFen, 38000);
      expect(record.amountFen, expectedAmount);
      expect(record.linkedProjectId, 'project:linked');
      expect(record.note, '本机确认');
      expect(record.sourceShareId, 'share-1');
      expect(record.sourceRecordUuid, 'source-record-1');
    });

    test(
      'project received amount snapshot round-trips through storage',
      () async {
        await _openCurrentInMemoryDb();
        final importRepo = SqfliteExternalImportRepository();
        final recordRepo = SqfliteExternalWorkRecordRepository();

        await importRepo.insertBatch(_batch());
        await recordRepo.insertRecord(_record(projectReceivedFen: 65432));

        final records = await recordRepo.listByBatchId('batch-1');
        expect(records.single.projectReceivedFen, 65432);
      },
    );

    test('listByLinkedProjectId returns only linked project rows', () async {
      final db = await _openCurrentInMemoryDb();
      final importRepo = SqfliteExternalImportRepository();
      final recordRepo = SqfliteExternalWorkRecordRepository();
      await db.insert('projects', _project(id: 'project:a').toMap());
      await db.insert('projects', _project(id: 'project:b').toMap());

      await importRepo.insertBatch(_batch());
      await recordRepo.insertRecords([
        _record(
          id: 'external-record-a',
          sourceRecordUuid: 'source-a',
          linkedProjectId: 'project:a',
        ),
        _record(
          id: 'external-record-b',
          sourceRecordUuid: 'source-b',
          linkedProjectId: 'project:b',
        ),
        _record(
          id: 'external-record-none',
          sourceRecordUuid: 'source-none',
          linkedProjectId: null,
        ),
      ]);

      final linked = await recordRepo.listByLinkedProjectId('project:a');

      expect(linked.map((record) => record.id).toList(), ['external-record-a']);
    });

    test(
      'deleteById removes record and prunes only empty import batch',
      () async {
        final db = await _openCurrentInMemoryDb();
        final importRepo = SqfliteExternalImportRepository();
        final recordRepo = SqfliteExternalWorkRecordRepository();

        await importRepo.insertBatch(_batch());
        await recordRepo.insertRecords([
          _record(id: 'external-record-a', sourceRecordUuid: 'source-a'),
          _record(id: 'external-record-b', sourceRecordUuid: 'source-b'),
        ]);

        expect(await recordRepo.deleteById('external-record-a'), 1);
        expect(await recordRepo.listByBatchId('batch-1'), hasLength(1));
        expect(await db.query('external_import_batches'), hasLength(1));

        expect(await recordRepo.deleteById('external-record-b'), 1);
        expect(await recordRepo.listByBatchId('batch-1'), isEmpty);
        expect(await db.query('external_import_batches'), isEmpty);
        expect(await db.rawQuery('PRAGMA foreign_key_check;'), isEmpty);
      },
    );

    test(
      'deleteByBatchId removes only records from one import batch',
      () async {
        final db = await _openCurrentInMemoryDb();
        final importRepo = SqfliteExternalImportRepository();
        final recordRepo = SqfliteExternalWorkRecordRepository();

        await importRepo.insertBatch(_batch());
        await importRepo.insertBatch(
          _batch(id: 'batch-2', sourceShareId: 'share-2'),
        );
        await recordRepo.insertRecords([
          _record(id: 'external-record-a', sourceRecordUuid: 'source-a'),
          _record(id: 'external-record-b', sourceRecordUuid: 'source-b'),
          _record(
            id: 'external-record-c',
            importBatchId: 'batch-2',
            sourceShareId: 'share-2',
            sourceRecordUuid: 'source-c',
          ),
        ]);

        expect(await recordRepo.deleteByBatchId('batch-1'), 2);

        expect(await recordRepo.listByBatchId('batch-1'), isEmpty);
        expect(
          (await recordRepo.listByBatchId(
            'batch-2',
          )).map((record) => record.id),
          ['external-record-c'],
        );
        expect(
          (await db.query('external_import_batches')).map((row) => row['id']),
          ['batch-2'],
        );
        expect(await db.rawQuery('PRAGMA foreign_key_check;'), isEmpty);
      },
    );
  });

  group('sync outbox coverage', () {
    test(
      'linkBatchToProject enqueues row-level update sync in the same transaction',
      () async {
        final db = await _openCurrentInMemoryDb();
        final recordRepo = SqfliteExternalWorkRecordRepository();
        await db.insert('projects', _project(id: 'project:a').toMap());
        await _insertBatchRecords();

        final linked = await recordRepo.linkBatchToProject(
          importBatchId: 'batch-1',
          projectId: 'project:a',
          updatedAt: '2026-05-20T00:00:00.000Z',
        );

        expect(linked, 2);
        final records = await recordRepo.listByBatchId('batch-1');
        expect(records.map((record) => record.linkedProjectId).toSet(), {
          'project:a',
        });
        await _expectExternalWorkSyncRows(
          db,
          records,
          operation: 'update',
          syncStatus: SyncStatus.pendingUpdate,
        );
        await _expectNoNonExternalWorkSyncRows(db);
      },
    );

    test(
      'unlinkBatch enqueues row-level update sync in the same transaction',
      () async {
        final db = await _openCurrentInMemoryDb();
        final recordRepo = SqfliteExternalWorkRecordRepository();
        await db.insert('projects', _project(id: 'project:a').toMap());
        await _insertBatchRecords(linkedProjectId: 'project:a');

        final unlinked = await recordRepo.unlinkBatch(
          importBatchId: 'batch-1',
          updatedAt: '2026-05-21T00:00:00.000Z',
        );

        expect(unlinked, 2);
        final records = await recordRepo.listByBatchId('batch-1');
        expect(
          records.every((record) => record.linkedProjectId == null),
          isTrue,
        );
        await _expectExternalWorkSyncRows(
          db,
          records,
          operation: 'update',
          syncStatus: SyncStatus.pendingUpdate,
        );
        await _expectNoNonExternalWorkSyncRows(db);
      },
    );

    test(
      'deleteById enqueues the deleted row snapshot as pending delete',
      () async {
        final db = await _openCurrentInMemoryDb();
        final recordRepo = SqfliteExternalWorkRecordRepository();
        await _insertBatchRecords();
        final snapshot = await recordRepo.findByIdWithExecutor(
          db,
          'external-record-a',
        );

        final deleted = await recordRepo.deleteById('external-record-a');

        expect(deleted, 1);
        expect(
          await recordRepo.findByIdWithExecutor(db, 'external-record-a'),
          isNull,
        );
        expect(await recordRepo.listByBatchId('batch-1'), hasLength(1));
        await _expectExternalWorkSyncRows(
          db,
          [snapshot!],
          operation: 'delete',
          syncStatus: SyncStatus.pendingDelete,
        );
        await _expectNoNonExternalWorkSyncRows(db);
      },
    );

    test(
      'deleteByBatchId enqueues each deleted row snapshot without batch outbox',
      () async {
        final db = await _openCurrentInMemoryDb();
        final recordRepo = SqfliteExternalWorkRecordRepository();
        final snapshots = await _insertBatchRecords();

        final deleted = await recordRepo.deleteByBatchId('batch-1');

        expect(deleted, 2);
        expect(await recordRepo.listByBatchId('batch-1'), isEmpty);
        expect(await db.query('external_import_batches'), isEmpty);
        await _expectExternalWorkSyncRows(
          db,
          snapshots,
          operation: 'delete',
          syncStatus: SyncStatus.pendingDelete,
        );
        await _expectNoNonExternalWorkSyncRows(db);
      },
    );

    test(
      'linkBatchToProject rolls back row updates when update outbox fails',
      () async {
        final db = await _openCurrentInMemoryDb();
        await db.insert('projects', _project(id: 'project:a').toMap());
        await _insertBatchRecords();
        final failingRepo = SqfliteExternalWorkRecordRepository(
          syncEnqueuer: ExternalWorkSyncEnqueuer(
            syncOutboxRepository: const _ThrowingSyncOutboxRepository(
              entityType: ExternalWorkSyncEnqueuer.entityType,
              operation: 'update',
            ),
          ),
        );

        await expectLater(
          failingRepo.linkBatchToProject(
            importBatchId: 'batch-1',
            projectId: 'project:a',
            updatedAt: '2026-05-20T00:00:00.000Z',
          ),
          throwsA(isA<StateError>()),
        );

        final records = await SqfliteExternalWorkRecordRepository()
            .listByBatchId('batch-1');
        expect(
          records.every((record) => record.linkedProjectId == null),
          isTrue,
        );
        await _expectNoSyncRows(db);
      },
    );

    test('unlinkBatch rolls back row updates when update meta fails', () async {
      final db = await _openCurrentInMemoryDb();
      await db.insert('projects', _project(id: 'project:a').toMap());
      await _insertBatchRecords(linkedProjectId: 'project:a');
      final failingRepo = SqfliteExternalWorkRecordRepository(
        syncEnqueuer: ExternalWorkSyncEnqueuer(
          entitySyncMetaRepository: const _ThrowingEntitySyncMetaRepository(
            entityType: ExternalWorkSyncEnqueuer.entityType,
          ),
        ),
      );

      await expectLater(
        failingRepo.unlinkBatch(
          importBatchId: 'batch-1',
          updatedAt: '2026-05-21T00:00:00.000Z',
        ),
        throwsA(isA<StateError>()),
      );

      final records = await SqfliteExternalWorkRecordRepository().listByBatchId(
        'batch-1',
      );
      expect(records.map((record) => record.linkedProjectId).toSet(), {
        'project:a',
      });
      await _expectNoSyncRows(db);
    });

    test('deleteById rolls back deletion when delete outbox fails', () async {
      final db = await _openCurrentInMemoryDb();
      await _insertBatchRecords();
      final failingRepo = SqfliteExternalWorkRecordRepository(
        syncEnqueuer: ExternalWorkSyncEnqueuer(
          syncOutboxRepository: const _ThrowingSyncOutboxRepository(
            entityType: ExternalWorkSyncEnqueuer.entityType,
            operation: 'delete',
          ),
        ),
      );

      await expectLater(
        failingRepo.deleteById('external-record-a'),
        throwsA(isA<StateError>()),
      );

      final records = await SqfliteExternalWorkRecordRepository().listByBatchId(
        'batch-1',
      );
      expect(records.map((record) => record.id).toSet(), {
        'external-record-a',
        'external-record-b',
      });
      expect(await db.query('external_import_batches'), hasLength(1));
      await _expectNoSyncRows(db);
    });

    test(
      'deleteByBatchId rolls back records and import batch when delete meta fails',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _insertBatchRecords();
        final failingRepo = SqfliteExternalWorkRecordRepository(
          syncEnqueuer: ExternalWorkSyncEnqueuer(
            entitySyncMetaRepository: const _ThrowingEntitySyncMetaRepository(
              entityType: ExternalWorkSyncEnqueuer.entityType,
            ),
          ),
        );

        await expectLater(
          failingRepo.deleteByBatchId('batch-1'),
          throwsA(isA<StateError>()),
        );

        final records = await SqfliteExternalWorkRecordRepository()
            .listByBatchId('batch-1');
        expect(records, hasLength(2));
        expect(await db.query('external_import_batches'), hasLength(1));
        await _expectNoSyncRows(db);
      },
    );
  });

  group('importBatch-level linking', () {
    test('linkBatchToProject links every record in the batch', () async {
      final db = await _openCurrentInMemoryDb();
      final importRepo = SqfliteExternalImportRepository();
      final recordRepo = SqfliteExternalWorkRecordRepository();
      await db.insert('projects', _project(id: 'project:a').toMap());

      await importRepo.insertBatch(_batch());
      await recordRepo.insertRecords([
        _record(id: 'external-record-a', sourceRecordUuid: 'source-a'),
        _record(id: 'external-record-b', sourceRecordUuid: 'source-b'),
      ]);

      final updated = await recordRepo.linkBatchToProject(
        importBatchId: 'batch-1',
        projectId: 'project:a',
        updatedAt: '2026-05-20T00:00:00.000Z',
      );

      expect(updated, 2);
      final records = await recordRepo.listByBatchId('batch-1');
      expect(records.map((record) => record.linkedProjectId).toSet(), {
        'project:a',
      });
      expect(await recordRepo.getLinkedProjectId('batch-1'), 'project:a');
    });

    test(
      'a batch can only carry one linked project (re-link rewrites all)',
      () async {
        final db = await _openCurrentInMemoryDb();
        final importRepo = SqfliteExternalImportRepository();
        final recordRepo = SqfliteExternalWorkRecordRepository();
        await db.insert('projects', _project(id: 'project:a').toMap());
        await db.insert('projects', _project(id: 'project:b').toMap());

        await importRepo.insertBatch(_batch());
        await recordRepo.insertRecords([
          _record(id: 'external-record-a', sourceRecordUuid: 'source-a'),
          _record(id: 'external-record-b', sourceRecordUuid: 'source-b'),
        ]);

        await recordRepo.linkBatchToProject(
          importBatchId: 'batch-1',
          projectId: 'project:a',
          updatedAt: '2026-05-20T00:00:00.000Z',
        );
        await recordRepo.linkBatchToProject(
          importBatchId: 'batch-1',
          projectId: 'project:b',
          updatedAt: '2026-05-20T01:00:00.000Z',
        );

        final records = await recordRepo.listByBatchId('batch-1');
        expect(records.map((record) => record.linkedProjectId).toSet(), {
          'project:b',
        });
      },
    );

    test('one project can link multiple import batches', () async {
      final db = await _openCurrentInMemoryDb();
      final importRepo = SqfliteExternalImportRepository();
      final recordRepo = SqfliteExternalWorkRecordRepository();
      await db.insert('projects', _project(id: 'project:a').toMap());

      await importRepo.insertBatch(_batch());
      await importRepo.insertBatch(
        _batch(id: 'batch-2', sourceShareId: 'share-2'),
      );
      await recordRepo.insertRecords([
        _record(id: 'external-record-a', sourceRecordUuid: 'source-a'),
        _record(
          id: 'external-record-b',
          importBatchId: 'batch-2',
          sourceShareId: 'share-2',
          sourceRecordUuid: 'source-b',
        ),
      ]);

      await recordRepo.linkBatchToProject(
        importBatchId: 'batch-1',
        projectId: 'project:a',
        updatedAt: '2026-05-20T00:00:00.000Z',
      );
      await recordRepo.linkBatchToProject(
        importBatchId: 'batch-2',
        projectId: 'project:a',
        updatedAt: '2026-05-20T00:00:00.000Z',
      );

      final linked = await recordRepo.listByLinkedProjectId('project:a');
      expect(linked.map((record) => record.importBatchId).toSet(), {
        'batch-1',
        'batch-2',
      });
    });

    test('unlinkBatch clears link but keeps the records', () async {
      final db = await _openCurrentInMemoryDb();
      final importRepo = SqfliteExternalImportRepository();
      final recordRepo = SqfliteExternalWorkRecordRepository();
      await db.insert('projects', _project(id: 'project:a').toMap());

      await importRepo.insertBatch(_batch());
      await recordRepo.insertRecords([
        _record(id: 'external-record-a', sourceRecordUuid: 'source-a'),
        _record(id: 'external-record-b', sourceRecordUuid: 'source-b'),
      ]);
      await recordRepo.linkBatchToProject(
        importBatchId: 'batch-1',
        projectId: 'project:a',
        updatedAt: '2026-05-20T00:00:00.000Z',
      );

      final cleared = await recordRepo.unlinkBatch(
        importBatchId: 'batch-1',
        updatedAt: '2026-05-21T00:00:00.000Z',
      );

      expect(cleared, 2);
      final records = await recordRepo.listByBatchId('batch-1');
      expect(records, hasLength(2));
      expect(records.every((record) => record.linkedProjectId == null), isTrue);
      expect(await recordRepo.getLinkedProjectId('batch-1'), isNull);
    });

    test('linking one batch does not affect other batches', () async {
      final db = await _openCurrentInMemoryDb();
      final importRepo = SqfliteExternalImportRepository();
      final recordRepo = SqfliteExternalWorkRecordRepository();
      await db.insert('projects', _project(id: 'project:a').toMap());

      await importRepo.insertBatch(_batch());
      await importRepo.insertBatch(
        _batch(id: 'batch-2', sourceShareId: 'share-2'),
      );
      await recordRepo.insertRecords([
        _record(id: 'external-record-a', sourceRecordUuid: 'source-a'),
        _record(
          id: 'external-record-b',
          importBatchId: 'batch-2',
          sourceShareId: 'share-2',
          sourceRecordUuid: 'source-b',
        ),
      ]);

      await recordRepo.linkBatchToProject(
        importBatchId: 'batch-1',
        projectId: 'project:a',
        updatedAt: '2026-05-20T00:00:00.000Z',
      );

      expect(await recordRepo.getLinkedProjectId('batch-2'), isNull);
    });

    test('linkBatchToProject rejects an empty project id', () async {
      await _openCurrentInMemoryDb();
      final recordRepo = SqfliteExternalWorkRecordRepository();
      await expectLater(
        recordRepo.linkBatchToProject(
          importBatchId: 'batch-1',
          projectId: '   ',
          updatedAt: '2026-05-20T00:00:00.000Z',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'linkBatchToProject throws when batch has no records (0 rows)',
      () async {
        final db = await _openCurrentInMemoryDb();
        final recordRepo = SqfliteExternalWorkRecordRepository();
        await db.insert('projects', _project(id: 'project:a').toMap());

        await expectLater(
          recordRepo.linkBatchToProject(
            importBatchId: 'ghost-batch',
            projectId: 'project:a',
            updatedAt: '2026-05-20T00:00:00.000Z',
          ),
          throwsA(isA<ExternalWorkBatchUnavailableException>()),
        );
      },
    );

    test('unlinkBatch throws when batch has no records (0 rows)', () async {
      await _openCurrentInMemoryDb();
      final recordRepo = SqfliteExternalWorkRecordRepository();

      await expectLater(
        recordRepo.unlinkBatch(
          importBatchId: 'ghost-batch',
          updatedAt: '2026-05-20T00:00:00.000Z',
        ),
        throwsA(isA<ExternalWorkBatchUnavailableException>()),
      );
    });
  });

  group('linkBatchToProjectWithSettlementReset (atomic)', () {
    test('links batch, deletes write-offs and restores active', () async {
      final db = await _openCurrentInMemoryDb();
      final importRepo = SqfliteExternalImportRepository();
      final recordRepo = SqfliteExternalWorkRecordRepository();
      await db.insert(
        'projects',
        _project(
          id: 'project:a',
          status: ProjectStatus.settled,
          settledAt: '2026-05-19T00:00:00.000Z',
        ).toMap(),
      );
      await db.insert('project_write_offs', _writeOff('project:a').toMap());
      await importRepo.insertBatch(_batch());
      await recordRepo.insertRecords([
        _record(id: 'external-record-a', sourceRecordUuid: 'source-a'),
        _record(id: 'external-record-b', sourceRecordUuid: 'source-b'),
      ]);

      final linked = await recordRepo.linkBatchToProjectWithSettlementReset(
        importBatchId: 'batch-1',
        projectId: 'project:a',
        updatedAt: '2026-05-20T00:00:00.000Z',
      );

      expect(linked, 2);
      final records = await recordRepo.listByBatchId('batch-1');
      expect(records, hasLength(2)); // 记录保留
      expect(records.map((r) => r.linkedProjectId).toSet(), {'project:a'});
      expect(await db.query('project_write_offs'), isEmpty); // 核销删除
      final projectRows = await db.query(
        'projects',
        where: 'id = ?',
        whereArgs: ['project:a'],
      );
      expect(Project.fromMap(projectRows.single).status, ProjectStatus.active);
    });

    test(
      'restores active for a payment-only settled project (no write-offs)',
      () async {
        final db = await _openCurrentInMemoryDb();
        final importRepo = SqfliteExternalImportRepository();
        final recordRepo = SqfliteExternalWorkRecordRepository();
        await db.insert(
          'projects',
          _project(
            id: 'project:a',
            status: ProjectStatus.settled,
            settledAt: '2026-05-19T00:00:00.000Z',
          ).toMap(),
        );
        await importRepo.insertBatch(_batch());
        await recordRepo.insertRecord(_record());

        await recordRepo.linkBatchToProjectWithSettlementReset(
          importBatchId: 'batch-1',
          projectId: 'project:a',
          updatedAt: '2026-05-20T00:00:00.000Z',
        );

        final projectRows = await db.query(
          'projects',
          where: 'id = ?',
          whereArgs: ['project:a'],
        );
        expect(
          Project.fromMap(projectRows.single).status,
          ProjectStatus.active,
        );
        expect(await recordRepo.getLinkedProjectId('batch-1'), 'project:a');
      },
    );

    test(
      'rolls back settlement reset when the batch is missing (no mid-state)',
      () async {
        final db = await _openCurrentInMemoryDb();
        final recordRepo = SqfliteExternalWorkRecordRepository();
        await db.insert(
          'projects',
          _project(
            id: 'project:a',
            status: ProjectStatus.settled,
            settledAt: '2026-05-19T00:00:00.000Z',
          ).toMap(),
        );
        await db.insert('project_write_offs', _writeOff('project:a').toMap());

        await expectLater(
          recordRepo.linkBatchToProjectWithSettlementReset(
            importBatchId: 'ghost-batch',
            projectId: 'project:a',
            updatedAt: '2026-05-20T00:00:00.000Z',
          ),
          throwsA(isA<ExternalWorkBatchUnavailableException>()),
        );

        // 中间态校验：核销仍在、项目仍为已结清。
        expect(await db.query('project_write_offs'), hasLength(1));
        final projectRows = await db.query(
          'projects',
          where: 'id = ?',
          whereArgs: ['project:a'],
        );
        expect(
          Project.fromMap(projectRows.single).status,
          ProjectStatus.settled,
        );
      },
    );
  });
}

class _ThrowingSyncOutboxRepository implements SyncOutboxRepository {
  const _ThrowingSyncOutboxRepository({this.entityType, this.operation});

  final String? entityType;
  final String? operation;

  @override
  Future<SyncOutboxEntry> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    _throwIfMatched(entityType: entityType, operation: operation);
    return const LocalSyncOutboxRepository().enqueue(
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
    );
  }

  @override
  Future<SyncOutboxEntry> enqueueWithExecutor(
    DatabaseExecutor executor, {
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    _throwIfMatched(entityType: entityType, operation: operation);
    return const LocalSyncOutboxRepository().enqueueWithExecutor(
      executor,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
    );
  }

  @override
  Future<List<SyncOutboxEntry>> listPending({int limit = 50}) async {
    return const [];
  }

  void _throwIfMatched({
    required String entityType,
    required String operation,
  }) {
    final entityMatched =
        this.entityType == null || this.entityType == entityType;
    final operationMatched =
        this.operation == null || this.operation == operation;
    if (entityMatched && operationMatched) {
      throw StateError('injected sync_outbox failure');
    }
  }
}

class _ThrowingEntitySyncMetaRepository implements EntitySyncMetaRepository {
  const _ThrowingEntitySyncMetaRepository({this.entityType});

  final String? entityType;

  @override
  Future<void> upsert(EntitySyncMeta meta) {
    _throwIfMatched(meta.entityType);
    return const LocalEntitySyncMetaRepository().upsert(meta);
  }

  @override
  Future<void> upsertWithExecutor(
    DatabaseExecutor executor,
    EntitySyncMeta meta,
  ) {
    _throwIfMatched(meta.entityType);
    return const LocalEntitySyncMetaRepository().upsertWithExecutor(
      executor,
      meta,
    );
  }

  @override
  Future<EntitySyncMeta?> find({
    required String entityType,
    required String localId,
  }) async {
    return null;
  }

  void _throwIfMatched(String entityType) {
    if (this.entityType == null || this.entityType == entityType) {
      throw StateError('injected entity_sync_meta failure');
    }
  }
}

Future<List<ExternalWorkRecord>> _insertBatchRecords({
  String batchId = 'batch-1',
  String sourceShareId = 'share-1',
  String? linkedProjectId,
}) async {
  final importRepo = SqfliteExternalImportRepository();
  final recordRepo = SqfliteExternalWorkRecordRepository();
  await importRepo.insertBatch(
    _batch(id: batchId, sourceShareId: sourceShareId),
  );
  final records = [
    _record(
      id: 'external-record-a',
      importBatchId: batchId,
      sourceShareId: sourceShareId,
      sourceRecordUuid: 'source-a',
      linkedProjectId: linkedProjectId,
    ),
    _record(
      id: 'external-record-b',
      importBatchId: batchId,
      sourceShareId: sourceShareId,
      sourceRecordUuid: 'source-b',
      linkedProjectId: linkedProjectId,
    ),
  ];
  await recordRepo.insertRecords(records);
  return records;
}

Future<void> _expectExternalWorkSyncRows(
  Database db,
  Iterable<ExternalWorkRecord> records, {
  required String operation,
  required SyncStatus syncStatus,
}) async {
  final expected = records.toList(growable: false)
    ..sort((a, b) => a.id.compareTo(b.id));
  final outboxRows = await db.query(
    'sync_outbox',
    where: 'entity_type = ? AND operation = ?',
    whereArgs: [ExternalWorkSyncEnqueuer.entityType, operation],
    orderBy: 'entity_id ASC',
  );
  expect(outboxRows, hasLength(expected.length));
  _expectUniqueOutboxIds(outboxRows);

  final metaRows = await db.query(
    'entity_sync_meta',
    where: 'entity_type = ?',
    whereArgs: [ExternalWorkSyncEnqueuer.entityType],
    orderBy: 'local_id ASC',
  );
  expect(metaRows, hasLength(expected.length));

  for (final record in expected) {
    final outbox = outboxRows.singleWhere(
      (row) => row['entity_id'] == record.id,
    );
    expect(outbox['status'], SyncOutboxStatus.pending.name);
    final payload =
        jsonDecode(outbox['payload_json'] as String) as Map<String, Object?>;
    expect(payload['entity_type'], ExternalWorkSyncEnqueuer.entityType);
    expect(payload['entity_id'], record.id);
    expect(payload['operation'], operation);
    expect(payload['record'], record.toMap());

    final meta = metaRows.singleWhere((row) => row['local_id'] == record.id);
    expect(meta['sync_status'], syncStatus.name);
    expect(meta['source'], ExternalWorkSyncEnqueuer.ownerAppSource);
    expect(meta['version'], 0);
    expect(meta['payload_hash'], outbox['payload_hash']);
  }
}

Future<void> _expectNoNonExternalWorkSyncRows(Database db) async {
  expect(
    await db.query(
      'sync_outbox',
      where: 'entity_type != ?',
      whereArgs: [ExternalWorkSyncEnqueuer.entityType],
    ),
    isEmpty,
  );
}

Future<void> _expectNoSyncRows(Database db) async {
  expect(await db.query('sync_outbox'), isEmpty);
  expect(await db.query('entity_sync_meta'), isEmpty);
}

void _expectUniqueOutboxIds(List<Map<String, Object?>> rows) {
  expect(rows.map((row) => row['id']).toSet(), hasLength(rows.length));
}

ProjectWriteOff _writeOff(String projectId) {
  return ProjectWriteOff(
    id: 'writeoff-$projectId',
    projectId: projectId,
    amount: 100,
    reason: ProjectWriteOffReason.settlement.dbValue,
    writeOffDate: '2026-05-19',
    createdAt: '2026-05-19T00:00:00.000Z',
    updatedAt: '2026-05-19T00:00:00.000Z',
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

ExternalImportBatch _batch({
  String id = 'batch-1',
  String sourceShareId = 'share-1',
}) {
  return ExternalImportBatch(
    id: id,
    sourceShareId: sourceShareId,
    sourceDisplayName: '王师傅',
    recordCount: 1,
    totalHoursMilli: 1500,
    totalAmountFen: 45000,
    siteSummary: '一号工地',
    importedAt: '2026-05-18T00:00:00.000Z',
    createdAt: '2026-05-18T00:00:00.000Z',
    updatedAt: '2026-05-18T00:00:00.000Z',
  );
}

ExternalWorkRecord _record({
  String id = 'external-record-1',
  String importBatchId = 'batch-1',
  String sourceShareId = 'share-1',
  String sourceRecordUuid = 'source-record-1',
  int sourceUnitPriceFen = 30000,
  int? localUnitPriceFen,
  int projectReceivedFen = 0,
  String? linkedProjectId,
}) {
  return ExternalWorkRecord.create(
    id: id,
    importBatchId: importBatchId,
    sourceShareId: sourceShareId,
    sourceRecordUuid: sourceRecordUuid,
    sourceInstallationUuid: 'install-1',
    originFingerprint: 'fingerprint-$sourceRecordUuid',
    collaboratorName: '王师傅',
    contactSnapshot: '甲方',
    siteSnapshot: '一号工地',
    equipmentBrand: '三一',
    equipmentModel: '75',
    equipmentType: 'excavator',
    workDate: 20260518,
    hoursMilli: 1500,
    sourceUnitPriceFen: sourceUnitPriceFen,
    localUnitPriceFen: localUnitPriceFen,
    projectReceivedFen: projectReceivedFen,
    linkedProjectId: linkedProjectId,
    createdAt: '2026-05-18T00:00:00.000Z',
    updatedAt: '2026-05-18T00:00:00.000Z',
  );
}

Project _project({
  String id = 'project:linked',
  ProjectStatus status = ProjectStatus.active,
  String? settledAt,
}) {
  return Project(
    id: id,
    contact: '甲方',
    site: '一号工地',
    status: status,
    settledAt: settledAt,
    createdAt: '2026-05-18T00:00:00.000Z',
    updatedAt: '2026-05-18T00:00:00.000Z',
  );
}
