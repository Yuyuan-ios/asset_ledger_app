import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/features/account/use_cases/delete_merged_payment_batch_use_case.dart';
import 'package:asset_ledger/features/account/use_cases/update_merged_payment_batch_use_case.dart';
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

  group('UpdateMergedPaymentBatchUseCase', () {
    test('keeps batch id and reallocates by earliest project first', () async {
      final repository = _RecordingPaymentRepository(
        seed: [
          _allocation(id: 1, projectKey: '李杰||尚义', amount: 1490),
          _allocation(id: 2, projectKey: '李杰||鲜滩', amount: 3510),
        ],
      );
      final useCase = _updateUseCase(repository);

      final rows = await useCase.execute(
        mergedProject: _mergedProject(remaining: 23990),
        memberProjects: [
          _memberProject(projectKey: '李杰||尚义', minYmd: 20260312, remaining: 0),
          _memberProject(
            projectKey: '李杰||鲜滩',
            minYmd: 20260323,
            remaining: 23990,
          ),
        ],
        mergeBatchId: 'batch-fixed',
        ymd: 20260516,
        amount: 6000,
        note: '改收款',
      );

      expect(repository.replaceBatchCalls, 1);
      expect(rows.map((row) => row.projectKey).toList(), ['李杰||尚义', '李杰||鲜滩']);
      expect(rows.map((row) => row.amount).toList(), [1490, 4510]);
      expect(
        rows.every(
          (row) =>
              row.mergeBatchId == 'batch-fixed' &&
              row.mergeBatchTotalAmount == 6000 &&
              row.mergeBatchNote == '改收款' &&
              row.createdAt == '2026-05-15T01:02:03.000Z' &&
              row.note == '改收款 / 合并分摊(从2026.05.16收款¥6000)',
        ),
        isTrue,
      );
      expect(rows.every((row) => row.projectKey != 'merge:7'), isTrue);
    });

    test('keeps the original batch createdAt after edit', () async {
      final repository = _RecordingPaymentRepository(
        seed: [
          _allocation(
            id: 1,
            projectKey: '李杰||尚义',
            amount: 1490,
            createdAt: '2026-05-15T10:00:00.000Z',
          ),
          _allocation(
            id: 2,
            projectKey: '李杰||鲜滩',
            amount: 3510,
            createdAt: '2026-05-15T10:00:00.000Z',
          ),
        ],
      );
      final useCase = _updateUseCase(repository);

      final rows = await useCase.execute(
        mergedProject: _mergedProject(remaining: 23990),
        memberProjects: [
          _memberProject(projectKey: '李杰||尚义', minYmd: 20260312, remaining: 0),
          _memberProject(
            projectKey: '李杰||鲜滩',
            minYmd: 20260323,
            remaining: 23990,
          ),
        ],
        mergeBatchId: 'batch-fixed',
        ymd: 20260516,
        amount: 5000,
      );

      expect(rows.map((row) => row.createdAt).toSet(), {
        '2026-05-15T10:00:00.000Z',
      });
    });

    test(
      'uses the earliest non-empty createdAt when old rows differ',
      () async {
        final repository = _RecordingPaymentRepository(
          seed: [
            _allocation(
              id: 1,
              projectKey: '李杰||尚义',
              amount: 1490,
              createdAt: '2026-05-15T11:00:00.000Z',
            ),
            _allocation(
              id: 2,
              projectKey: '李杰||鲜滩',
              amount: 3510,
              createdAt: '2026-05-15T10:00:00.000Z',
            ),
          ],
        );
        final useCase = _updateUseCase(repository);

        final rows = await useCase.execute(
          mergedProject: _mergedProject(remaining: 23990),
          memberProjects: [
            _memberProject(
              projectKey: '李杰||尚义',
              minYmd: 20260312,
              remaining: 0,
            ),
            _memberProject(
              projectKey: '李杰||鲜滩',
              minYmd: 20260323,
              remaining: 23990,
            ),
          ],
          mergeBatchId: 'batch-fixed',
          ymd: 20260516,
          amount: 5000,
        );

        expect(rows.map((row) => row.createdAt).toSet(), {
          '2026-05-15T10:00:00.000Z',
        });
      },
    );

    test(
      'keeps createdAt null when old batch rows have no createdAt',
      () async {
        final repository = _RecordingPaymentRepository(
          seed: [
            _allocation(
              id: 1,
              projectKey: '李杰||尚义',
              amount: 1490,
              createdAt: null,
            ),
            _allocation(
              id: 2,
              projectKey: '李杰||鲜滩',
              amount: 3510,
              createdAt: null,
            ),
          ],
        );
        final useCase = _updateUseCase(repository);

        final rows = await useCase.execute(
          mergedProject: _mergedProject(remaining: 23990),
          memberProjects: [
            _memberProject(
              projectKey: '李杰||尚义',
              minYmd: 20260312,
              remaining: 0,
            ),
            _memberProject(
              projectKey: '李杰||鲜滩',
              minYmd: 20260323,
              remaining: 23990,
            ),
          ],
          mergeBatchId: 'batch-fixed',
          ymd: 20260516,
          amount: 5000,
        );

        expect(rows.every((row) => row.createdAt == null), isTrue);
      },
    );

    test(
      'fails before replace when edited amount exceeds editable remaining',
      () async {
        final repository = _RecordingPaymentRepository(
          seed: [_allocation(id: 1, projectKey: '李杰||尚义', amount: 1000)],
        );
        final useCase = _updateUseCase(repository);

        await expectLater(
          useCase.execute(
            mergedProject: _mergedProject(remaining: 500),
            memberProjects: [
              _memberProject(
                projectKey: '李杰||尚义',
                minYmd: 20260312,
                remaining: 500,
              ),
            ],
            mergeBatchId: 'batch-fixed',
            ymd: 20260516,
            amount: 1501,
          ),
          throwsA(isA<StateError>()),
        );

        expect(repository.replaceBatchCalls, 0);
      },
    );

    test(
      'rejects editing when old batch belongs to another merge group',
      () async {
        final repository = _RecordingPaymentRepository(
          seed: [
            _allocation(
              id: 1,
              projectKey: '李杰||尚义',
              amount: 1000,
              mergeGroupId: 99,
            ),
          ],
        );
        final useCase = _updateUseCase(repository);

        await expectLater(
          useCase.execute(
            mergedProject: _mergedProject(remaining: 5000),
            memberProjects: [
              _memberProject(
                projectKey: '李杰||尚义',
                minYmd: 20260312,
                remaining: 5000,
              ),
            ],
            mergeBatchId: 'batch-fixed',
            ymd: 20260516,
            amount: 1000,
          ),
          throwsA(
            predicate(
              (error) => error.toString().contains('合并状态已变化，请重新打开项目详情后再操作'),
            ),
          ),
        );

        expect(repository.replaceBatchCalls, 0);
      },
    );

    test('rolls back old rows when inserting replacement rows fails', () async {
      final db = await _openCurrentInMemoryDb();
      final repository = SqfliteAccountPaymentRepository();
      await repository.insert(
        _allocation(id: null, projectKey: '李杰||尚义', amount: 1490),
      );
      await repository.insert(
        _allocation(id: null, projectKey: '李杰||鲜滩', amount: 3510),
      );
      await db.execute('''
        CREATE TRIGGER fail_replacement_second_allocation
        BEFORE INSERT ON account_payments
        WHEN NEW.amount = 4510
        BEGIN
          SELECT RAISE(ABORT, 'fail replacement second allocation');
        END;
      ''');

      final useCase = _updateUseCase(repository);

      await expectLater(
        useCase.execute(
          mergedProject: _mergedProject(remaining: 23990),
          memberProjects: [
            _memberProject(
              projectKey: '李杰||尚义',
              minYmd: 20260312,
              remaining: 0,
            ),
            _memberProject(
              projectKey: '李杰||鲜滩',
              minYmd: 20260323,
              remaining: 23990,
            ),
          ],
          mergeBatchId: 'batch-fixed',
          ymd: 20260516,
          amount: 6000,
        ),
        throwsA(anything),
      );

      final rows = await repository.listByMergeBatchId('batch-fixed');
      expect(rows.map((row) => row.amount).toList(), [1490, 3510]);
      expect(rows.map((row) => row.ymd).toSet(), {20260515});
    });
  });

  group('DeleteMergedPaymentBatchUseCase', () {
    test(
      'deletes merge allocation rows only and keeps manual payments',
      () async {
        final db = await _openCurrentInMemoryDb();
        final repository = SqfliteAccountPaymentRepository();
        await repository.insert(
          _allocation(id: null, projectKey: '李杰||尚义', amount: 1490),
        );
        await repository.insert(
          _allocation(id: null, projectKey: '李杰||鲜滩', amount: 3510),
        );
        await db.insert(
          SqfliteAccountPaymentRepository.table,
          AccountPayment(
            projectKey: '李杰||尚义',
            ymd: 20260515,
            amount: 800,
            sourceType: AccountPayment.sourceTypeManual,
            mergeBatchId: 'batch-fixed',
          ).toMap(),
        );

        final deleted = await DeleteMergedPaymentBatchUseCase(
          repository: repository,
        ).execute(mergeBatchId: 'batch-fixed');

        expect(deleted, 2);
        expect(await repository.listByMergeBatchId('batch-fixed'), isEmpty);
        final allRows = await repository.listAll();
        expect(allRows, hasLength(1));
        expect(allRows.single.sourceType, AccountPayment.sourceTypeManual);
        expect(allRows.single.amount, 800);
      },
    );
  });
}

