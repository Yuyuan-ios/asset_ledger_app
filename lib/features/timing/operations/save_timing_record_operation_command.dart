import '../../../core/operations/operation_models.dart';
import '../../../core/operations/operation_transaction_runner.dart';
import '../../../data/models/operation_audit_log.dart';
import '../../../data/repositories/operation_audit_log_repository.dart';
import '../use_cases/save_timing_record_with_impact_use_case.dart';

class SaveTimingRecordOperationPreviewInput {
  const SaveTimingRecordOperationPreviewInput({
    required this.operationId,
    required this.isEditing,
    this.timingRecordId,
    required this.deviceLabel,
    required this.projectLabel,
    this.oldProjectLabel,
    this.newProjectLabel,
    this.projectChanged = false,
    this.willDissolveMerge = false,
    this.willRevokeSettlement = false,
    this.affectedEntities = const [],
    this.warnings = const [],
  });

  final String operationId;
  final bool isEditing;
  final String? timingRecordId;
  final String deviceLabel;
  final String projectLabel;
  final String? oldProjectLabel;
  final String? newProjectLabel;
  final bool projectChanged;
  final bool willDissolveMerge;
  final bool willRevokeSettlement;
  final List<OperationEntityRef> affectedEntities;
  final List<String> warnings;
}

/// 保存计时记录的 operation command。
///
/// D4：可选注入 [auditRepository]，在 executeConfirmed 成功 / 失败 / cancel 三
/// 条路径上写 append-only 审计。`auditRepository == null` 时退化为 D2 行为
/// （`auditId` 为 null），既保持向后兼容也允许未接 audit 的测试 / 早期生产路径。
///
/// 写审计失败的处理（与 prompt 一致）：
/// - 业务已经执行（成功或失败）+ audit 写入失败 → 返回 [OperationExecutionResult.failure]，
///   `userMessage` 与 `error` 明确指出"业务可能已执行，审计写入失败"，避免静默吞错。
/// - D4 仍未把审计与业务放进同一事务；这是 D5 的工作。
class SaveTimingRecordOperationCommand {
  const SaveTimingRecordOperationCommand({
    this.auditRepository,
    this.transactionRunner,
    this.actorType = OperationAuditActorType.owner,
    this.actorId,
    this.source = OperationAuditSource.app,
    this.now,
    this.auditIdFactory,
  });

  final OperationAuditLogRepository? auditRepository;
  final OperationTransactionRunner? transactionRunner;
  final OperationAuditActorType actorType;
  final String? actorId;
  final OperationAuditSource source;
  final DateTime Function()? now;
  final String Function()? auditIdFactory;

  OperationPreview preview(SaveTimingRecordOperationPreviewInput input) {
    return OperationPreview(
      operationId: input.operationId,
      operationType: OperationType.saveTimingRecord,
      title: input.isEditing ? '修改计时记录' : '保存计时记录',
      summary: _summary(input),
      warnings: input.warnings,
      affectedEntities: input.affectedEntities,
      impactItems: _impactItems(input),
      requiresConfirmation: true,
      riskLevel: input.willDissolveMerge || input.willRevokeSettlement
          ? OperationRiskLevel.high
          : OperationRiskLevel.medium,
    );
  }

  Future<OperationExecutionResult> executeConfirmedInTransaction({
    required OperationPreview preview,
    required String operationId,
    String? auditTokenId,
    required Future<SaveTimingRecordWithImpactResult> Function(
      OperationDatabaseExecutor executor,
    )
    executeSaveWithExecutor,
  }) async {
    _validatePreview(preview: preview, operationId: operationId);

    final runner = transactionRunner;
    if (runner == null) {
      throw StateError('transactionRunner is required');
    }
    final repo = auditRepository;
    if (repo == null) {
      throw StateError('auditRepository is required');
    }

    try {
      return await runner.run((executor) async {
        final businessResult = await executeSaveWithExecutor(executor);
        final auditId = _resolveAuditId();
        final log = _buildAuditLog(
          auditId: auditId,
          preview: preview,
          tokenId: auditTokenId,
          confirmed: true,
          result: OperationAuditResult.success,
          errorMessage: null,
        );
        try {
          await repo.insertWithExecutor(executor, log);
        } catch (error) {
          throw _AuditWriteFailed(error);
        }
        return OperationExecutionResult.success(
          operationId: preview.operationId,
          operationType: OperationType.saveTimingRecord,
          affectedEntities: preview.affectedEntities,
          userMessage: businessResult.userMessage ?? '',
          auditId: auditId,
        );
      });
    } on _AuditWriteFailed catch (error) {
      return OperationExecutionResult.failure(
        operationId: preview.operationId,
        operationType: OperationType.saveTimingRecord,
        affectedEntities: preview.affectedEntities,
        userMessage: '保存计时记录失败，请刷新后重试。',
        error: 'audit write failed: ${error.cause}',
      );
    } catch (error) {
      return OperationExecutionResult.failure(
        operationId: preview.operationId,
        operationType: OperationType.saveTimingRecord,
        affectedEntities: preview.affectedEntities,
        userMessage: '保存计时记录失败，请刷新后重试。',
        error: error.toString(),
      );
    }
  }

