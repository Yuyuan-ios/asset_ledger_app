import 'dart:convert';

import '../../../core/operations/operation_access_control.dart';
import '../../../core/operations/operation_actor_scope.dart';
import '../../../core/operations/operation_confirmation_token.dart';
import '../../../core/operations/operation_models.dart';
import '../../../core/operations/operation_transaction_runner.dart';
import '../../../data/models/operation_audit_log.dart';
import '../../../data/repositories/operation_audit_log_repository.dart';
import '../../../data/repositories/operation_token_repository.dart';
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
///
/// D50：新增 token-aware 入口 [executeConfirmedWithToken]。它在事务前做
/// token 校验（无状态 validator）+ freshness 校验，fresh 后把
/// `claimForConsumeWithExecutor` 包进传给 command 的 save 闭包，使
/// **token 消费 + 业务写入 + audit 写入位于同一 SQLite transaction**
/// （同 commit / 同 rollback），真正闭合跨进程一次性消费 / 防重放。
/// 不改 [SaveTimingRecordOperationCommand]，不改 audit schema。
class SaveTimingRecordOperationConfirmAdapter {
  const SaveTimingRecordOperationConfirmAdapter({
    required this.analyzer,
    required this.command,
    this.auditRepository,
    this.tokenRepository,
    this.tokenValidator = const OperationConfirmationTokenValidator(),
    this.actorType = OperationAuditActorType.owner,
    this.actorId,
    this.source = OperationAuditSource.app,
    this.now,
    this.auditIdFactory,
  });

  final SaveTimingRecordOperationAnalyzer analyzer;
  final SaveTimingRecordOperationCommand command;
  final OperationAuditLogRepository? auditRepository;
  final OperationTokenRepository? tokenRepository;
  final OperationConfirmationTokenValidator tokenValidator;
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
    _requireOperationIdMatches(operationId, preview);

    final freshnessFailure = await _freshnessFailureOrNull(
      analyzeInput: analyzeInput,
      previousAnalyzeResult: previousAnalyzeResult,
      preview: preview,
    );
    if (freshnessFailure != null) return freshnessFailure;

