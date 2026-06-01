import '../../../core/operations/operation_access_control.dart';
import '../../../core/operations/operation_models.dart';
import 'save_timing_record_operation_analyzer.dart';
import 'save_timing_record_operation_command.dart';
import 'save_timing_record_operation_preview_adapter.dart';

/// 阶段 D Step 25：保存计时预览的脱敏投影。
///
/// 这是一个**只读 helper**：把 D20 的 [SaveTimingRecordOperationPreviewResponse]
/// 按 [ActorContext] + D23 的 [OperationVisibilityPolicy] 投影成一份对外可展示的
/// [RedactedSaveTimingRecordPreview]。
///
/// 严格约束：
/// - **不修改**入参 response（owner 侧保留完整保真度）。
/// - 不写 DB、不写审计、不执行 execute、不接 UI / MCP / outbox。
/// - 返回的脱敏投影**不是执行凭据**：真正用于 confirm / freshness 复核的
///   [SaveTimingRecordOperationAnalyzeResult] 仍留在 owner 侧，绝不可拿脱敏结果
///   去 execute。
///
/// 投影分三档（由 visibility policy 推导，不直接看 actorType）：
/// - full：能看见 projectLabel + financialAmount（即 owner / agent-as-owner）→ 直通。
/// - partial：看不见项目 / 财务，但能看见设备（driver / partner / 受委托 agent）
///   → 脱敏项目 / 联系人 / 工地 / 财务 / 内部 ID，合并影响泛化。
/// - none：什么都看不见（无委托 scope 的 agent / system / unknown）→ 最小空壳。
class SaveTimingRecordPreviewRedactor {
  const SaveTimingRecordPreviewRedactor({
    this.visibilityPolicy = const OperationVisibilityPolicy(),
  });

  final OperationVisibilityPolicy visibilityPolicy;

  RedactedSaveTimingRecordPreview redact({
    required SaveTimingRecordOperationPreviewResponse response,
    required ActorContext actor,
  }) {
    bool sees(OperationVisibilityCapability capability) =>
        visibilityPolicy.canSee(actor: actor, capability: capability).visible;

    final visible = <OperationVisibilityCapability>[];
    final hidden = <OperationVisibilityCapability>[];
    for (final capability in OperationVisibilityCapability.values) {
      (sees(capability) ? visible : hidden).add(capability);
    }

    final seesProject =
        sees(OperationVisibilityCapability.projectLabel) &&
        sees(OperationVisibilityCapability.contactSite);
    final seesFinance = sees(OperationVisibilityCapability.financialAmount);
    final seesDevice = sees(OperationVisibilityCapability.deviceName);

    final _Mode mode;
    if (seesProject && seesFinance) {
      mode = _Mode.full;
    } else if (seesDevice) {
      mode = _Mode.partial;
    } else {
      mode = _Mode.none;
    }

    switch (mode) {
      case _Mode.full:
        return _passthrough(response, visible, hidden);
      case _Mode.partial:
        return _partial(response, visible, hidden);
      case _Mode.none:
        return _none(response, visible, hidden);
    }
  }

  // ── full（owner / agent-as-owner）：直通，不脱敏 ─────────────────────────────

  RedactedSaveTimingRecordPreview _passthrough(
    SaveTimingRecordOperationPreviewResponse response,
    List<OperationVisibilityCapability> visible,
    List<OperationVisibilityCapability> hidden,
  ) {
    final analysis = response.analysis;
    return RedactedSaveTimingRecordPreview(
      preview: response.preview,
      analysis: RedactedSaveTimingRecordAnalysis(
        wouldCreateNewProject: analysis.wouldCreateNewProject,
        willDissolveMerge: analysis.previewInput.willDissolveMerge,
        willRevokeSettlement: analysis.previewInput.willRevokeSettlement,
        oldProjectId: analysis.oldProjectId,
        existingNewProjectId: analysis.existingNewProjectId,
        affectedProjectIds: List.unmodifiable(analysis.affectedProjectIds),
        mergeGroupIdsToDissolve: List.unmodifiable(
          analysis.mergeGroupIdsToDissolve,
        ),
        warnings: List.unmodifiable(analysis.warnings),
      ),
      freshness: _passthroughFreshness(response.freshness),
      redacted: false,
      redactionReasons: const [],
      visibleCapabilities: List.unmodifiable(visible),
      hiddenCapabilities: List.unmodifiable(hidden),
    );
  }

  RedactedSaveTimingRecordFreshness? _passthroughFreshness(
    SaveTimingRecordFreshnessVerdict? freshness,
  ) {
    if (freshness == null) return null;
    return RedactedSaveTimingRecordFreshness(
      isFresh: freshness.isFresh,
      staleReasons: List.unmodifiable([
        for (final reason in freshness.staleReasons)
          RedactedStaleReason(
            type: reason.type,
            message: reason.message,
            previousValue: reason.previousValue,
            latestValue: reason.latestValue,
          ),
      ]),
    );
  }

  // ── partial（driver / partner / 受委托 agent）：脱敏 ───────────────────────