UpdateMergedPaymentBatchUseCase _updateUseCase(
  AccountPaymentRepository repository,
) {
  return UpdateMergedPaymentBatchUseCase(repository: repository);
}

AccountPayment _allocation({
  required int? id,
  required String projectKey,
  required double amount,
  String? createdAt = '2026-05-15T01:02:03.000Z',
  int mergeGroupId = 7,
}) {
  return AccountPayment(
    id: id,
    projectKey: projectKey,
    ymd: 20260515,
    amount: amount,
    note: '微信收款 / 合并分摊(从2026.05.15收款¥5000)',
    sourceType: AccountPayment.sourceTypeMergeAllocation,
    mergeGroupId: mergeGroupId,
    mergeBatchId: 'batch-fixed',
    mergeBatchTotalAmount: 5000,
    mergeBatchNote: '微信收款',
    createdAt: createdAt,
  );
}

AccountProjectVM _mergedProject({required double remaining}) {
  return AccountProjectVM(
    projectKey: 'merge:7',
    displayName: '李杰 + 合并2项目',
    kind: AccountProjectKind.merged,
    mergeGroupId: 7,
    memberProjectKeys: const ['李杰||尚义', '李杰||鲜滩'],
    includedSites: const ['尚义', '鲜滩'],
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
    receivable: 0,
    received: 0,
    remaining: remaining,
    ratio: null,
    payments: const [],
  );
}

