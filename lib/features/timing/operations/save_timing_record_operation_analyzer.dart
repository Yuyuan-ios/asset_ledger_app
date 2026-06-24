import '../../../core/operations/operation_models.dart';
import '../../../data/models/account_project_merge_member.dart';
import '../../../data/models/device.dart';
import '../../../data/models/project.dart';
import '../../../data/models/project_device_rate.dart';
import '../../../data/models/timing_record.dart';
import '../../../data/repositories/account_project_merge_repository.dart';
import '../../../data/repositories/account_payment_repository.dart';
import '../../../data/repositories/device_repository.dart';
import '../../../data/repositories/project_rate_repository.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/project_write_off_repository.dart';
import '../../../data/repositories/timing_repository.dart';
import '../../../data/services/account_service.dart';
import '../../account/domain/services/project_finance_calculator.dart';
import '../../../infrastructure/local/account/project_settlement_impact_service.dart';
import '../use_cases/save_timing_record_allocation_cutoff_validator.dart';
import 'save_timing_record_operation_command.dart';

class SaveTimingRecordOperationAnalyzeInput {
  const SaveTimingRecordOperationAnalyzeInput({
    required this.operationId,
    required this.draftRecord,
    this.editingRecordId,
  });

  final String operationId;
  final TimingRecord draftRecord;
  final int? editingRecordId;
}

class SaveTimingRecordOperationAnalyzeResult {
  const SaveTimingRecordOperationAnalyzeResult({
    required this.previewInput,
    required this.preview,
    required this.oldProjectId,
    required this.existingNewProjectId,
    required this.wouldCreateNewProject,
    required this.affectedProjectIds,
    required this.mergeGroupIdsToDissolve,
    required this.requiresReanalysisBeforeExecute,
    required this.warnings,
  });

  final SaveTimingRecordOperationPreviewInput previewInput;
  final OperationPreview preview;
  final String? oldProjectId;
  final String? existingNewProjectId;
  final bool wouldCreateNewProject;
  final List<String> affectedProjectIds;
  final List<int> mergeGroupIdsToDissolve;
  final bool requiresReanalysisBeforeExecute;
  final List<String> warnings;
}

class SaveTimingRecordAnalyzeException implements Exception {
  const SaveTimingRecordAnalyzeException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() {
    final suffix = code == null ? '' : ' ($code)';
    return 'SaveTimingRecordAnalyzeException: $message$suffix';
  }
}

/// 预览过期原因。语义对应 D13 审计列出的关键状态漂移点。
enum SaveTimingRecordStaleReasonType {
  /// 重新 analyze 时旧 timing record 已不存在（或 analyzer 抛出 stale 异常）。
  oldRecordMissing,

  /// 旧 timing record 仍存在但归属的 oldProjectId 已变化。
  oldProjectChanged,

  /// 目标项目（existingNewProjectId）变化：另一条 active project 出现 / 消失 / 改名。
  targetProjectChanged,

  /// 是否会创建新项目的判断发生反转。
  wouldCreateNewProjectChanged,

  /// 受影响项目集合（含解除合并组带入的成员）变化。
  affectedProjectIdsChanged,

  /// 受影响合并组集合变化（dissolve、新建、成员变更等）。
  mergeGroupsChanged,

  /// previewInput.willDissolveMerge 发生反转。
  willDissolveMergeChanged,

  /// previewInput.willRevokeSettlement 发生反转。
  willRevokeSettlementChanged,

  /// preview.riskLevel 变化。
  riskLevelChanged,

  /// 警告集合（previewInput.warnings）变化。
  warningsChanged,
}

class SaveTimingRecordStaleReason {
  const SaveTimingRecordStaleReason({
    required this.type,
    required this.message,
    this.previousValue,
    this.latestValue,
  });

  final SaveTimingRecordStaleReasonType type;
  final String message;
  final Object? previousValue;
  final Object? latestValue;

  @override
  String toString() {
    return 'SaveTimingRecordStaleReason(${type.name}: $message; '
        'previous=$previousValue, latest=$latestValue)';
  }
}

