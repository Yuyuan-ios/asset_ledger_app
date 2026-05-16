import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/features/account/use_cases/create_merged_payment_use_case.dart';
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

  group('CreateMergedPaymentUseCase', () {
    test('allocates by earliest project first, not by proportion', () async {
      final repository = _RecordingPaymentRepository();
      final useCase = _useCase(repository);

      final rows = await useCase.execute(
        mergedProject: _mergedProject(remaining: 28990),
        memberProjects: [
          _memberProject(
            projectKey: '李杰||尚义',
            minYmd: 20260312,
            receivable: 6490,
            received: 5000,
            remaining: 1490,
          ),
          _memberProject(
            projectKey: '李杰||鲜滩',
            minYmd: 20260323,
            receivable: 27500,
            received: 0,
            remaining: 27500,
          ),
        ],
        ymd: 20260515,
        amount: 5000,
        note: '微信收款',
      );

      expect(repository.insertAllCalls, 1);
      expect(rows.map((row) => row.projectKey).toList(), ['李杰||尚义', '李杰||鲜滩']);
      expect(rows.map((row) => row.amount).toList(), [1490, 3510]);
      expect(rows.first.amount, isNot(closeTo(258, 1)));
      expect(rows.last.amount, isNot(closeTo(4742, 1)));
    });

    test('writes merge allocation fields and factual notes', () async {
      final repository = _RecordingPaymentRepository();
      final useCase = _useCase(repository);

      final rows = await useCase.execute(
        mergedProject: _mergedProject(remaining: 28990),
        memberProjects: [
          _memberProject(
            projectKey: '李杰||尚义',
            minYmd: 20260312,
            remaining: 1490,
          ),
          _memberProject(
            projectKey: '李杰||鲜滩',
            minYmd: 20260323,
            remaining: 27500,
          ),
        ],
        ymd: 20260515,
        amount: 5000,
        note: '微信收款',
      );

      expect(rows, hasLength(2));
      expect(
        rows.every(
          (row) =>
              row.sourceType == AccountPayment.sourceTypeMergeAllocation &&
              row.mergeGroupId == 7 &&
              row.mergeBatchId == 'batch-fixed' &&
              row.mergeBatchTotalAmount == 5000 &&
              row.mergeBatchNote == '微信收款' &&
              row.createdAt == '2026-05-16T01:02:03.000Z' &&
              row.note == '微信收款 / 合并分摊(从2026.05.15收款¥5000)',
        ),
        isTrue,
      );
      expect(rows.every((row) => row.projectKey != 'merge:7'), isTrue);
    });

    test('fails before insert when amount exceeds merged remaining', () async {
      final repository = _RecordingPaymentRepository();
      final useCase = _useCase(repository);

      await expectLater(
        useCase.execute(
          mergedProject: _mergedProject(remaining: 1000),
          memberProjects: [
            _memberProject(
              projectKey: '李杰||尚义',
              minYmd: 20260312,
              remaining: 1000,
            ),
          ],
          ymd: 20260515,
          amount: 1001,
        ),
        throwsA(isA<StateError>()),
      );

      expect(repository.insertAllCalls, 0);
      expect(repository.insertedRows, isEmpty);
    });

    test('skips members with no remaining amount', () async {
      final repository = _RecordingPaymentRepository();
      final useCase = _useCase(repository);

      final rows = await useCase.execute(
        mergedProject: _mergedProject(remaining: 5000),
        memberProjects: [
          _memberProject(projectKey: '李杰||尚义', minYmd: 20260312, remaining: 0),
          _memberProject(
            projectKey: '李杰||鲜滩',
            minYmd: 20260323,
            remaining: 5000,
          ),
        ],
        ymd: 20260515,
        amount: 5000,
      );

      expect(rows, hasLength(1));
      expect(rows.single.projectKey, '李杰||鲜滩');
      expect(rows.single.amount, 5000);
    });

    test(
      'does not create a row for the next project when prior projects close exactly',
      () async {
        final repository = _RecordingPaymentRepository();
        final useCase = _useCase(repository);

        final rows = await useCase.execute(
          mergedProject: _mergedProject(remaining: 6000),
          memberProjects: [
            _memberProject(
              projectKey: '李杰||尚义',
              minYmd: 20260312,
              remaining: 1000,
            ),
            _memberProject(
              projectKey: '李杰||鲜滩',
              minYmd: 20260323,
              remaining: 4000,
            ),
            _memberProject(
              projectKey: '李杰||高桥',
              minYmd: 20260324,
              remaining: 1000,
            ),
          ],
          ymd: 20260515,
          amount: 5000,
        );

        expect(rows.map((row) => row.projectKey).toList(), [
          '李杰||尚义',
          '李杰||鲜滩',
        ]);
        expect(rows.map((row) => row.amount).toList(), [1000, 4000]);
      },
    );

    test('allows amount to equal total remaining', () async {
      final repository = _RecordingPaymentRepository();
      final useCase = _useCase(repository);

      final rows = await useCase.execute(
        mergedProject: _mergedProject(remaining: 3000),
        memberProjects: [
          _memberProject(
            projectKey: '李杰||尚义',
            minYmd: 20260312,
            remaining: 1000,
          ),
          _memberProject(
            projectKey: '李杰||鲜滩',
            minYmd: 20260323,
            remaining: 2000,
          ),
        ],
        ymd: 20260515,
        amount: 3000,
      );

      expect(rows.map((row) => row.amount).toList(), [1000, 2000]);
    });

    test('rolls back the whole batch when a later insert fails', () async {
      final db = await _openCurrentInMemoryDb();
      await db.execute('''
        CREATE TRIGGER fail_second_allocation
        BEFORE INSERT ON account_payments
        WHEN NEW.amount = 3510
        BEGIN
          SELECT RAISE(ABORT, 'fail second allocation');
        END;
      ''');

      final useCase = _useCase(SqfliteAccountPaymentRepository());

      await expectLater(
        useCase.execute(
          mergedProject: _mergedProject(remaining: 28990),
          memberProjects: [
            _memberProject(
              projectKey: '李杰||尚义',
              minYmd: 20260312,
              remaining: 1490,
            ),
            _memberProject(
              projectKey: '李杰||鲜滩',
              minYmd: 20260323,
              remaining: 27500,
            ),
          ],
          ymd: 20260515,
          amount: 5000,
        ),
        throwsA(anything),
      );

      final rows = await db.query(
        'account_payments',
        where: 'merge_batch_id = ?',
        whereArgs: ['batch-fixed'],
      );
      expect(rows, isEmpty);
    });
  });
}

