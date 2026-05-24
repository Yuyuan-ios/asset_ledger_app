import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/external_import_batch.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/repositories/external_import_repository.dart';
import 'package:asset_ledger/data/repositories/external_work_record_repository.dart';
import 'package:asset_ledger/features/timing/state/timing_external_work_store.dart';
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

  group('TimingExternalWorkStore batch linking', () {
    late SqfliteExternalImportRepository importRepo;
    late SqfliteExternalWorkRecordRepository recordRepo;
    late TimingExternalWorkStore store;

    Future<void> seed() async {
      final db = await _openCurrentInMemoryDb();
      importRepo = SqfliteExternalImportRepository();
      recordRepo = SqfliteExternalWorkRecordRepository();
      store = TimingExternalWorkStore(
        importRepository: importRepo,
        recordRepository: recordRepo,
      );
      await db.insert('projects', _project(id: 'project:a').toMap());
      await importRepo.insertBatch(_batch());
      await recordRepo.insertRecords([
        _record(id: 'external-record-a', sourceRecordUuid: 'source-a'),
        _record(id: 'external-record-b', sourceRecordUuid: 'source-b'),
      ]);
      await store.loadAll();
    }

    test('linkBatchToProject writes link and flips items to linked', () async {
      await seed();
      expect(store.items.every((item) => !item.isLinked), isTrue);

      await store.linkBatchToProject('batch-1', 'project:a');

      expect(store.items, hasLength(2));
      expect(store.items.every((item) => item.isLinked), isTrue);
      expect(
        store.items.map((item) => item.record.linkedProjectId).toSet(),
        {'project:a'},
      );
      // Persisted, not just in-memory.
      expect(await recordRepo.getLinkedProjectId('batch-1'), 'project:a');
    });

    test('unlinkBatch clears link but keeps records', () async {
      await seed();
      await store.linkBatchToProject('batch-1', 'project:a');

      await store.unlinkBatch('batch-1');

      expect(store.items, hasLength(2));
      expect(store.items.every((item) => !item.isLinked), isTrue);
      expect(await recordRepo.getLinkedProjectId('batch-1'), isNull);
      expect(await recordRepo.listByBatchId('batch-1'), hasLength(2));
    });

    test('linking a missing project surfaces a store failure', () async {
      await seed();

      await expectLater(
        store.linkBatchToProject('batch-1', 'project:missing'),
        throwsA(isA<Object>()),
      );
      expect(store.failure, isNotNull);
      // Items remain unlinked because the FK write was rejected.
      expect(store.items.every((item) => !item.isLinked), isTrue);
    });
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

ExternalImportBatch _batch({String id = 'batch-1', String sourceShareId = 'share-1'}) {
  return ExternalImportBatch(
    id: id,
    sourceShareId: sourceShareId,
    sourceDisplayName: '王师傅',
    recordCount: 2,
    totalHoursMilli: 3000,
    totalAmountFen: 90000,
    siteSummary: '一号工地',
    importedAt: '2026-05-18T00:00:00.000Z',
    createdAt: '2026-05-18T00:00:00.000Z',
    updatedAt: '2026-05-18T00:00:00.000Z',
  );
}

ExternalWorkRecord _record({
  required String id,
  required String sourceRecordUuid,
  String importBatchId = 'batch-1',
  String sourceShareId = 'share-1',
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
    sourceUnitPriceFen: 30000,
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