/// validateFreshness 的判定结果。
///
/// - [isFresh] 为 true 时 [staleReasons] 必为空。
/// - [isFresh] 为 false 时 [staleReasons] 至少包含一条原因。
/// - [latest] 在重新 analyze 抛出 [SaveTimingRecordAnalyzeException] 时为 null
///   （例如旧 record 已删除）；其它情况下为最新 analyze 结果。
class SaveTimingRecordFreshnessVerdict {
  const SaveTimingRecordFreshnessVerdict({
    required this.isFresh,
    required this.latest,
    required this.staleReasons,
  });

  final bool isFresh;
  final SaveTimingRecordOperationAnalyzeResult? latest;
  final List<SaveTimingRecordStaleReason> staleReasons;
}

class SaveTimingRecordOperationAnalyzer {
  SaveTimingRecordOperationAnalyzer({
    required SaveTimingRecordOperationCommand command,
    SqfliteTimingRepository? timingRepository,
    SqfliteAccountProjectMergeRepository? mergeRepository,
    SqfliteProjectRepository? projectRepository,
    DeviceRepository? deviceRepository,
    ProjectRateRepository? projectRateRepository,
    SqfliteAccountPaymentRepository? accountPaymentRepository,
    SqfliteProjectWriteOffRepository? writeOffRepository,
  }) : _command = command,
       _timingRepository = timingRepository ?? SqfliteTimingRepository(),
       _mergeRepository =
           mergeRepository ?? SqfliteAccountProjectMergeRepository(),
       _projectRepository = projectRepository ?? SqfliteProjectRepository(),
       _deviceRepository = deviceRepository ?? SqfliteDeviceRepository(),
       _projectRateRepository =
           projectRateRepository ?? SqfliteProjectRateRepository(),
       _accountPaymentRepository =
           accountPaymentRepository ?? SqfliteAccountPaymentRepository(),
       _writeOffRepository =
           writeOffRepository ?? const SqfliteProjectWriteOffRepository();

  final SaveTimingRecordOperationCommand _command;
  final SqfliteTimingRepository _timingRepository;
  final SqfliteAccountProjectMergeRepository _mergeRepository;
  final SqfliteProjectRepository _projectRepository;
  final DeviceRepository _deviceRepository;
  final ProjectRateRepository _projectRateRepository;
  final SqfliteAccountPaymentRepository _accountPaymentRepository;
  final SqfliteProjectWriteOffRepository _writeOffRepository;

