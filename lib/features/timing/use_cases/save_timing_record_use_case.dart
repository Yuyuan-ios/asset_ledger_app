import 'package:asset_ledger/data/models/timing_calculation_history.dart';

import '../../../core/operations/operation_models.dart';
import '../../../data/models/timing_record.dart';
import '../operations/save_timing_record_operation_command.dart';
import '../state/timing_store.dart';
import 'save_timing_record_with_impact_use_case.dart';

/// Thin façade for the timing editor save flow.
///
/// 阶段 C Step 1（C1）后语义：
/// - 唯一权威保存路径是 [SaveTimingRecordWithImpactUseCase]（阶段 B Step 3 引入
///   的事务化路径：保存计时 + 解除合并 + 撤销结清 同一事务）。
/// - 本类作为 feature 层的薄包装：调用事务化路径、拉取最新 store 数据、把
///   impact 信息归一化成 UI 友好的 [SaveTimingRecordResult]。
/// - 不再保留"store.save + retry merge dissolve"的遗留两步保存路径，也不再
///   有 pending retry / [PendingTimingMergeDissolve]。Provider 缺失现在直接
///   fail-fast，由 [context.read] 抛 `ProviderNotFoundException`。
class SaveTimingRecordUseCase {
  const SaveTimingRecordUseCase({
    required TimingStore timingStore,
    required SaveTimingRecordWithImpactUseCase withImpact,
    required SaveTimingRecordOperationCommand command,
    String Function()? operationIdFactory,
  }) : _timingStore = timingStore,
       _withImpact = withImpact,
       _command = command,
       _operationIdFactory = operationIdFactory ?? _defaultOperationId;

  final TimingStore _timingStore;
  final SaveTimingRecordWithImpactUseCase _withImpact;
  final SaveTimingRecordOperationCommand _command;
  final String Function() _operationIdFactory;

  Future<SaveTimingRecordResult> execute({
    required TimingRecord? editing,
    required TimingRecord record,
    List<TimingCalculationHistory> calculationHistories = const [],
  }) async {
    final preparation = await _withImpact.prepareForSave(
      editing: editing,
      record: record,
    );
    SaveTimingRecordWithImpactResult? impact;
    final preview = _command.preview(
      _buildPreviewInput(editing: editing, preparation: preparation),
    );
    final execution = await _command.executeConfirmedInTransaction(
      preview: preview,
      operationId: preview.operationId,
      executeSaveWithExecutor: (executor) async {
        final result = await _withImpact.executeWithExecutor(
          executor,
          editing: editing,
          preparation: preparation,
          calculationHistories: calculationHistories,
        );
        impact = result;
        return result;
      },
    );
    if (!execution.success) {
      throw SaveTimingRecordOperationException(
        execution.userMessage.isEmpty ? '保存失败，请重试' : execution.userMessage,
        error: execution.error,
      );
    }
    final committedImpact = impact;
    if (committedImpact == null) {
      throw const SaveTimingRecordOperationException('保存失败，请重试');
    }
    // 事务提交后刷新内存 store，让 UI 看到最新落库列表 + 级联后的状态。
    await _timingStore.loadAll();
    return SaveTimingRecordResult(
      mergeDissolved: committedImpact.mergeDissolved,
      impact: committedImpact,
    );
  }

  SaveTimingRecordOperationPreviewInput _buildPreviewInput({
    required TimingRecord? editing,
    required SaveTimingRecordPreparation preparation,
  }) {
    final recordToSave = preparation.recordToSave;
    final projectId = recordToSave.effectiveProjectId.trim();
    final oldProjectId = editing?.effectiveProjectId.trim() ?? '';
    final projectChanged =
        editing != null &&
        oldProjectId.isNotEmpty &&
        projectId.isNotEmpty &&
        oldProjectId != projectId;
    final projectLabel = _projectLabel(recordToSave);
    return SaveTimingRecordOperationPreviewInput(
      operationId: _operationIdFactory(),
      isEditing: editing != null,
      timingRecordId: editing?.id?.toString(),
      deviceLabel: _deviceLabel(
        deviceId: recordToSave.deviceId,
        preparation: preparation,
      ),
      projectLabel: projectLabel,
      oldProjectLabel: editing == null ? null : _projectLabel(editing),
      newProjectLabel: projectChanged ? projectLabel : null,
      projectChanged: projectChanged,
      affectedEntities: _affectedEntities(
        editing: editing,
        recordToSave: recordToSave,
        projectLabel: projectLabel,
      ),
      warnings: const [],
    );
  }

  static List<OperationEntityRef> _affectedEntities({
    required TimingRecord? editing,
    required TimingRecord recordToSave,
    required String projectLabel,
  }) {
    final refs = <OperationEntityRef>[
      OperationEntityRef(
        entityType: 'device',
        entityId: recordToSave.deviceId.toString(),
        label: '设备 ${recordToSave.deviceId}',
        deviceId: recordToSave.deviceId.toString(),
      ),
    ];
    final timingId = editing?.id;
    if (timingId != null) {
      refs.add(
        OperationEntityRef(
          entityType: 'timing_record',
          entityId: timingId.toString(),
          label: '计时记录 $timingId',
          projectId: recordToSave.effectiveProjectId.trim().isEmpty
              ? null
              : recordToSave.effectiveProjectId.trim(),
          deviceId: recordToSave.deviceId.toString(),
        ),
      );
    }
    final projectId = recordToSave.effectiveProjectId.trim();
    if (projectId.isNotEmpty) {
      refs.add(
        OperationEntityRef(
          entityType: 'project',
          entityId: projectId,
          label: projectLabel,
          projectId: projectId,
        ),
      );
    }
    return refs;
  }

  static String _deviceLabel({
    required int deviceId,
    required SaveTimingRecordPreparation preparation,
  }) {
    for (final device in preparation.devices) {
      if (device.id != deviceId) continue;
      final name = device.name.trim();
      if (name.isNotEmpty) return name;
      final brand = device.brand.trim();
      if (brand.isNotEmpty) return brand;
    }
    return '设备 $deviceId';
  }

  static String _projectLabel(TimingRecord record) {
    final contact = record.contact.trim();
    final site = record.site.trim();
    if (contact.isNotEmpty && site.isNotEmpty) return '$contact · $site';
    if (contact.isNotEmpty) return contact;
    if (site.isNotEmpty) return site;
    final projectId = record.effectiveProjectId.trim();
    return projectId.isEmpty ? '未命名项目' : projectId;
  }

  static String _defaultOperationId() {
    return 'save-timing-${DateTime.now().microsecondsSinceEpoch}';
  }
}

class SaveTimingRecordOperationException implements Exception {
  const SaveTimingRecordOperationException(this.message, {this.error});

  final String message;
  final String? error;

  @override
  String toString() {
    final detail = error;
    if (detail == null || detail.isEmpty) {
      return 'SaveTimingRecordOperationException: $message';
    }
    return 'SaveTimingRecordOperationException: $message ($detail)';
  }
}

class SaveTimingRecordResult {
  const SaveTimingRecordResult({
    required this.mergeDissolved,
    required this.impact,
  });

  final bool mergeDissolved;

  /// 事务化路径返回的完整 impact 信息。C1 起永不为 null。
  final SaveTimingRecordWithImpactResult impact;
}