    return command.executeConfirmedInTransaction(
      preview: preview,
      operationId: operationId,
      executeSaveWithExecutor: executeSaveWithExecutor,
    );
  }

  /// token-aware 确认入口。
  ///
  /// 顺序：① operationId 自洽校验 → ② 读取 token record（权威来源，调用方不可
  /// 伪造 token 状态）→ ③ 无状态 validator（actor/delegated/session/scopeHash/
  /// inputHash/fullAnalysisHash/redactedPreviewHash/expiry/status）→ ④ freshness
  /// → ⑤ 事务内 claimForConsume + 业务 + audit。inputHash / fullAnalysisHash 由
  /// 本类从 analyzeInput / previousAnalyzeResult **内部计算**，调用方无法伪造。
  Future<OperationExecutionResult> executeConfirmedWithToken({
    required SaveTimingRecordOperationAnalyzeInput analyzeInput,
    required SaveTimingRecordOperationAnalyzeResult previousAnalyzeResult,
    required String operationId,
    required String tokenId,
    required ActorContext actor,
    required ActorScope scope,
    required Future<SaveTimingRecordWithImpactResult> Function(
      OperationDatabaseExecutor executor,
    )
    executeSaveWithExecutor,
    String? redactedPreviewHash,
    DateTime? now,
    String? sessionId,
  }) async {
    final preview = previousAnalyzeResult.preview;
    _requireOperationIdMatches(operationId, preview);

    final repo = tokenRepository;
    if (repo == null) {
      return _tokenFailure(preview, 'token_repository_unavailable');
    }

    final checkedNow = now ?? _resolveNow();

    final record = await repo.findById(tokenId);
    if (record == null) {
      return _tokenFailure(preview, 'token_not_found');
    }

    // 用 repository 中的权威 token，而非调用方传入。
    final token = record.token;
    final inputHash = inputHashFor(analyzeInput);
    final fullAnalysisHash = fullAnalysisHashFor(previousAnalyzeResult);

    final validation = tokenValidator.validate(
      OperationConfirmationTokenValidationInput(
        token: token,
        actor: actor,
        scope: scope,
        operationType: OperationType.saveTimingRecord,
        operationId: operationId,
        inputHash: inputHash,
        fullAnalysisHash: fullAnalysisHash,
        redactedPreviewHash: redactedPreviewHash,
        now: checkedNow,
        sessionId: sessionId,
      ),
    );
    if (!validation.isValid) {
      return _tokenFailure(
        preview,
        'token_invalid:${validation.errors.join(',')}',
      );
    }

    // stale 时不 claim token、不执行，token 保持 issued（可重新预览换新票）。
    final freshnessFailure = await _freshnessFailureOrNull(
      analyzeInput: analyzeInput,
      previousAnalyzeResult: previousAnalyzeResult,
      preview: preview,
    );
    if (freshnessFailure != null) return freshnessFailure;

    // claim 与业务、audit 同事务：claim 失败即抛错中止事务，业务不执行。
    return command.executeConfirmedInTransaction(
      preview: preview,
      operationId: operationId,
      executeSaveWithExecutor: (executor) async {
        final claimed = await repo.claimForConsumeWithExecutor(
          executor,
          id: tokenId,
          now: checkedNow,
        );
        if (!claimed) throw const _TokenClaimFailed();
        return executeSaveWithExecutor(executor);
      },
    );
  }

  /// 稳定 inputHash：绑定 analyze 输入（草稿 + 编辑目标）。供未来签发端复用同口径。
  static String inputHashFor(SaveTimingRecordOperationAnalyzeInput input) {
    return OperationConfirmationFingerprint.stableHash(
      _analyzeInputCanonicalMap(input),
    );
  }

  /// 稳定 fullAnalysisHash：绑定执行所依据的完整 analyze 结果。供未来签发端复用同口径。
  static String fullAnalysisHashFor(
    SaveTimingRecordOperationAnalyzeResult result,
  ) {
    return OperationConfirmationFingerprint.stableHash(
      _analysisCanonicalMap(result),
    );
  }

  static const _staleUserMessage = '数据已变化，请重新预览。';
  static const _tokenInvalidUserMessage = '操作凭据无效，请重新预览。';

  void _requireOperationIdMatches(String operationId, OperationPreview preview) {
    if (operationId != preview.operationId) {
      throw ArgumentError.value(
        operationId,
        'operationId',
        'Must match previousAnalyzeResult.preview.operationId',
      );
    }
  }

  OperationExecutionResult _tokenFailure(
    OperationPreview preview,
    String error,
  ) {
    return OperationExecutionResult.failure(
      operationId: preview.operationId,
      operationType: OperationType.saveTimingRecord,
      affectedEntities: preview.affectedEntities,
      userMessage: _tokenInvalidUserMessage,
      error: error,
    );
  }

  /// 共享的 freshness 闸：返回非空即为应当直接返回的 failure；返回 null 表示
  /// fresh、可继续执行。stale 时按既有语义写 stale failure audit。
  Future<OperationExecutionResult?> _freshnessFailureOrNull({
    required SaveTimingRecordOperationAnalyzeInput analyzeInput,
    required SaveTimingRecordOperationAnalyzeResult previousAnalyzeResult,
    required OperationPreview preview,
  }) async {
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
    return null;
  }

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

  // ── canonical maps for fingerprints（集合字段排序，保证口径稳定） ──

  static Map<String, Object?> _analyzeInputCanonicalMap(
    SaveTimingRecordOperationAnalyzeInput input,
  ) {
    return {
      'operation_id': input.operationId,
      'editing_record_id': input.editingRecordId,
      'draft': input.draftRecord.toMap(),
    };
  }

  static Map<String, Object?> _analysisCanonicalMap(
    SaveTimingRecordOperationAnalyzeResult result,
  ) {
    final affectedProjectIds = [...result.affectedProjectIds]..sort();
    final mergeGroupIds = [...result.mergeGroupIdsToDissolve]..sort();
    final warnings = [...result.warnings]..sort();
    final input = result.previewInput;
    return {
      'preview': result.preview.toMap(),
      'old_project_id': result.oldProjectId,
      'existing_new_project_id': result.existingNewProjectId,
      'would_create_new_project': result.wouldCreateNewProject,
      'affected_project_ids': affectedProjectIds,
      'merge_group_ids_to_dissolve': mergeGroupIds,
      'requires_reanalysis_before_execute':
          result.requiresReanalysisBeforeExecute,
      'warnings': warnings,
      'preview_input': {
        'operation_id': input.operationId,
        'is_editing': input.isEditing,
        'timing_record_id': input.timingRecordId,
        'device_label': input.deviceLabel,
        'project_label': input.projectLabel,
        'old_project_label': input.oldProjectLabel,
        'new_project_label': input.newProjectLabel,
        'project_changed': input.projectChanged,
        'will_dissolve_merge': input.willDissolveMerge,
        'will_revoke_settlement': input.willRevokeSettlement,
      },
    };
  }
}

class _StaleAuditOutcome {
  const _StaleAuditOutcome._({required this.auditId, required this.error});

  final String? auditId;
  final Object? error;
}

/// token claim 在事务内失败（已被消费 / 过期 / 取消 / 并发赢家先 claim）。
/// 抛出后由 command 的事务 catch 统一回滚并映射为 failure。
class _TokenClaimFailed implements Exception {
  const _TokenClaimFailed();

  @override
  String toString() => 'token_claim_failed';
}
