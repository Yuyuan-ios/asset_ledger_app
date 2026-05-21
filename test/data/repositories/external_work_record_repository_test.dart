import 'package:asset_ledger/core/money/amount_policy.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/external_import_batch.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/repositories/external_import_repository.dart';
import 'package:asset_ledger/data/repositories/external_work_record_repository.dart';
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

Project _project({String id = 'project:linked'}) {
  return Project(
    id: id,
    contact: '甲方',
    site: '一号工地',
    createdAt: '2026-05-18T00:00:00.000Z',
    updatedAt: '2026-05-18T00:00:00.000Z',
  );
}