  Future<SaveTimingRecordOperationAnalyzeResult> analyze(
    SaveTimingRecordOperationAnalyzeInput input,
  ) async {
    final devices = await _deviceRepository.listAll();
    final rates = await _projectRateRepository.listAll();
    final draft = input.draftRecord;

    final oldRecord = await _readOldRecord(input.editingRecordId);
    await _validateAllocationCutoff(
      draft: draft,
      editingRecordId: input.editingRecordId,
    );
    final oldProjectId = _trimToNull(oldRecord?.effectiveProjectId);
    final target = await _resolveTargetProject(
      draft: draft,
      oldRecord: oldRecord,
    );
    final targetProjectId = _trimToNull(target.existingProject?.id);
    final projectChanged =
        oldProjectId != null &&
        targetProjectId != null &&
        oldProjectId != targetProjectId;

    final affectedProjectIds = <String>{?oldProjectId, ?targetProjectId};
    final mergeGroupIds = <int>{};
    final affectedEntities = <OperationEntityRef>[];
    final warnings = <String>[];

    _addEntity(
      affectedEntities,
      OperationEntityRef(
        entityType: 'device',
        entityId: draft.deviceId.toString(),
        label: _deviceLabel(devices, draft.deviceId),
        deviceId: draft.deviceId.toString(),
      ),
    );
    if (oldRecord != null) {
      _addEntity(
        affectedEntities,
        OperationEntityRef(
          entityType: 'timing_record',
          entityId: oldRecord.id.toString(),
          label: '计时记录 ${oldRecord.id}',
          projectId: oldProjectId,
          deviceId: draft.deviceId.toString(),
        ),
      );
    }
    if (oldProjectId != null) {
      _addEntity(
        affectedEntities,
        OperationEntityRef(
          entityType: 'project',
          entityId: oldProjectId,
          label: _projectLabel(oldRecord),
          projectId: oldProjectId,
        ),
      );
    }
    if (target.existingProject != null) {
      final project = target.existingProject!;
      _addEntity(
        affectedEntities,
        OperationEntityRef(
          entityType: 'project',
          entityId: project.id,
          label: _projectLabel(project),
          projectId: project.id,
        ),
      );
    } else if (target.wouldCreateNewProject) {
      _addEntity(
        affectedEntities,
        OperationEntityRef(
          entityType: 'project',
          entityId: 'new:${draft.legacyProjectKey}',
          label: _projectLabel(draft),
        ),
      );
      warnings.add('当前没有可复用的未结清项目，执行时将创建新项目。');
    }
    final missingExplicitProjectId = target.missingExplicitProjectId;
    if (missingExplicitProjectId != null) {
      warnings.add('当前记录指向的项目 $missingExplicitProjectId 不存在，请刷新后再试。');
    }

    if (projectChanged) {
      await _collectActiveMergeGroup(
        projectId: oldProjectId,
        affectedProjectIds: affectedProjectIds,
        mergeGroupIds: mergeGroupIds,
        affectedEntities: affectedEntities,
      );
      await _collectActiveMergeGroup(
        projectId: targetProjectId,
        affectedProjectIds: affectedProjectIds,
        mergeGroupIds: mergeGroupIds,
        affectedEntities: affectedEntities,
      );
    }

    final simulatedRecord = targetProjectId == null
        ? draft
        : draft.copyWith(projectId: targetProjectId);
    final receivableFenByProjectId =
        await _computeReceivableFenByProjectIdForPreview(
          affectedProjectIds: affectedProjectIds,
          editingRecordId: input.editingRecordId,
          simulatedRecord: simulatedRecord,
          targetProjectId: targetProjectId,
          devices: devices,
          rates: rates,
        );
    final impactDecision = await _evaluateSettlementImpact(
      receivableFenByProjectId: receivableFenByProjectId,
      reason: ProjectSettlementImpactReason.editTiming,
    );
    final willRevokeSettlement = impactDecision.anyRevocationNeeded;

    if (mergeGroupIds.isNotEmpty) {
      warnings.add('保存后将自动解除受影响的合并项目。');
    }
    if (willRevokeSettlement) {
      warnings.add('保存后将自动撤销不再成立的结清状态。');
    }
    warnings.add('预览基于当前本地数据，执行前必须重新分析确认。');

    final previewInput = SaveTimingRecordOperationPreviewInput(
      operationId: input.operationId,
      isEditing: oldRecord != null,
      timingRecordId: input.editingRecordId?.toString(),
      deviceLabel: _deviceLabel(devices, draft.deviceId),
      projectLabel: target.existingProject == null
          ? _projectLabel(draft)
          : _projectLabel(target.existingProject),
      oldProjectLabel: oldRecord == null ? null : _projectLabel(oldRecord),
      newProjectLabel: projectChanged
          ? target.existingProject == null
                ? _projectLabel(draft)
                : _projectLabel(target.existingProject)
          : null,
      projectChanged: projectChanged,
      willDissolveMerge: mergeGroupIds.isNotEmpty,
      willRevokeSettlement: willRevokeSettlement,
      affectedEntities: List.unmodifiable(affectedEntities),
      warnings: List.unmodifiable(warnings),
    );

    return SaveTimingRecordOperationAnalyzeResult(
      previewInput: previewInput,
      preview: _command.preview(previewInput),
      oldProjectId: oldProjectId,
      existingNewProjectId: targetProjectId,
      wouldCreateNewProject: target.wouldCreateNewProject,
      affectedProjectIds: List.unmodifiable(affectedProjectIds),
      mergeGroupIdsToDissolve: List.unmodifiable(mergeGroupIds),
      requiresReanalysisBeforeExecute: true,
      warnings: List.unmodifiable(warnings),
    );
  }