  Future<OperationExecutionResult> executeConfirmed({
    required OperationPreview preview,
    required String operationId,
    required Future<SaveTimingRecordWithImpactResult> Function() executeSave,
  }) async {
    _validatePreview(preview: preview, operationId: operationId);

    SaveTimingRecordWithImpactResult? businessResult;
    Object? businessError;
    try {
      businessResult = await executeSave();
    } catch (e) {
      businessError = e;
    }

    final auditOutcome = await _maybeWriteAudit(
      preview: preview,
      confirmed: true,
      result: businessError == null
          ? OperationAuditResult.success
          : OperationAuditResult.failure,
      errorMessage: businessError?.toString(),
    );

    if (auditOutcome.error != null) {
      // 业务已执行（成功或失败），但 audit 写入失败 → 不能假装成功。
      final auditErrorText = auditOutcome.error.toString();
      return OperationExecutionResult.failure(
        operationId: preview.operationId,
        operationType: OperationType.saveTimingRecord,
        affectedEntities: preview.affectedEntities,
        userMessage: businessError == null
            ? '操作已执行，但审计写入失败，请检查日志。'
            : '保存计时记录失败，且审计写入失败，请检查日志。',
        error: businessError == null
            ? 'audit write failed: $auditErrorText'
            : 'business: $businessError | audit: $auditErrorText',
      );
    }

    if (businessError != null) {
      return OperationExecutionResult.failure(
        operationId: preview.operationId,
        operationType: OperationType.saveTimingRecord,
        affectedEntities: preview.affectedEntities,
        userMessage: '保存计时记录失败，请刷新后重试。',
        error: businessError.toString(),
        auditId: auditOutcome.auditId,
      );
    }

    return OperationExecutionResult.success(
      operationId: preview.operationId,
      operationType: OperationType.saveTimingRecord,
      affectedEntities: preview.affectedEntities,
      userMessage: businessResult!.userMessage ?? '',
      auditId: auditOutcome.auditId,
    );
  }

  /// 用户在 confirm 步骤选择"取消"。不调用 executeSave；只写一条 cancelled
  /// 审计（如果配置了 [auditRepository]）。
  ///
  /// D1 模型没有 cancelled 语义，所以这里返回 [OperationExecutionResult.failure]
  /// + `error = reason ?? 'cancelled'`；UI 侧据此处理"用户已取消"分支。
  Future<OperationExecutionResult> cancel({
    required OperationPreview preview,
    String? reason,
  }) async {
    _validatePreview(preview: preview, operationId: preview.operationId);

    final auditOutcome = await _maybeWriteAudit(
      preview: preview,
      confirmed: false,
      result: OperationAuditResult.cancelled,
      errorMessage: reason,
    );

    if (auditOutcome.error != null) {
      return OperationExecutionResult.failure(
        operationId: preview.operationId,
        operationType: OperationType.saveTimingRecord,
        affectedEntities: preview.affectedEntities,
        userMessage: '操作已取消，但审计写入失败，请检查日志。',
        error: 'audit write failed: ${auditOutcome.error}',
      );
    }

    return OperationExecutionResult.failure(
      operationId: preview.operationId,
      operationType: OperationType.saveTimingRecord,
      affectedEntities: preview.affectedEntities,
      userMessage: '操作已取消',
      error: reason ?? 'cancelled',
      auditId: auditOutcome.auditId,
    );
  }

