import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
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

  group('SqfliteAccountPaymentRepository', () {
    test('insert and list preserve merge batch fields', () async {
      await _openCurrentInMemoryDb();
      final repo = SqfliteAccountPaymentRepository();

      await repo.insert(
        const AccountPayment(
          projectKey: '李杰||尚义',
          ymd: 20260515,
          amount: 1490,
          note: '合并分摊',
          sourceType: AccountPayment.sourceTypeMergeAllocation,
          mergeGroupId: 3,
          mergeBatchId: 'batch-1',
          mergeBatchTotalAmount: 5000,
          mergeBatchNote: '微信收款',
          createdAt: '2026-05-16T01:02:03.000Z',
        ),
      );

      final rows = await repo.listAll();

      expect(rows, hasLength(1));
      expect(rows.single.projectKey, '李杰||尚义');
      expect(rows.single.sourceType, AccountPayment.sourceTypeMergeAllocation);
      expect(rows.single.mergeGroupId, 3);
      expect(rows.single.mergeBatchId, 'batch-1');
      expect(rows.single.mergeBatchTotalAmount, 5000);
      expect(rows.single.mergeBatchNote, '微信收款');
      expect(rows.single.createdAt, '2026-05-16T01:02:03.000Z');
    });

    test('list sorts by ymd, createdAt, then id descending', () async {
      await _openCurrentInMemoryDb();
      final repo = SqfliteAccountPaymentRepository();

      await repo.insert(
        const AccountPayment(
          projectKey: '李杰||尚义',
          ymd: 20260514,
          amount: 100,
          createdAt: '2026-05-16T01:02:03.000Z',
        ),
      );
      await repo.insert(
        const AccountPayment(
          projectKey: '李杰||鲜滩',
          ymd: 20260515,
          amount: 200,
          createdAt: '2026-05-16T01:02:03.000Z',
        ),
      );
      await repo.insert(
        const AccountPayment(
          projectKey: '李杰||高桥',
          ymd: 20260515,
          amount: 300,
          createdAt: '2026-05-16T01:03:03.000Z',
        ),
      );
      await repo.insert(
        const AccountPayment(
          projectKey: '李杰||新村',
          ymd: 20260515,
          amount: 400,
          createdAt: '2026-05-16T01:03:03.000Z',
        ),
      );

      final rows = await repo.listAll();

      expect(rows.map((row) => row.amount).toList(), [400, 300, 200, 100]);
    });

    test('manual payment can omit merge fields', () async {
      await _openCurrentInMemoryDb();
      final repo = SqfliteAccountPaymentRepository();

      await repo.insert(
        const AccountPayment(
          projectKey: '李杰||尚义',
          ymd: 20260515,
          amount: 500,
          note: '普通收款',
        ),
      );

      final row = (await repo.listAll()).single;

      expect(row.sourceType, AccountPayment.sourceTypeManual);
      expect(row.mergeGroupId, isNull);
      expect(row.mergeBatchId, isNull);
      expect(row.mergeBatchTotalAmount, isNull);
      expect(row.mergeBatchNote, isNull);
      expect(row.createdAt, isNull);
    });

    test('batch queries and deletes only merge allocation rows', () async {
      await _openCurrentInMemoryDb();
      final repo = SqfliteAccountPaymentRepository();

      await repo.insert(_allocation(projectKey: '李杰||尚义', amount: 1000));
      await repo.insert(_allocation(projectKey: '李杰||鲜滩', amount: 500));
      await repo.insert(
        const AccountPayment(
          projectKey: '李杰||尚义',
          ymd: 20260515,
          amount: 88,
          sourceType: AccountPayment.sourceTypeManual,
          mergeBatchId: 'batch-1',
        ),
      );

      final batchRows = await repo.listByMergeBatchId('batch-1');
      expect(batchRows.map((row) => row.amount).toList(), [1000, 500]);

      final deleted = await repo.deleteByMergeBatchId('batch-1');
      expect(deleted, 2);
      expect(await repo.listByMergeBatchId('batch-1'), isEmpty);
      final allRows = await repo.listAll();
      expect(allRows, hasLength(1));
      expect(allRows.single.sourceType, AccountPayment.sourceTypeManual);
      expect(allRows.single.amount, 88);
    });

    test('replace batch validates replacement rows before writing', () async {
      await _openCurrentInMemoryDb();
      final repo = SqfliteAccountPaymentRepository();

      await expectLater(
        repo.replaceMergeBatchInTransaction(
          batchId: 'batch-1',
          newRows: const [
            AccountPayment(
              projectKey: 'merge:1',
              ymd: 20260515,
              amount: 100,
              sourceType: AccountPayment.sourceTypeMergeAllocation,
              mergeGroupId: 1,
              mergeBatchId: 'batch-1',
              mergeBatchTotalAmount: 100,
              createdAt: '2026-05-15T10:00:00.000Z',
            ),
          ],
        ),
        throwsA(isA<StateError>()),
      );

      expect(await repo.listAll(), isEmpty);
    });
  });
}

AccountPayment _allocation({
  required String projectKey,
  required double amount,
}) {
  return AccountPayment(
    projectKey: projectKey,
    ymd: 20260515,
    amount: amount,
    sourceType: AccountPayment.sourceTypeMergeAllocation,
    mergeGroupId: 1,
    mergeBatchId: 'batch-1',
    mergeBatchTotalAmount: 1500,
    mergeBatchNote: '微信收款',
    createdAt: '2026-05-15T10:00:00.000Z',
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