  /// 重新 analyze 同一份 [input]，与 [previousResult] 关键字段比对，判断 preview
  /// 是否仍然新鲜。纯只读：不写 DB、不调 execute、不写 audit。
  ///
  /// 重新 analyze 抛 [SaveTimingRecordAnalyzeException] 时（例如旧 record 已被
  /// 删除）不向上抛错，而是返回 `isFresh: false` + `oldRecordMissing` 原因，
  /// 让调用方统一以 verdict 形式处理"过期"。其它异常（例如 DB 错误、
  /// "多个 active 项目匹配同一联系人和工地" 等结构性错误）仍向上传播，因为
  /// 它们不是"漂移"，是真实 bug。
  Future<SaveTimingRecordFreshnessVerdict> validateFreshness({
    required SaveTimingRecordOperationAnalyzeInput input,
    required SaveTimingRecordOperationAnalyzeResult previousResult,
  }) async {
    SaveTimingRecordOperationAnalyzeResult latest;
    try {
      latest = await analyze(input);
    } on SaveTimingRecordAnalyzeException catch (error) {
      return SaveTimingRecordFreshnessVerdict(
        isFresh: false,
        latest: null,
        staleReasons: List.unmodifiable([
          SaveTimingRecordStaleReason(
            type: SaveTimingRecordStaleReasonType.oldRecordMissing,
            message: error.message,
          ),
        ]),
      );
    }

    final reasons = <SaveTimingRecordStaleReason>[];

    void diffScalar(
      SaveTimingRecordStaleReasonType type,
      String label,
      Object? prev,
      Object? next,
    ) {
      if (prev == next) return;
      reasons.add(
        SaveTimingRecordStaleReason(
          type: type,
          message: '$label: $prev → $next',
          previousValue: prev,
          latestValue: next,
        ),
      );
    }

    void diffSet<T>(
      SaveTimingRecordStaleReasonType type,
      String label,
      Iterable<T> prev,
      Iterable<T> next,
    ) {
      if (_unorderedSetEquals(prev, next)) return;
      reasons.add(
        SaveTimingRecordStaleReason(
          type: type,
          message: '$label: ${prev.toSet()} → ${next.toSet()}',
          previousValue: prev.toList(growable: false),
          latestValue: next.toList(growable: false),
        ),
      );
    }

    diffScalar(
      SaveTimingRecordStaleReasonType.oldProjectChanged,
      '旧项目身份',
      previousResult.oldProjectId,
      latest.oldProjectId,
    );
    diffScalar(
      SaveTimingRecordStaleReasonType.targetProjectChanged,
      '目标项目',
      previousResult.existingNewProjectId,
      latest.existingNewProjectId,
    );
    diffScalar(
      SaveTimingRecordStaleReasonType.wouldCreateNewProjectChanged,
      '是否会创建新项目',
      previousResult.wouldCreateNewProject,
      latest.wouldCreateNewProject,
    );
    diffSet(
      SaveTimingRecordStaleReasonType.affectedProjectIdsChanged,
      '受影响项目集合',
      previousResult.affectedProjectIds,
      latest.affectedProjectIds,
    );
    diffSet(
      SaveTimingRecordStaleReasonType.mergeGroupsChanged,
      '受影响合并组集合',
      previousResult.mergeGroupIdsToDissolve,
      latest.mergeGroupIdsToDissolve,
    );
    diffScalar(
      SaveTimingRecordStaleReasonType.willDissolveMergeChanged,
      '是否解除合并组',
      previousResult.previewInput.willDissolveMerge,
      latest.previewInput.willDissolveMerge,
    );
    diffScalar(
      SaveTimingRecordStaleReasonType.willRevokeSettlementChanged,
      '是否撤销结清',
      previousResult.previewInput.willRevokeSettlement,
      latest.previewInput.willRevokeSettlement,
    );
    diffScalar(
      SaveTimingRecordStaleReasonType.riskLevelChanged,
      '风险等级',
      previousResult.preview.riskLevel,
      latest.preview.riskLevel,
    );
    diffSet(
      SaveTimingRecordStaleReasonType.warningsChanged,
      '警告集合',
      previousResult.previewInput.warnings,
      latest.previewInput.warnings,
    );

    return SaveTimingRecordFreshnessVerdict(
      isFresh: reasons.isEmpty,
      latest: latest,
      staleReasons: List.unmodifiable(reasons),
    );
  }

