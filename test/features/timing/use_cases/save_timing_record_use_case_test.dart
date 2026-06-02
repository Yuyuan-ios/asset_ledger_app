import 'package:asset_ledger/core/operations/operation_transaction_runner.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/operation_audit_log.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/operation_audit_log_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_command.dart';
import 'package:asset_ledger/features/timing/state/timing_store.dart';
import 'package:asset_ledger/features/timing/use_cases/save_timing_record_use_case.dart';
import 'package:asset_ledger/features/timing/use_cases/save_timing_record_with_impact_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

/// 阶段 C Step 1 后 [SaveTimingRecordUseCase] 是 [SaveTimingRecordWithImpactUseCase]
/// 的薄包装：
/// - 把保存请求转发给事务化路径；
/// - 事务提交后刷新 [TimingStore]；
/// - 把 [SaveTimingRecordWithImpactResult] 归一化成 UI 友好的
///   [SaveTimingRecordResult]。
///
/// 真实的事务化行为（保存计时 + 解除合并 + 撤销结清）由
/// `save_timing_record_with_impact_test.dart` 用真实 sqflite 覆盖；本测试只
/// 锁定上述薄包装层的契约。
void main() {
  group(
    'SaveTimingRecordUseCase delegates to SaveTimingRecordWithImpactUseCase',
    () {
      test('forwards the editing / record / calculationHistories arguments '
          'and reloads the timing store after the txn commits', () async {
        final timingRepository = _SpyTimingRepository();
        final timingStore = TimingStore(timingRepository);
        final withImpact = _SpyWithImpactUseCase(
          result: const SaveTimingRecordWithImpactResult(
            savedRecord: _staticSavedRecord,
            projectChanged: false,
            mergeDissolved: false,
            settlementRevoked: false,
            affectedProjectIds: ['project:alpha'],
            revokedProjectIds: [],
            userMessage: null,
          ),
        );
        final auditRepository = _FakeAuditRepository();
        final runner = await _newFakeRunner();
        final useCase = SaveTimingRecordUseCase(
          timingStore: timingStore,
          withImpact: withImpact,
          command: SaveTimingRecordOperationCommand(
            auditRepository: auditRepository,
            transactionRunner: runner,
            auditIdFactory: () => 'audit-save-1',
          ),
          operationIdFactory: () => 'op-save-1',
        );

        const editing = _staticSavedRecord;
        final newRecord = editing.copyWith(hours: 9);
        final calcHistories = [
          TimingCalculationHistory(
            id: 'history-1',
            timingRecordId: 0,
            createdAt: DateTime.utc(2026, 5, 18),
            expression: '1 * 100',
            result: 100,
            ticketCount: 1,
          ),
        ];

        final result = await useCase.execute(
          editing: editing,
          record: newRecord,
          calculationHistories: calcHistories,
        );

        // 1) Forwarded args 与原样一致。
        expect(withImpact.prepareCalls, 1);
        expect(withImpact.executeWithExecutorCalls, 1);
        expect(withImpact.directExecuteCalls, 0);
        expect(identical(withImpact.lastEditing, editing), isTrue);
        expect(identical(withImpact.lastRecord, newRecord), isTrue);
        expect(withImpact.lastCalculationHistories, calcHistories);
        expect(identical(withImpact.lastExecutor, runner.executor), isTrue);
        expect(runner.commits, 1);
        expect(runner.rollbacks, 0);

        // 2) 事务提交后刷新 store。
        expect(timingRepository.listAllCalls, 1);

        // 3) command 写入 success audit，preview snapshot 可追踪。
        expect(auditRepository.insertedWithExecutor, hasLength(1));
        final audit = auditRepository.insertedWithExecutor.single;
        expect(audit.id, 'audit-save-1');
        expect(audit.operationId, 'op-save-1');
        expect(audit.result, OperationAuditResult.success);
        expect(audit.preview?.title, '修改计时记录');
        expect(audit.preview?.summary, contains('SANY 1#'));
        expect(audit.preview?.summary, contains('甲方 · alpha'));
        expect(
          audit.entityRefs.map((ref) => ref.entityType),
          containsAll(['device', 'timing_record', 'project']),
        );

        // 4) 结果映射：mergeDissolved + 完整 impact。
        expect(result.mergeDissolved, isFalse);
        expect(identical(result.impact, withImpact.lastResult), isTrue);
      });

      test('propagates mergeDissolved=true from the impact result', () async {
        final timingRepository = _SpyTimingRepository();
        final timingStore = TimingStore(timingRepository);
        final withImpact = _SpyWithImpactUseCase(
          result: const SaveTimingRecordWithImpactResult(
            savedRecord: _staticSavedRecord,
            projectChanged: true,
            mergeDissolved: true,
            settlementRevoked: false,
            affectedProjectIds: ['project:a', 'project:b'],
            revokedProjectIds: [],
            userMessage: '已保存，已自动解除相关合并项目。',
          ),
        );
        final useCase = SaveTimingRecordUseCase(
          timingStore: timingStore,
          withImpact: withImpact,
          command: await _command(),
          operationIdFactory: () => 'op-save-merge',
        );

        final result = await useCase.execute(
          editing: _staticSavedRecord,
          record: _staticSavedRecord.copyWith(site: '工地 B'),
        );

        expect(result.mergeDissolved, isTrue);
        expect(result.impact.projectChanged, isTrue);
        expect(result.impact.affectedProjectIds, ['project:a', 'project:b']);
        expect(result.impact.userMessage, contains('解除'));
      });

      test(
        'does not reload the store when the txn throws (errors propagate)',
        () async {
          final timingRepository = _SpyTimingRepository();
          final timingStore = TimingStore(timingRepository);
          final withImpact = _SpyWithImpactUseCase(
            result: const SaveTimingRecordWithImpactResult(
              savedRecord: _staticSavedRecord,
              projectChanged: false,
              mergeDissolved: false,
              settlementRevoked: false,
              affectedProjectIds: [],
              revokedProjectIds: [],
            ),
            throwOnExecute: const TimingRecordSaveStaleException(
              '这条计时记录已不存在，请刷新后再试',
            ),
          );
          final useCase = SaveTimingRecordUseCase(
            timingStore: timingStore,
            withImpact: withImpact,
            command: await _command(),
            operationIdFactory: () => 'op-save-failure',
          );

          await expectLater(
            useCase.execute(
              editing: _staticSavedRecord,
              record: _staticSavedRecord,
            ),
            throwsA(isA<SaveTimingRecordOperationException>()),
          );
          // 事务抛错时不应再调 store.loadAll —— 让上层决定刷新策略。
          expect(timingRepository.listAllCalls, 0);
        },
      );

      test(
        'does not reload the store when audit insert fails after business save',
        () async {
          final timingRepository = _SpyTimingRepository();
          final timingStore = TimingStore(timingRepository);
          final withImpact = _SpyWithImpactUseCase(
            result: const SaveTimingRecordWithImpactResult(
              savedRecord: _staticSavedRecord,
              projectChanged: false,
              mergeDissolved: false,
              settlementRevoked: false,
              affectedProjectIds: ['project:alpha'],
              revokedProjectIds: [],
            ),
          );
          final auditRepository = _FakeAuditRepository()
            ..throwOnInsertWithExecutor = StateError('audit duplicate id');
          final useCase = SaveTimingRecordUseCase(
            timingStore: timingStore,
            withImpact: withImpact,
            command: SaveTimingRecordOperationCommand(
              auditRepository: auditRepository,
              transactionRunner: await _newFakeRunner(),
              auditIdFactory: () => 'audit-duplicate',
            ),
            operationIdFactory: () => 'op-save-audit-failure',
          );

          await expectLater(
            useCase.execute(editing: null, record: _staticSavedRecord),
            throwsA(
              isA<SaveTimingRecordOperationException>().having(
                (error) => error.error,
                'error',
                contains('audit write failed'),
              ),
            ),
          );

          expect(withImpact.executeWithExecutorCalls, 1);
          expect(timingRepository.listAllCalls, 0);
          expect(auditRepository.insertedWithExecutor, isEmpty);
        },
      );
    },
  );
}

