import 'package:asset_ledger/data/models/timing_calculation_history.dart';

import '../../../data/models/timing_record.dart';
import '../../../data/services/project_resolver.dart';
import '../state/timing_store.dart';
import 'timing_merge_dissolve_port.dart';

class SaveTimingRecordUseCase {
  const SaveTimingRecordUseCase({
    required TimingStore timingStore,
    required TimingMergeDissolvePort mergeDissolve,
    required ProjectResolver projectResolver,
  }) : _timingStore = timingStore,
       _mergeDissolve = mergeDissolve,
       _projectResolver = projectResolver;

  final TimingStore _timingStore;
  final TimingMergeDissolvePort _mergeDissolve;
  final ProjectResolver _projectResolver;

  Future<SaveTimingRecordResult> execute({
    required TimingRecord? editing,
    required TimingRecord record,
    List<TimingCalculationHistory> calculationHistories = const [],
  }) async {
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
  });

  final bool mergeDissolved;
  final PendingTimingMergeDissolve? pendingMergeDissolve;

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
