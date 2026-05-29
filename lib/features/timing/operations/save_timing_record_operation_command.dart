import '../../../core/operations/operation_models.dart';
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

class SaveTimingRecordOperationCommand {
  const SaveTimingRecordOperationCommand();

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

  Future<OperationExecutionResult> executeConfirmed({
    required OperationPreview preview,
    required String operationId,
    required Future<SaveTimingRecordWithImpactResult> Function() executeSave,
  }) async {
    _validatePreview(preview: preview, operationId: operationId);

    try {
      final result = await executeSave();
      return OperationExecutionResult.success(
        operationId: preview.operationId,
        operationType: OperationType.saveTimingRecord,
        affectedEntities: preview.affectedEntities,
        userMessage: result.userMessage ?? '',
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