  static bool _unorderedSetEquals<T>(Iterable<T> a, Iterable<T> b) {
    final setA = a.toSet();
    final setB = b.toSet();
    return setA.length == setB.length && setA.containsAll(setB);
  }

  Future<TimingRecord?> _readOldRecord(int? editingRecordId) async {
    if (editingRecordId == null) return null;
    final record = await _timingRepository.findById(editingRecordId);
    if (record == null) {
      throw SaveTimingRecordAnalyzeException('这条计时记录已不存在，请刷新后再试');
    }
    return record;
  }

  Future<void> _validateAllocationCutoff({
    required TimingRecord draft,
    required int? editingRecordId,
  }) async {
    if (draft.allocationCutoffDate == null) return;
    final sameDeviceRecords = await _timingRepository.listByDeviceId(
      draft.deviceId,
    );
    try {
      SaveTimingRecordAllocationCutoffValidator.validate(
        record: draft,
        sameDeviceRecords: sameDeviceRecords,
        editingRecordId: editingRecordId ?? draft.id,
      );
    } on SaveTimingRecordAllocationCutoffValidationException catch (error) {
      throw SaveTimingRecordAnalyzeException(error.message, code: error.code);
    }
  }

  Future<_TargetProjectResolution> _resolveTargetProject({
    required TimingRecord draft,
    required TimingRecord? oldRecord,
  }) async {
    final explicitProjectId = _trimToNull(draft.projectId);
    if (explicitProjectId != null) {
      final project = await _projectRepository.findById(explicitProjectId);
      if (project != null) {
        return _TargetProjectResolution(existingProject: project);
      }
      return _TargetProjectResolution(
        wouldCreateNewProject: false,
        missingExplicitProjectId: explicitProjectId,
      );
    }

    if (oldRecord != null &&
        oldRecord.legacyProjectKey == draft.legacyProjectKey) {
      final oldProjectId = _trimToNull(oldRecord.effectiveProjectId);
      if (oldProjectId != null) {
        final oldProject = await _projectRepository.findById(oldProjectId);
        if (oldProject != null) {
          return _TargetProjectResolution(existingProject: oldProject);
        }
      }
    }

    final activeProjects = await _projectRepository.findActiveByContactSite(
      contact: draft.contact,
      site: draft.site,
    );
    if (activeProjects.length == 1) {
      return _TargetProjectResolution(existingProject: activeProjects.single);
    }
    if (activeProjects.length > 1) {
      throw StateError('存在多个 active 项目匹配同一联系人和工地');
    }
    return const _TargetProjectResolution(wouldCreateNewProject: true);
  }

  Future<void> _collectActiveMergeGroup({
    required String? projectId,
    required Set<String> affectedProjectIds,
    required Set<int> mergeGroupIds,
    required List<OperationEntityRef> affectedEntities,
  }) async {
    final normalized = _trimToNull(projectId);
    if (normalized == null) return;
    final member = await _mergeRepository.findActiveMemberByProjectId(
      normalized,
    );
    if (member == null) return;
    if (!mergeGroupIds.add(member.groupId)) return;

    _addEntity(
      affectedEntities,
      OperationEntityRef(
        entityType: 'merge_group',
        entityId: member.groupId.toString(),
        label: '合并项目 ${member.groupId}',
      ),
    );
    final members = await _mergeRepository.listActiveMembersByGroupId(
      member.groupId,
    );
    for (final groupMember in members) {
      final pid = _trimToNull(groupMember.effectiveProjectId);
      if (pid == null) continue;
      affectedProjectIds.add(pid);
      _addEntity(
        affectedEntities,
        OperationEntityRef(
          entityType: 'project',
          entityId: pid,
          label: _memberLabel(groupMember),
          projectId: pid,
        ),
      );
    }
  }

