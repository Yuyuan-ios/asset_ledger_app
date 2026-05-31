import 'package:asset_ledger/core/operations/operation_models.dart';
import 'package:asset_ledger/core/operations/operation_transaction_runner.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_analyzer.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_command.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_confirm_adapter.dart';
import 'package:asset_ledger/features/timing/use_cases/save_timing_record_with_impact_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaveTimingRecordOperationConfirmAdapter', () {
    test('fresh verdict calls command and forwards execute closure', () async {
      final analyzer = _FakeAnalyzer()
        ..verdict = SaveTimingRecordFreshnessVerdict(
          isFresh: true,
          latest: _previousResult(),
          staleReasons: const [],
        );
      final command = _FakeCommand(
        result: OperationExecutionResult.success(
          operationId: 'op-save-1',
          operationType: OperationType.saveTimingRecord,
          userMessage: '已保存',
          auditId: 'audit-1',
        ),
        callExecuteClosure: true,
      );
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: analyzer,
        command: command,
      );
      var saveCalled = false;

      final result = await adapter.executeConfirmedWithFreshness(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        executeSaveWithExecutor: (_) async {
          saveCalled = true;
          return _saveResult();
        },
      );

      expect(analyzer.validateCalls, 1);
      expect(command.executeCalls, 1);
      expect(command.lastOperationId, 'op-save-1');
      expect(command.lastPreview?.operationId, 'op-save-1');
      expect(saveCalled, isTrue);
      expect(result.success, isTrue);
      expect(result.userMessage, '已保存');
      expect(result.auditId, 'audit-1');
    });

    test('stale verdict blocks command and save execution', () async {
      final analyzer = _FakeAnalyzer()
        ..verdict = const SaveTimingRecordFreshnessVerdict(
          isFresh: false,
          latest: null,
          staleReasons: [
            SaveTimingRecordStaleReason(
              type: SaveTimingRecordStaleReasonType.oldProjectChanged,
              message: '旧项目变化',
            ),
            SaveTimingRecordStaleReason(
              type: SaveTimingRecordStaleReasonType.mergeGroupsChanged,
              message: '合并组变化',
            ),
          ],
        );
      final command = _FakeCommand();
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: analyzer,
        command: command,
      );
      var saveCalled = false;

      final result = await adapter.executeConfirmedWithFreshness(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        executeSaveWithExecutor: (_) async {
          saveCalled = true;
          return _saveResult();
        },
      );

      expect(analyzer.validateCalls, 1);
      expect(command.executeCalls, 0);
      expect(saveCalled, isFalse);
      expect(result.success, isFalse);
      expect(result.userMessage, '数据已变化，请重新预览。');
      expect(result.error, contains('preview_stale'));
      expect(result.error, contains('oldProjectChanged'));
      expect(result.error, contains('mergeGroupsChanged'));
      expect(result.auditId, isNull);
    });

    test('operationId mismatch fails before analyzer and command', () async {
      final analyzer = _FakeAnalyzer();
      final command = _FakeCommand();
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: analyzer,
        command: command,
      );
      var saveCalled = false;

      await expectLater(
        adapter.executeConfirmedWithFreshness(
          analyzeInput: _analyzeInput(),
          previousAnalyzeResult: _previousResult(),
          operationId: 'op-other',
          executeSaveWithExecutor: (_) async {
            saveCalled = true;
            return _saveResult();
          },
        ),
        throwsArgumentError,
      );

      expect(analyzer.validateCalls, 0);
      expect(command.executeCalls, 0);
      expect(saveCalled, isFalse);
    });

    test(
      'analyzer failure returns failure without command execution',
      () async {
        final analyzer = _FakeAnalyzer()
          ..throwOnValidate = StateError('db busy');
        final command = _FakeCommand();
        final adapter = SaveTimingRecordOperationConfirmAdapter(
          analyzer: analyzer,
          command: command,
        );
        var saveCalled = false;

        final result = await adapter.executeConfirmedWithFreshness(
          analyzeInput: _analyzeInput(),
          previousAnalyzeResult: _previousResult(),
          operationId: 'op-save-1',
          executeSaveWithExecutor: (_) async {
            saveCalled = true;
            return _saveResult();
          },
        );

        expect(analyzer.validateCalls, 1);
        expect(command.executeCalls, 0);
        expect(saveCalled, isFalse);
        expect(result.success, isFalse);
        expect(result.userMessage, '数据已变化，请重新预览。');
        expect(result.error, contains('freshness_check_failed'));
        expect(result.error, contains('db busy'));
        expect(result.auditId, isNull);
      },
    );

    test(
      'oldRecordMissing stale is encoded as machine-readable error',
      () async {
        final analyzer = _FakeAnalyzer()
          ..verdict = const SaveTimingRecordFreshnessVerdict(
            isFresh: false,
            latest: null,
            staleReasons: [
              SaveTimingRecordStaleReason(
                type: SaveTimingRecordStaleReasonType.oldRecordMissing,
                message: '记录已不存在',
              ),
            ],
          );
        final command = _FakeCommand();
        final adapter = SaveTimingRecordOperationConfirmAdapter(
          analyzer: analyzer,
          command: command,
        );

        final result = await adapter.executeConfirmedWithFreshness(
          analyzeInput: _analyzeInput(),
          previousAnalyzeResult: _previousResult(),
          operationId: 'op-save-1',
          executeSaveWithExecutor: (_) async => _saveResult(),
        );

        expect(command.executeCalls, 0);
        expect(result.success, isFalse);
        expect(result.userMessage, '数据已变化，请重新预览。');
        expect(result.error, 'preview_stale:oldRecordMissing');
        expect(result.auditId, isNull);
      },
    );

    test('fresh path preserves command auditId', () async {
      final analyzer = _FakeAnalyzer()
        ..verdict = SaveTimingRecordFreshnessVerdict(
          isFresh: true,
          latest: _previousResult(),
          staleReasons: const [],
        );
      final command = _FakeCommand(
        result: OperationExecutionResult.success(
          operationId: 'op-save-1',
          operationType: OperationType.saveTimingRecord,
          auditId: 'audit-from-command',
        ),
      );
      final adapter = SaveTimingRecordOperationConfirmAdapter(
        analyzer: analyzer,
        command: command,
      );

      final result = await adapter.executeConfirmedWithFreshness(
        analyzeInput: _analyzeInput(),
        previousAnalyzeResult: _previousResult(),
        operationId: 'op-save-1',
        executeSaveWithExecutor: (_) async => _saveResult(),
      );

      expect(command.executeCalls, 1);
      expect(result.success, isTrue);
      expect(result.auditId, 'audit-from-command');
    });
  });
}