const TimingRecord _staticSavedRecord = TimingRecord(
  id: 1,
  deviceId: 1,
  startDate: 20260518,
  projectId: 'project:alpha',
  contact: '甲方',
  site: 'alpha',
  type: TimingType.hours,
  startMeter: 0,
  endMeter: 1,
  hours: 1,
  income: 100,
);

/// 监听并断言转发参数 / 返回结果 / 异常的伪 use case；不接触 DB。
class _SpyWithImpactUseCase implements SaveTimingRecordWithImpactUseCase {
  _SpyWithImpactUseCase({required this.result, this.throwOnExecute});

  final SaveTimingRecordWithImpactResult result;
  final Object? throwOnExecute;

  int prepareCalls = 0;
  int executeWithExecutorCalls = 0;
  int directExecuteCalls = 0;
  OperationDatabaseExecutor? lastExecutor;
  TimingRecord? lastEditing;
  TimingRecord? lastRecord;
  List<TimingCalculationHistory> lastCalculationHistories = const [];
  SaveTimingRecordWithImpactResult? lastResult;

  @override
  Future<SaveTimingRecordPreparation> prepareForSave({
    required TimingRecord? editing,
    required TimingRecord record,
  }) async {
    prepareCalls += 1;
    return SaveTimingRecordPreparation(
      recordToSave: record,
      devices: const [
        Device(
          id: 1,
          name: 'SANY 1#',
          brand: 'SANY',
          defaultUnitPrice: 100,
          baseMeterHours: 0,
        ),
      ],
      rates: const [],
      timestampIso: '2026-05-30T00:00:00.000Z',
    );
  }

