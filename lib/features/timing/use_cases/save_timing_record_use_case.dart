import 'package:asset_ledger/data/models/timing_calculation_history.dart';

import '../../../data/models/timing_record.dart';
import '../../../data/services/project_resolver.dart';
import '../state/timing_store.dart';
import 'save_timing_record_with_impact_use_case.dart';
import 'timing_merge_dissolve_port.dart';

class SaveTimingRecordUseCase {
  const SaveTimingRecordUseCase({
    required TimingStore timingStore,
    required TimingMergeDissolvePort mergeDissolve,
    required ProjectResolver projectResolver,
    SaveTimingRecordWithImpactUseCase? withImpact,
  }) : _timingStore = timingStore,
       _mergeDissolve = mergeDissolve,
       _projectResolver = projectResolver,
       _withImpact = withImpact;

  final TimingStore _timingStore;
  final TimingMergeDissolvePort _mergeDissolve;
  final ProjectResolver _projectResolver;

  /// 阶段 B Step 3 引入的事务化保存入口。生产环境通过
  /// [TimingSaveProviders] 注入；遗留测试（基于 fake collaborator）保持 null
  /// 仍走旧 store.save + retry 路径，不强制改造既有测试。
  final SaveTimingRecordWithImpactUseCase? _withImpact;

  Future<SaveTimingRecordResult> execute({
    required TimingRecord? editing,
    required TimingRecord record,
    List<TimingCalculationHistory> calculationHistories = const [],
  }) async {
    final withImpact = _withImpact;
    if (withImpact != null) {
      // 事务化路径：保存计时 + 解除合并 + 撤销结清 在同一事务内完成；
      // UI 不再依赖 pending retry 兜底一致性。
      final impact = await withImpact.execute(
        editing: editing,
        record: record,
        calculationHistories: calculationHistories,
      );
      // 刷新 store 以让 UI 看到最新落库的记录列表 + 级联后的状态。
      await _timingStore.loadAll();
      return SaveTimingRecordResult(
        mergeDissolved: impact.mergeDissolved,
        impact: impact,
      );
    }

    // 遗留路径：在事务化入口未注入时保留两步保存 + UI retry，兼容旧测试。
    final recordToSave = await _resolveProjectId(
      editing: editing,
      record: record,
    );
    await _timingStore.save(
      recordToSave,
      calculationHistories: calculationHistories,
    );

    final pending = PendingTimingMergeDissolve.fromRecords(
      editing: editing,
      record: recordToSave,
    );
    if (pending == null) return const SaveTimingRecordResult();

    try {
      final dissolved = await retryMergeDissolve(pending);
      return SaveTimingRecordResult(mergeDissolved: dissolved);
    } catch (error) {
      return SaveTimingRecordResult(
        pendingMergeDissolve: pending.copyWith(error: error),
      );
    }
  }

  Future<bool> retryMergeDissolve(PendingTimingMergeDissolve pending) {
    return _mergeDissolve.dissolveMergeGroupIfProjectIdChanged(
      oldProjectId: pending.oldProjectId,
      newProjectId: pending.newProjectId,
    );
  }

  Future<TimingRecord> _resolveProjectId({
    required TimingRecord? editing,
    required TimingRecord record,
  }) async {
    if (editing != null && _projectIdentityChanged(editing, record)) {
      final result = await _projectResolver.resolveOrCreate(
        contact: record.contact,
        site: record.site,
      );
      return record.copyWith(projectId: result.projectId);
    }
    if (record.projectId.trim().isNotEmpty) return record;
    final editedProjectId = editing?.effectiveProjectId;
    if (editedProjectId != null && editedProjectId.trim().isNotEmpty) {
      return record.copyWith(projectId: editedProjectId);
    }
    final result = await _projectResolver.resolveOrCreate(
      contact: record.contact,
      site: record.site,
    );
    final projectId = result.projectId;
    return record.copyWith(projectId: projectId);
  }

  bool _projectIdentityChanged(TimingRecord editing, TimingRecord record) {
    return editing.legacyProjectKey != record.legacyProjectKey;
  }
}

class SaveTimingRecordResult {
  const SaveTimingRecordResult({
    this.mergeDissolved = false,
    this.pendingMergeDissolve,
    this.impact,
  });

  final bool mergeDissolved;
  final PendingTimingMergeDissolve? pendingMergeDissolve;

  /// 事务化路径返回的完整 impact 信息。遗留两步保存路径保持 null。
  final SaveTimingRecordWithImpactResult? impact;

  bool get needsMergeDissolveRetry => pendingMergeDissolve != null;
}

class PendingTimingMergeDissolve {
  const PendingTimingMergeDissolve({
    required this.oldProjectId,
    required this.newProjectId,
    this.error,
  });

  final String oldProjectId;
  final String newProjectId;
  final Object? error;

  static PendingTimingMergeDissolve? fromRecords({
    required TimingRecord? editing,
    required TimingRecord record,
  }) {
    if (editing == null) return null;

    final oldProjectId = editing.effectiveProjectId;
    final newProjectId = record.effectiveProjectId;
    if (oldProjectId == newProjectId) return null;

    return PendingTimingMergeDissolve(
      oldProjectId: oldProjectId,
      newProjectId: newProjectId,
    );
  }

  PendingTimingMergeDissolve copyWith({Object? error}) {
    return PendingTimingMergeDissolve(
      oldProjectId: oldProjectId,
      newProjectId: newProjectId,
      error: error ?? this.error,
    );
  }
}
