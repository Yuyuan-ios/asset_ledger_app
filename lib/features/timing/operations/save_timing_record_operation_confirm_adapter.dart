import '../../../core/operations/operation_models.dart';
import '../../../core/operations/operation_transaction_runner.dart';
import '../use_cases/save_timing_record_with_impact_use_case.dart';
import 'save_timing_record_operation_analyzer.dart';
import 'save_timing_record_operation_command.dart';

/// Agent / MCP 预留的保存计时确认适配层。
///
/// 它只协调 analyzer 与 command：
/// - confirm 前先重新 validate freshness；
/// - stale preview 直接拒绝执行；
/// - fresh preview 交给 command 保持业务写入 + audit 同事务语义。
///
/// 手动保存路径不经过本适配层。
class SaveTimingRecordOperationConfirmAdapter {
  const SaveTimingRecordOperationConfirmAdapter({
    required this.analyzer,
    required this.command,
  });

  final SaveTimingRecordOperationAnalyzer analyzer;
  final SaveTimingRecordOperationCommand command;

  Future<OperationExecutionResult> executeConfirmedWithFreshness({
    required SaveTimingRecordOperationAnalyzeInput analyzeInput,
    required SaveTimingRecordOperationAnalyzeResult previousAnalyzeResult,
    required String operationId,
    required Future<SaveTimingRecordWithImpactResult> Function(
      OperationDatabaseExecutor executor,
    )
    executeSaveWithExecutor,
  }) async {
    final preview = previousAnalyzeResult.preview;
    if (operationId != preview.operationId) {
      throw ArgumentError.value(
        operationId,
        'operationId',
        'Must match previousAnalyzeResult.preview.operationId',
      );
    }

    SaveTimingRecordFreshnessVerdict verdict;
    try {
      verdict = await analyzer.validateFreshness(
        input: analyzeInput,
        previousResult: previousAnalyzeResult,
      );
    } catch (error) {
      return OperationExecutionResult.failure(
        operationId: preview.operationId,
        operationType: OperationType.saveTimingRecord,
        affectedEntities: preview.affectedEntities,
        userMessage: _staleUserMessage,
        error: 'freshness_check_failed:$error',
      );
    }

    if (!verdict.isFresh) {
      return OperationExecutionResult.failure(
        operationId: preview.operationId,
        operationType: OperationType.saveTimingRecord,
        affectedEntities: preview.affectedEntities,
        userMessage: _staleUserMessage,
        error: _staleError(verdict.staleReasons),
      );
    }

    return command.executeConfirmedInTransaction(
      preview: preview,
      operationId: operationId,
      executeSaveWithExecutor: executeSaveWithExecutor,
    );
  }

  static const _staleUserMessage = '数据已变化，请重新预览。';

  static String _staleError(List<SaveTimingRecordStaleReason> reasons) {
    final codes = reasons.map((reason) => reason.type.name).join(',');
    return 'preview_stale:${codes.isEmpty ? 'unknown' : codes}';
  }
}