  RedactedSaveTimingRecordPreview _partial(
    SaveTimingRecordOperationPreviewResponse response,
    List<OperationVisibilityCapability> visible,
    List<OperationVisibilityCapability> hidden,
  ) {
    final analysis = response.analysis;
    final input = analysis.previewInput;
    final willDissolveMerge = input.willDissolveMerge;

    final safeWarnings = _safeWarnings(willDissolveMerge: willDissolveMerge);

    final redactedPreview = OperationPreview(
      operationId: response.preview.operationId,
      operationType: response.preview.operationType,
      title: response.preview.title,
      summary: _safeSummary(input),
      warnings: safeWarnings,
      affectedEntities: _deviceOnlyEntities(response.preview.affectedEntities),
      impactItems: _genericImpactItems(willDissolveMerge: willDissolveMerge),
      requiresConfirmation: response.preview.requiresConfirmation,
      // D26.5：非 owner 一律归一化为 medium（save 基线）。上游
      // command.preview 把 willRevokeSettlement || willDissolveMerge 映射成
      // high；若原样透传，driver/partner/无 scope agent 可仅凭 riskLevel=high
      // 反推出被隐藏的撤销结清 / 合并结构状态。owner 直通档不经过此处。
      riskLevel: OperationRiskLevel.medium,
    );

    return RedactedSaveTimingRecordPreview(
      preview: redactedPreview,
      analysis: RedactedSaveTimingRecordAnalysis(
        // 内部 ID / 财务 / "是否新建项目" 一律隐藏；仅保留泛化的合并结构标志。
        wouldCreateNewProject: null,
        willDissolveMerge: willDissolveMerge,
        willRevokeSettlement: null,
        oldProjectId: null,
        existingNewProjectId: null,
        affectedProjectIds: const [],
        mergeGroupIdsToDissolve: const [],
        warnings: safeWarnings,
      ),
      freshness: _typeOnlyFreshness(response.freshness),
      redacted: true,
      redactionReasons: _redactionReasons(),
      visibleCapabilities: List.unmodifiable(visible),
      hiddenCapabilities: List.unmodifiable(hidden),
    );
  }

  // ── none（无委托 scope 的 agent / system / unknown）：最小空壳 ──────────────

