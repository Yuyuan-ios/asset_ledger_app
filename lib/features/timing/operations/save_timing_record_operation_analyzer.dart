import 'package:sqflite/sqflite.dart';

import '../../../core/operations/operation_models.dart';
import '../../../core/operations/operation_transaction_runner.dart';
import '../../../data/db/database.dart';
import '../../../data/models/account_project_merge_member.dart';
import '../../../data/models/device.dart';
import '../../../data/models/project.dart';
import '../../../data/models/project_device_rate.dart';
import '../../../data/models/timing_record.dart';
import '../../../data/repositories/account_project_merge_repository.dart';
import '../../../data/repositories/device_repository.dart';
import '../../../data/repositories/project_rate_repository.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/timing_repository.dart';
import '../../../data/services/account_service.dart';
import '../../account/domain/services/project_finance_calculator.dart';
import '../../../infrastructure/local/account/project_settlement_impact_service.dart';
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
  const SaveTimingRecordAnalyzeException(this.message);

  final String message;

  @override
  String toString() => 'SaveTimingRecordAnalyzeException: $message';
}

class SaveTimingRecordOperationAnalyzer {
  SaveTimingRecordOperationAnalyzer({
    required SaveTimingRecordOperationCommand command,
    SqfliteTimingRepository? timingRepository,
    SqfliteAccountProjectMergeRepository? mergeRepository,
    SqfliteProjectRepository? projectRepository,
    DeviceRepository? deviceRepository,
    ProjectRateRepository? projectRateRepository,
    ProjectSettlementImpactService? impactService,
    Future<OperationDatabaseExecutor> Function()? executorFactory,
  }) : _command = command,
       _timingRepository = timingRepository ?? SqfliteTimingRepository(),
       _mergeRepository =
           mergeRepository ?? SqfliteAccountProjectMergeRepository(),
       _projectRepository = projectRepository ?? SqfliteProjectRepository(),
       _deviceRepository = deviceRepository ?? SqfliteDeviceRepository(),
       _projectRateRepository =
           projectRateRepository ?? SqfliteProjectRateRepository(),
       _impactService = impactService ?? ProjectSettlementImpactService(),
       _executorFactory = executorFactory ?? (() async => AppDatabase.database);

  final SaveTimingRecordOperationCommand _command;
  final SqfliteTimingRepository _timingRepository;
  final SqfliteAccountProjectMergeRepository _mergeRepository;
  final SqfliteProjectRepository _projectRepository;
  final DeviceRepository _deviceRepository;
  final ProjectRateRepository _projectRateRepository;
  final ProjectSettlementImpactService _impactService;
  final Future<OperationDatabaseExecutor> Function() _executorFactory;

  Future<SaveTimingRecordOperationAnalyzeResult> analyze(
    SaveTimingRecordOperationAnalyzeInput input,
  ) async {
    final executor = await _executorFactory();
    final devices = await _deviceRepository.listAll();
    final rates = await _projectRateRepository.listAll();
    final draft = input.draftRecord;

    final oldRecord = await _readOldRecord(executor, input.editingRecordId);
    final oldProjectId = _trimToNull(oldRecord?.effectiveProjectId);
    final target = await _resolveTargetProject(
      executor,
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
        executor,
        projectId: oldProjectId,
        affectedProjectIds: affectedProjectIds,
        mergeGroupIds: mergeGroupIds,
        affectedEntities: affectedEntities,
      );
      await _collectActiveMergeGroup(
        executor,
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
          executor,
          affectedProjectIds: affectedProjectIds,
          editingRecordId: input.editingRecordId,
          simulatedRecord: simulatedRecord,
          targetProjectId: targetProjectId,
          devices: devices,
          rates: rates,
        );
    final impactDecision = await _impactService.evaluate(
      executor: executor,
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

  Future<TimingRecord?> _readOldRecord(
    DatabaseExecutor executor,
    int? editingRecordId,
  ) async {
    if (editingRecordId == null) return null;
    final record = await _timingRepository.findByIdWithExecutor(
      executor,
      editingRecordId,
    );
    if (record == null) {
      throw SaveTimingRecordAnalyzeException('这条计时记录已不存在，请刷新后再试');
    }
    return record;
  }

  Future<_TargetProjectResolution> _resolveTargetProject(
    DatabaseExecutor executor, {
    required TimingRecord draft,
    required TimingRecord? oldRecord,
  }) async {
    final explicitProjectId = _trimToNull(draft.projectId);
    if (explicitProjectId != null) {
      final project = await _findProjectByIdWithExecutor(
        executor,
        explicitProjectId,
      );
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
        final oldProject = await _findProjectByIdWithExecutor(
          executor,
          oldProjectId,
        );
        if (oldProject != null) {
          return _TargetProjectResolution(existingProject: oldProject);
        }
      }
    }

    final activeProjects = await _projectRepository
        .findActiveByContactSiteWithExecutor(
          executor,
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

  Future<Project?> _findProjectByIdWithExecutor(
    DatabaseExecutor executor,
    String projectId,
  ) async {
    final normalized = projectId.trim();
    if (normalized.isEmpty) return null;
    final rows = await executor.query(
      SqfliteProjectRepository.table,
      where: 'id = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Project.fromMap(rows.single);
  }

  Future<void> _collectActiveMergeGroup(
    DatabaseExecutor executor, {
    required String? projectId,
    required Set<String> affectedProjectIds,
    required Set<int> mergeGroupIds,
    required List<OperationEntityRef> affectedEntities,
  }) async {
    final normalized = _trimToNull(projectId);
    if (normalized == null) return;
    final member = await _mergeRepository
        .findActiveMemberByProjectIdWithExecutor(executor, normalized);
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
    final members = await _mergeRepository
        .listActiveMembersByGroupIdWithExecutor(executor, member.groupId);
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

  Future<Map<String, int>> _computeReceivableFenByProjectIdForPreview(
    DatabaseExecutor executor, {
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
        executor,
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

  Future<int> _computeReceivableFenForProject(
    DatabaseExecutor executor, {
    required String projectId,
    required int? editingRecordId,
    required TimingRecord simulatedRecord,
    required String? targetProjectId,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
  }) async {
    final records = await _timingRepository.listByProjectIdWithExecutor(
      executor,
      projectId,
    );
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