  Future<Map<String, int>> _computeReceivableFenByProjectIdForPreview({
    required Set<String> affectedProjectIds,
    required int? editingRecordId,
    required TimingRecord simulatedRecord,
    required String? targetProjectId,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
  }) async {
    final result = <String, int>{};
    for (final projectId in affectedProjectIds) {
      result[projectId] = await _computeReceivableFenForProject(
        projectId: projectId,
        editingRecordId: editingRecordId,
        simulatedRecord: simulatedRecord,
        targetProjectId: targetProjectId,
        devices: devices,
        rates: rates,
      );
    }
    return result;
  }

  Future<int> _computeReceivableFenForProject({
    required String projectId,
    required int? editingRecordId,
    required TimingRecord simulatedRecord,
    required String? targetProjectId,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
  }) async {
    final records = await _timingRepository.listByProjectId(projectId);
    final simulatedRecords = <TimingRecord>[
      for (final record in records)
        if (record.id != editingRecordId) record,
    ];
    if (targetProjectId == projectId) {
      simulatedRecords.add(simulatedRecord);
    }
    if (simulatedRecords.isEmpty) return 0;

    final aggs = AccountService.buildProjects(timingRecords: simulatedRecords);
    var receivableYuan = 0.0;
    for (final agg in aggs.values) {
      if (agg.projectId != projectId) continue;
      final money = AccountService.calcMoney(
        agg: agg,
        devices: devices,
        rates: rates,
        payments: const [],
        writeOffs: const [],
      );
      receivableYuan += money.receivable;
    }
    return ProjectFinanceCalculator.yuanToFen(receivableYuan);
  }

  // 预览路径委托到单一来源 [ProjectSettlementImpactService.evaluateFromRepositories]，
  // 与 commit 路径（事务 executor 上的 [ProjectSettlementImpactService.evaluate]）共用
  // 同一套 snapshot 构建逻辑，避免 preview 与 commit 漂移。feature 层不持 executor，
  // 故走 repository 版（不违反 features→AppDatabase 守卫）。
  Future<ProjectSettlementImpactDecision> _evaluateSettlementImpact({
    required Map<String, int> receivableFenByProjectId,
    ProjectSettlementImpactReason reason = ProjectSettlementImpactReason.other,
  }) {
    return ProjectSettlementImpactService.evaluateFromRepositories(
      receivableFenByProjectId: receivableFenByProjectId,
      accountPaymentRepository: _accountPaymentRepository,
      writeOffRepository: _writeOffRepository,
      projectRepository: _projectRepository,
      reason: reason,
    );
  }

  static void _addEntity(
    List<OperationEntityRef> refs,
    OperationEntityRef ref,
  ) {
    final exists = refs.any((item) {
      return item.entityType == ref.entityType && item.entityId == ref.entityId;
    });
    if (!exists) refs.add(ref);
  }

  static String _deviceLabel(List<Device> devices, int deviceId) {
    for (final device in devices) {
      if (device.id != deviceId) continue;
      final name = device.name.trim();
      if (name.isNotEmpty) return name;
      final brand = device.brand.trim();
      if (brand.isNotEmpty) return brand;
    }
    return '设备 $deviceId';
  }

  static String _projectLabel(Object? source) {
    if (source is Project) return _partsLabel(source.contact, source.site);
    if (source is TimingRecord) return _partsLabel(source.contact, source.site);
    return '未命名项目';
  }

  static String _memberLabel(AccountProjectMergeMember member) {
    return _partsLabel(member.contact, member.site);
  }

  static String _partsLabel(String contact, String site) {
    final normalizedContact = contact.trim();
    final normalizedSite = site.trim();
    if (normalizedContact.isNotEmpty && normalizedSite.isNotEmpty) {
      return '$normalizedContact · $normalizedSite';
    }
    if (normalizedContact.isNotEmpty) return normalizedContact;
    if (normalizedSite.isNotEmpty) return normalizedSite;
    return '未命名项目';
  }

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}

class _TargetProjectResolution {
  const _TargetProjectResolution({
    this.existingProject,
    this.wouldCreateNewProject = false,
    this.missingExplicitProjectId,
  });

  final Project? existingProject;
  final bool wouldCreateNewProject;
  final String? missingExplicitProjectId;
}
