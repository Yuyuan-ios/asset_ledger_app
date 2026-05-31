import 'dart:convert';

import '../../../core/operations/operation_models.dart';
import '../../../core/operations/operation_transaction_runner.dart';
import '../../../data/models/operation_audit_log.dart';
import '../../../data/repositories/operation_audit_log_repository.dart';
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
    this.auditRepository,
    this.actorType = OperationAuditActorType.owner,
    this.actorId,
    this.source = OperationAuditSource.app,
    this.now,
    this.auditIdFactory,
  });

  final SaveTimingRecordOperationAnalyzer analyzer;
  final SaveTimingRecordOperationCommand command;
  final OperationAuditLogRepository? auditRepository;
  final OperationAuditActorType actorType;
  final String? actorId;
  final OperationAuditSource source;
  final DateTime Function()? now;
  final String Function()? auditIdFactory;

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
      final staleError = _staleError(verdict.staleReasons);
      final auditOutcome = await _maybeWriteStaleAudit(
        preview: preview,
        staleReasons: verdict.staleReasons,
      );
      return OperationExecutionResult.failure(
        operationId: preview.operationId,
        operationType: OperationType.saveTimingRecord,
        affectedEntities: preview.affectedEntities,
        userMessage: _staleUserMessage,
        error: auditOutcome.error == null
            ? staleError
            : '$staleError;audit_write_failed:${auditOutcome.error}',
        auditId: auditOutcome.auditId,
      );
    }

    return command.executeConfirmedInTransaction(
      preview: preview,
      operationId: operationId,
      executeSaveWithExecutor: executeSaveWithExecutor,
    );
  }

  static const _staleUserMessage = '数据已变化，请重新预览。';

  Future<_StaleAuditOutcome> _maybeWriteStaleAudit({
    required OperationPreview preview,
    required List<SaveTimingRecordStaleReason> staleReasons,
  }) async {
    final repo = auditRepository;
    if (repo == null) {
      return const _StaleAuditOutcome._(auditId: null, error: null);
    }

    final auditId = _resolveAuditId();
    final log = OperationAuditLog(
      id: auditId,
      operationId: preview.operationId,
      operationType: OperationType.saveTimingRecord,
      actorId: actorId,
      actorType: actorType,
      source: source,
      createdAt: _resolveNow(),
      entityRefs: preview.affectedEntities,
      preview: preview,
      confirmed: true,
      result: OperationAuditResult.failure,
      errorMessage: _staleAuditErrorMessage(staleReasons),
    );

    try {
      await repo.insert(log);
      return _StaleAuditOutcome._(auditId: auditId, error: null);
    } catch (error) {
      return _StaleAuditOutcome._(auditId: null, error: error);
    }
  }

  DateTime _resolveNow() => now?.call() ?? DateTime.now();

  String _resolveAuditId() {
    final factory = auditIdFactory;
    if (factory != null) return factory();
    return 'audit-${DateTime.now().microsecondsSinceEpoch}';
  }

  static String _staleAuditErrorMessage(
    List<SaveTimingRecordStaleReason> reasons,
  ) {
    return jsonEncode({
      'code': 'preview_stale',
      'reasons': _staleReasonCodes(reasons),
    });
  }

  static String _staleError(List<SaveTimingRecordStaleReason> reasons) {
    return 'preview_stale:${_staleReasonCodes(reasons).join(',')}';
  }

  static List<String> _staleReasonCodes(
    List<SaveTimingRecordStaleReason> reasons,
  ) {
    final codes = reasons.map((reason) => reason.type.name).toList();
    return codes.isEmpty ? const ['unknown'] : List.unmodifiable(codes);
  }
}

class _StaleAuditOutcome {
  const _StaleAuditOutcome._({required this.auditId, required this.error});

  final String? auditId;
  final Object? error;
}