const _projectRef = OperationEntityRef(
  entityType: 'project',
  entityId: 'project:a',
  label: '丁队五里山',
  projectId: 'project:a',
);

SaveTimingRecordOperationAnalyzeInput _analyzeInput() {
  return const SaveTimingRecordOperationAnalyzeInput(
    operationId: 'op-save-1',
    editingRecordId: 1,
    draftRecord: TimingRecord(
      id: 1,
      deviceId: 1,
      startDate: 20260531,
      projectId: 'project:a',
      contact: '丁队',
      site: '五里山',
      type: TimingType.hours,
      startMeter: 1,
      endMeter: 8,
      hours: 7,
      income: 1400,
    ),
  );
}

SaveTimingRecordOperationAnalyzeResult _previousResult() {
  const previewInput = SaveTimingRecordOperationPreviewInput(
    operationId: 'op-save-1',
    isEditing: true,
    timingRecordId: '1',
    deviceLabel: 'Hitachi 200',
    projectLabel: '丁队五里山',
    affectedEntities: [_projectRef],
  );
  return const SaveTimingRecordOperationAnalyzeResult(
    previewInput: previewInput,
    preview: OperationPreview(
      operationId: 'op-save-1',
      operationType: OperationType.saveTimingRecord,
      title: '修改计时记录',
      summary: '编辑计时；设备：Hitachi 200；项目：丁队五里山',
      affectedEntities: [_projectRef],
      requiresConfirmation: true,
      riskLevel: OperationRiskLevel.medium,
    ),
    oldProjectId: 'project:a',
    existingNewProjectId: 'project:a',
    wouldCreateNewProject: false,
    affectedProjectIds: ['project:a'],
    mergeGroupIdsToDissolve: [],
    requiresReanalysisBeforeExecute: true,
    warnings: [],
  );
}

SaveTimingRecordWithImpactResult _saveResult({String? userMessage}) {
  return SaveTimingRecordWithImpactResult(
    savedRecord: _analyzeInput().draftRecord,
    projectChanged: false,
    mergeDissolved: false,
    settlementRevoked: false,
    affectedProjectIds: const ['project:a'],
    revokedProjectIds: const [],
    userMessage: userMessage,
  );
}

class _FakeAnalyzer extends SaveTimingRecordOperationAnalyzer {
  _FakeAnalyzer() : super(command: const SaveTimingRecordOperationCommand());

  int validateCalls = 0;
  Object? throwOnValidate;
  SaveTimingRecordFreshnessVerdict? verdict;

  @override
  Future<SaveTimingRecordFreshnessVerdict> validateFreshness({
    required SaveTimingRecordOperationAnalyzeInput input,
    required SaveTimingRecordOperationAnalyzeResult previousResult,
  }) async {
    validateCalls += 1;
    final error = throwOnValidate;
    if (error != null) throw error;
    return verdict ??
        SaveTimingRecordFreshnessVerdict(
          isFresh: true,
          latest: previousResult,
          staleReasons: const [],
        );
  }
}

class _FakeCommand extends SaveTimingRecordOperationCommand {
  _FakeCommand({this.result, this.callExecuteClosure = false});

  final OperationExecutionResult? result;
  final bool callExecuteClosure;

  int executeCalls = 0;
  OperationPreview? lastPreview;
  String? lastOperationId;

  @override
  Future<OperationExecutionResult> executeConfirmedInTransaction({
    required OperationPreview preview,
    required String operationId,
    required Future<SaveTimingRecordWithImpactResult> Function(
      OperationDatabaseExecutor executor,
    )
    executeSaveWithExecutor,
  }) async {
    executeCalls += 1;
    lastPreview = preview;
    lastOperationId = operationId;
    if (callExecuteClosure) {
      await executeSaveWithExecutor(_FakeExecutor());
    }
    return result ??
        OperationExecutionResult.success(
          operationId: preview.operationId,
          operationType: OperationType.saveTimingRecord,
          affectedEntities: preview.affectedEntities,
          userMessage: 'ok',
        );
  }
}

class _FakeExecutor implements OperationDatabaseExecutor {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