  Future<_AuditOutcome> _maybeWriteAudit({
    required OperationPreview preview,
    required bool confirmed,
    required OperationAuditResult result,
    required String? errorMessage,
  }) async {
    final repo = auditRepository;
    if (repo == null) return const _AuditOutcome._(auditId: null, error: null);

    final auditId = _resolveAuditId();
    final log = _buildAuditLog(
      auditId: auditId,
      preview: preview,
      confirmed: confirmed,
      result: result,
      errorMessage: errorMessage,
    );

    try {
      await repo.insert(log);
      return _AuditOutcome._(auditId: auditId, error: null);
    } catch (e) {
      return _AuditOutcome._(auditId: null, error: e);
    }
  }

  DateTime _resolveNow() => now?.call() ?? DateTime.now();

  String _resolveAuditId() {
    final factory = auditIdFactory;
    if (factory != null) return factory();
    return 'audit-${DateTime.now().microsecondsSinceEpoch}';
  }

  OperationAuditLog _buildAuditLog({
    required String auditId,
    required OperationPreview preview,
    String? tokenId,
    required bool confirmed,
    required OperationAuditResult result,
    required String? errorMessage,
  }) {
    return OperationAuditLog(
      id: auditId,
      operationId: preview.operationId,
      tokenId: tokenId,
      operationType: OperationType.saveTimingRecord,
      actorId: actorId,
      actorType: actorType,
      source: source,
      createdAt: _resolveNow(),
      entityRefs: preview.affectedEntities,
      preview: preview,
      confirmed: confirmed,
      result: result,
      errorMessage: errorMessage,
    );
  }

  static void _validatePreview({
    required OperationPreview preview,
    required String operationId,
  }) {
    if (preview.operationType != OperationType.saveTimingRecord) {
      throw ArgumentError.value(
        preview.operationType,
        'preview.operationType',
        'Expected saveTimingRecord preview',
      );
    }
    if (preview.operationId != operationId) {
      throw ArgumentError.value(
        operationId,
        'operationId',
        'Must match preview.operationId',
      );
    }
    if (!preview.requiresConfirmation) {
      throw ArgumentError.value(
        preview.requiresConfirmation,
        'preview.requiresConfirmation',
        'Save timing operation requires confirmation',
      );
    }
  }

  static List<OperationImpactItem> _impactItems(
    SaveTimingRecordOperationPreviewInput input,
  ) {
    return [
      if (input.projectChanged)
        OperationImpactItem(
          title: '项目归属将变化',
          description: _projectChangeDescription(input),
          severity: OperationImpactSeverity.warning,
          affectedEntities: input.affectedEntities,
          code: 'project_changed',
        ),
      if (input.willDissolveMerge)
        OperationImpactItem(
          title: '将自动解除相关合并项目',
          description: '保存后，受影响的合并项目会自动解除，以避免账务口径错误。',
          severity: OperationImpactSeverity.warning,
          affectedEntities: input.affectedEntities,
          code: 'merge_dissolve',
        ),
      if (input.willRevokeSettlement)
        OperationImpactItem(
          title: '将自动撤销结清状态',
          description: '保存后，受影响项目如果不再满足结清条件，会自动恢复为进行中。',
          severity: OperationImpactSeverity.warning,
          affectedEntities: input.affectedEntities,
          code: 'settlement_revoke',
        ),
    ];
  }

  static String _summary(SaveTimingRecordOperationPreviewInput input) {
    final mode = input.isEditing ? '编辑计时' : '新增计时';
    final parts = [
      mode,
      '设备：${_labelOrFallback(input.deviceLabel, '未命名设备')}',
      '项目：${_labelOrFallback(input.projectLabel, '未命名项目')}',
    ];
    if (input.projectChanged) {
      parts.add(_projectChangeDescription(input));
    }
    return parts.join('；');
  }

  static String _projectChangeDescription(
    SaveTimingRecordOperationPreviewInput input,
  ) {
    final oldLabel = _labelOrFallback(input.oldProjectLabel, '原项目');
    final newLabel = _labelOrFallback(
      input.newProjectLabel ?? input.projectLabel,
      '新项目',
    );
    return '项目归属：$oldLabel -> $newLabel';
  }

  static String _labelOrFallback(String? value, String fallback) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
  }
}

class _AuditOutcome {
  const _AuditOutcome._({required this.auditId, required this.error});
  final String? auditId;
  final Object? error;
}

class _AuditWriteFailed implements Exception {
  const _AuditWriteFailed(this.cause);

  final Object cause;
}