class _RecordingPaymentRepository implements AccountPaymentRepository {
  _RecordingPaymentRepository({required List<AccountPayment> seed})
    : rows = List.of(seed);

  final List<AccountPayment> rows;
  int replaceBatchCalls = 0;

  @override
  Future<List<AccountPayment>> listAll() async => rows;

  @override
  Future<int> insert(AccountPayment payment) async {
    rows.add(payment);
    return rows.length;
  }

  @override
  Future<void> insertAllInTransaction(List<AccountPayment> payments) async {
    rows.addAll(payments);
  }

  @override
  Future<List<AccountPayment>> listByMergeBatchId(String batchId) async {
    return rows.where((row) {
      return row.sourceType == AccountPayment.sourceTypeMergeAllocation &&
          row.mergeBatchId == batchId;
    }).toList();
  }

  @override
  Future<int> deleteByMergeBatchId(String batchId) async {
    final before = rows.length;
    rows.removeWhere((row) {
      return row.sourceType == AccountPayment.sourceTypeMergeAllocation &&
          row.mergeBatchId == batchId;
    });
    return before - rows.length;
  }

  @override
  Future<void> replaceMergeBatchInTransaction({
    required String batchId,
    required List<AccountPayment> newRows,
  }) async {
    replaceBatchCalls++;
    await deleteByMergeBatchId(batchId);
    rows.addAll(newRows);
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