  @override
  Future<SaveTimingRecordWithImpactResult> executeWithExecutor(
    OperationDatabaseExecutor executor, {
    required TimingRecord? editing,
    required SaveTimingRecordPreparation preparation,
    List<TimingCalculationHistory> calculationHistories = const [],
  }) async {
    executeWithExecutorCalls += 1;
    lastExecutor = executor;
    lastEditing = editing;
    lastRecord = preparation.recordToSave;
    lastCalculationHistories = calculationHistories;
    final err = throwOnExecute;
    if (err != null) {
      throw err;
    }
    lastResult = result;
    return result;
  }

  @override
  Future<SaveTimingRecordWithImpactResult> execute({
    required TimingRecord? editing,
    required TimingRecord record,
    List<TimingCalculationHistory> calculationHistories = const [],
  }) async {
    directExecuteCalls += 1;
    lastEditing = editing;
    lastRecord = record;
    lastCalculationHistories = calculationHistories;
    final err = throwOnExecute;
    if (err != null) {
      throw err;
    }
    lastResult = result;
    return result;
  }
}

Future<SaveTimingRecordOperationCommand> _command() async {
  return SaveTimingRecordOperationCommand(
    auditRepository: _FakeAuditRepository(),
    transactionRunner: await _newFakeRunner(),
    auditIdFactory: () => 'audit-save',
  );
}

Future<_FakeTransactionRunner> _newFakeRunner() async {
  return _FakeTransactionRunner(_FakeDatabaseExecutor());
}

class _FakeTransactionRunner implements OperationTransactionRunner {
  _FakeTransactionRunner(this.executor);

  final OperationDatabaseExecutor executor;
  int commits = 0;
  int rollbacks = 0;

  @override
  Future<T> run<T>(
    Future<T> Function(OperationDatabaseExecutor executor) action,
  ) async {
    try {
      final result = await action(executor);
      commits += 1;
      return result;
    } catch (_) {
      rollbacks += 1;
      rethrow;
    }
  }
}

class _FakeDatabaseExecutor implements OperationDatabaseExecutor {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuditRepository implements OperationAuditLogRepository {
  final inserted = <OperationAuditLog>[];
  final insertedWithExecutor = <OperationAuditLog>[];
  Object? throwOnInsertWithExecutor;

  @override
  Future<void> insert(OperationAuditLog log) async {
    inserted.add(log);
  }

  @override
  Future<void> insertWithExecutor(
    OperationDatabaseExecutor executor,
    OperationAuditLog log,
  ) async {
    final error = throwOnInsertWithExecutor;
    if (error != null) throw error;
    insertedWithExecutor.add(log);
    inserted.add(log);
  }

  @override
  Future<OperationAuditLog?> findById(String id) async {
    for (final log in inserted) {
      if (log.id == id) return log;
    }
    return null;
  }

  @override
  Future<List<OperationAuditLog>> listByOperationId(String operationId) async {
    return inserted
        .where((log) => log.operationId == operationId)
        .toList(growable: false);
  }

  @override
  Future<List<OperationAuditLog>> listByTokenId(String tokenId) async {
    return inserted
        .where((log) => log.tokenId == tokenId)
        .toList(growable: false);
  }

  @override
  Future<List<OperationAuditLog>> listRecent({int limit = 50}) async {
    return inserted.take(limit).toList(growable: false);
  }
}

/// 仅为 TimingStore 提供最小 listAll；其它方法不被调用。
class _SpyTimingRepository implements TimingRepository {
  int listAllCalls = 0;

  @override
  Future<List<TimingRecord>> listAll() async {
    listAllCalls += 1;
    return const [];
  }

  @override
  Future<TimingRecord> saveWithCalculationHistories(
    TimingRecord record, {
    List<TimingCalculationHistory> calculationHistories = const [],
  }) {
    throw UnimplementedError('not used by C1 façade tests');
  }

  @override
  Future<int> insert(TimingRecord record) {
    throw UnimplementedError();
  }

  @override
  Future<int> update(TimingRecord record) {
    throw UnimplementedError();
  }

  @override
  Future<int> deleteById(int id) {
    throw UnimplementedError();
  }

  @override
  Future<int> deleteByDeviceId(int deviceId) {
    throw UnimplementedError();
  }

  @override
  Future<int> deleteByIds(Iterable<int> ids) {
    throw UnimplementedError();
  }
}