  RedactedSaveTimingRecordPreview _none(
    SaveTimingRecordOperationPreviewResponse response,
    List<OperationVisibilityCapability> visible,
    List<OperationVisibilityCapability> hidden,
  ) {
    final shell = OperationPreview(
      operationId: response.preview.operationId,
      operationType: response.preview.operationType,
      title: response.preview.title,
      summary: '',
      warnings: const [],
      affectedEntities: const [],
      impactItems: const [],
      requiresConfirmation: response.preview.requiresConfirmation,
      // D26.5：非 owner 一律归一化为 medium（save 基线）。上游
      // command.preview 把 willRevokeSettlement || willDissolveMerge 映射成
      // high；若原样透传，driver/partner/无 scope agent 可仅凭 riskLevel=high
      // 反推出被隐藏的撤销结清 / 合并结构状态。owner 直通档不经过此处。
      riskLevel: OperationRiskLevel.medium,
    );

    return RedactedSaveTimingRecordPreview(
      preview: shell,
      analysis: const RedactedSaveTimingRecordAnalysis(
        wouldCreateNewProject: null,
        willDissolveMerge: false,
        willRevokeSettlement: null,
        oldProjectId: null,
        existingNewProjectId: null,
        affectedProjectIds: [],
        mergeGroupIdsToDissolve: [],
        warnings: [],
      ),
      freshness: _typeOnlyFreshness(response.freshness),
      redacted: true,
      redactionReasons: const ['无委托范围，全部隐藏'],
      visibleCapabilities: List.unmodifiable(visible),
      hiddenCapabilities: List.unmodifiable(hidden),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  /// 非 owner 的 freshness：只保留 stale reason 的 type，丢弃可能含内部 ID /
  /// 标签的 message / previousValue / latestValue。
  RedactedSaveTimingRecordFreshness? _typeOnlyFreshness(
    SaveTimingRecordFreshnessVerdict? freshness,
  ) {
    if (freshness == null) return null;
    return RedactedSaveTimingRecordFreshness(
      isFresh: freshness.isFresh,
      staleReasons: List.unmodifiable([
        for (final reason in freshness.staleReasons)
          RedactedStaleReason(type: reason.type),
      ]),
    );
  }

  /// 仅基于设备名（visible 能力）重建 summary，移除项目 / 联系人 / 工地段。
  String _safeSummary(SaveTimingRecordOperationPreviewInput input) {
    final mode = input.isEditing ? '编辑计时' : '新增计时';
    final device = input.deviceLabel.trim();
    final deviceText = device.isEmpty ? '未命名设备' : device;
    return '$mode；设备：$deviceText';
  }

  /// 与 raw warnings 解耦的安全告警集合，避免泄漏财务 / 项目 / 内部 ID。
  List<String> _safeWarnings({required bool willDissolveMerge}) {
    return List.unmodifiable([
      '预览基于当前本地数据，执行前必须重新分析确认。',
      if (willDissolveMerge) '可能影响项目结构，需老板确认。',
    ]);
  }

  /// 仅保留 device 实体，并把内部标识替换为不可逆占位；删除项目 / 合并组 / 记录实体。
  List<OperationEntityRef> _deviceOnlyEntities(
    List<OperationEntityRef> entities,
  ) {
    return List.unmodifiable([
      for (final entity in entities)
        if (entity.entityType == 'device')
          OperationEntityRef(
            entityType: 'device',
            entityId: 'device:hidden',
            label: entity.label,
          ),
    ]);
  }

  /// 删除结清 / 项目变更影响；合并影响泛化为「可能影响项目结构」。
  List<OperationImpactItem> _genericImpactItems({
    required bool willDissolveMerge,
  }) {
    return List.unmodifiable([
      if (willDissolveMerge)
        const OperationImpactItem(
          title: '可能影响项目结构',
          description: '该操作可能影响项目合并关系，需老板确认。',
          severity: OperationImpactSeverity.warning,
          code: 'project_structure',
        ),
    ]);
  }

  List<String> _redactionReasons() {
    return const [
      '项目 / 联系人 / 工地信息已隐藏',
      '财务相关信息已隐藏',
      '内部标识已剥离',
    ];
  }
}

enum _Mode { full, partial, none }

/// 脱敏后的保存计时预览投影。对外展示用，**不是执行凭据**。
class RedactedSaveTimingRecordPreview {
  const RedactedSaveTimingRecordPreview({
    required this.preview,
    required this.analysis,
    required this.freshness,
    required this.redacted,
    required this.redactionReasons,
    required this.visibleCapabilities,
    required this.hiddenCapabilities,
  });

  final OperationPreview preview;
  final RedactedSaveTimingRecordAnalysis analysis;
  final RedactedSaveTimingRecordFreshness? freshness;
  final bool redacted;
  final List<String> redactionReasons;
  final List<OperationVisibilityCapability> visibleCapabilities;
  final List<OperationVisibilityCapability> hiddenCapabilities;

  Map<String, Object?> toMap() {
    return {
      'preview': preview.toMap(),
      'analysis': analysis.toMap(),
      'freshness': freshness?.toMap(),
      'redacted': redacted,
      'redaction_reasons': List<String>.from(redactionReasons),
      'visible_capabilities': [
        for (final c in visibleCapabilities) c.wireName,
      ],
      'hidden_capabilities': [
        for (final c in hiddenCapabilities) c.wireName,
      ],
    };
  }
}

/// analyze 结果的脱敏投影。内部 ID / 财务字段对非 owner 为 null / 空。
class RedactedSaveTimingRecordAnalysis {
  const RedactedSaveTimingRecordAnalysis({
    required this.wouldCreateNewProject,
    required this.willDissolveMerge,
    required this.willRevokeSettlement,
    required this.oldProjectId,
    required this.existingNewProjectId,
    required this.affectedProjectIds,
    required this.mergeGroupIdsToDissolve,
    required this.warnings,
  });

  /// 是否会新建项目；非 owner 为 null（隐藏）。
  final bool? wouldCreateNewProject;

  /// 是否会解除合并；非 owner 仍保留布尔（用于渲染泛化结构提示），但不暴露组成员。
  final bool willDissolveMerge;

  /// 是否会撤销结清（财务信号）；非 owner 为 null（隐藏）。
  final bool? willRevokeSettlement;

  final String? oldProjectId;
  final String? existingNewProjectId;
  final List<String> affectedProjectIds;
  final List<int> mergeGroupIdsToDissolve;
  final List<String> warnings;

  Map<String, Object?> toMap() {
    return {
      'would_create_new_project': wouldCreateNewProject,
      'will_dissolve_merge': willDissolveMerge,
      'will_revoke_settlement': willRevokeSettlement,
      'old_project_id': oldProjectId,
      'existing_new_project_id': existingNewProjectId,
      'affected_project_ids': List<String>.from(affectedProjectIds),
      'merge_group_ids_to_dissolve': List<int>.from(mergeGroupIdsToDissolve),
      'warnings': List<String>.from(warnings),
    };
  }
}

/// freshness 的脱敏投影。
class RedactedSaveTimingRecordFreshness {
  const RedactedSaveTimingRecordFreshness({
    required this.isFresh,
    required this.staleReasons,
  });

  final bool isFresh;
  final List<RedactedStaleReason> staleReasons;

  Map<String, Object?> toMap() {
    return {
      'is_fresh': isFresh,
      'stale_reasons': [for (final r in staleReasons) r.toMap()],
    };
  }
}

/// stale reason 的脱敏投影。非 owner 仅保留 [type]。
class RedactedStaleReason {
  const RedactedStaleReason({
    required this.type,
    this.message,
    this.previousValue,
    this.latestValue,
  });

  final SaveTimingRecordStaleReasonType type;
  final String? message;
  final Object? previousValue;
  final Object? latestValue;

  Map<String, Object?> toMap() {
    return {
      'type': type.name,
      'message': message,
      'previous_value': previousValue,
      'latest_value': latestValue,
    };
  }
}