CreateMergedPaymentUseCase _useCase(AccountPaymentRepository repository) {
  return CreateMergedPaymentUseCase(
    repository: repository,
    now: () => DateTime.utc(2026, 5, 16, 1, 2, 3),
    batchIdFactory: () => 'batch-fixed',
  );
}

AccountProjectVM _mergedProject({required double remaining}) {
  return AccountProjectVM(
    projectKey: 'merge:7',
    displayName: '李杰 + 合并2项目',
    kind: AccountProjectKind.merged,
    mergeGroupId: 7,
    memberProjectKeys: const ['李杰||尚义', '李杰||鲜滩', '李杰||高桥'],
    includedSites: const ['尚义', '鲜滩', '高桥'],
    minYmd: 20260312,
    deviceIds: const [],
    hoursByDevice: const {},
    rentIncomeTotal: 0,
    minRate: null,
    isMultiDevice: false,
    isMultiMode: false,
    receivable: remaining,
    received: 0,
    remaining: remaining,
    ratio: null,
    payments: const [],
  );
}

AccountProjectVM _memberProject({
  required String projectKey,
  required int minYmd,
  double receivable = 0,
  double received = 0,
  required double remaining,
}) {
  return AccountProjectVM(
    projectKey: projectKey,
    displayName: projectKey,
    minYmd: minYmd,
    deviceIds: const [],
    hoursByDevice: const {},
    rentIncomeTotal: 0,
    minRate: null,
    isMultiDevice: false,
    isMultiMode: false,
    receivable: receivable,
    received: received,
    remaining: remaining,
    ratio: null,
    payments: const [],
  );
}

class _RecordingPaymentRepository implements AccountPaymentRepository {
  int insertAllCalls = 0;
  final insertedRows = <AccountPayment>[];

  @override
  Future<List<AccountPayment>> listAll() async => insertedRows;

  @override
  Future<int> insert(AccountPayment payment) async {
    insertedRows.add(payment.copyWith(id: insertedRows.length + 1));
    return insertedRows.length;
  }

  @override
  Future<void> insertAllInTransaction(List<AccountPayment> payments) async {
    insertAllCalls++;
    insertedRows.addAll(payments);
  }

  @override
  Future<List<AccountPayment>> listByMergeBatchId(String batchId) async {
    return insertedRows.where((row) {
      return row.sourceType == AccountPayment.sourceTypeMergeAllocation &&
          row.mergeBatchId == batchId;
    }).toList();
  }

  @override
  Future<int> deleteByMergeBatchId(String batchId) async {
    final before = insertedRows.length;
    insertedRows.removeWhere((row) {
      return row.sourceType == AccountPayment.sourceTypeMergeAllocation &&
          row.mergeBatchId == batchId;
    });
    return before - insertedRows.length;
  }

  @override
  Future<void> replaceMergeBatchInTransaction({
    required String batchId,
    required List<AccountPayment> newRows,
  }) async {
    await deleteByMergeBatchId(batchId);
    insertedRows.addAll(newRows);
  }

  @override
  Future<int> update(AccountPayment payment) async => 1;

  @override
  Future<int> deleteById(int id) async => 1;
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
