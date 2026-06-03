import 'package:asset_ledger/data/models/timing_calculation_history.dart';

import '../../../core/operations/operation_access_control.dart';
import '../../../core/operations/operation_actor_scope.dart';
import '../../../core/operations/operation_models.dart';
import '../../../data/models/timing_record.dart';
import '../operations/save_timing_record_operation_analyzer.dart';
import '../operations/save_timing_record_operation_confirm_adapter.dart';
import '../operations/save_timing_record_operation_command.dart';
import '../operations/save_timing_record_operation_fingerprints.dart';
import '../operations/save_timing_record_operation_preview_adapter.dart';
import '../operations/save_timing_record_preview_service.dart';
import '../state/timing_store.dart';
import 'save_timing_record_with_impact_use_case.dart';

/// Thin façade for the timing editor save flow.
///
/// R4：新增 [executeWithToken] 方法，使用 token-aware save 路径。
/// 生产路径优先通过 provider 注入 [previewService] + [confirmAdapter] +
/// [actorContext]，走 previewWithToken → executeConfirmedWithToken 链路。
/// 保留旧 [execute] 方法作为后向兼容路径。
class SaveTimingRecordUseCase {
  const SaveTimingRecordUseCase({
    required TimingStore timingStore,
    required SaveTimingRecordWithImpactUseCase withImpact,
    required SaveTimingRecordOperationCommand command,
    this.analyzer,
    this.previewService,
    this.confirmAdapter,
    this.actorContext,
    String Function()? operationIdFactory,
  }) : _timingStore = timingStore,
       _withImpact = withImpact,
       _command = command,
       _operationIdFactory = operationIdFactory ?? _defaultOperationId;

  final TimingStore _timingStore;
  final SaveTimingRecordWithImpactUseCase _withImpact;
  final SaveTimingRecordOperationCommand _command;
  final String Function() _operationIdFactory;

  /// R4：与 preview/confirm 共享的 analyzer，用于复建 confirm 所需完整 analysis。
  final SaveTimingRecordOperationAnalyzer? analyzer;

  /// R4：token-aware 预览服务（可选注入）。
  final SaveTimingRecordPreviewService? previewService;

  /// R4：token-aware 确认适配器（可选注入）。
  final SaveTimingRecordOperationConfirmAdapter? confirmAdapter;

  /// R4：真实 ActorContext（可选注入，来自 R3）。
  final ActorContext? actorContext;

  /// R4：token-aware 保存路径。
  ///
  /// 使用 [previewService.previewWithToken] 获得带有 confirmation token 的预览，
  /// 再通过 [confirmAdapter.executeConfirmedWithToken] 执行保存。
  /// 需要 [previewService]、[confirmAdapter]、[actorContext] 全部注入。
  /// 若任一缺失，抛 [SaveTimingRecordOperationException]。
  Future<SaveTimingRecordResult> executeWithToken({
    required TimingRecord? editing,
    required TimingRecord record,
    List<TimingCalculationHistory> calculationHistories = const [],
  }) async {
    final svc = previewService;
    final adapter = confirmAdapter;
    final operationAnalyzer = analyzer;
    final actorCtx = actorContext;
    if (svc == null ||
        adapter == null ||
        operationAnalyzer == null ||
        actorCtx == null) {
      throw const SaveTimingRecordOperationException(
        'token-aware save 未就绪：缺少 previewService / confirmAdapter / analyzer / actorContext',
      );
    }

    final preparation = await _withImpact.prepareForSave(
      editing: editing,
      record: record,
    );
    SaveTimingRecordWithImpactResult? impact;

    // 1) 构建 analyze input（与 operationAnalyzer 的产物签名一致）
    final operationId = _operationIdFactory();
    final analyzeInput = SaveTimingRecordOperationAnalyzeInput(
      operationId: operationId,
      draftRecord: record,
      editingRecordId: editing?.id,
    );

    // 2) token-aware preview（由 previewService 内部完成 analyze + token 签发）
    final previewResult = await svc.previewWithToken(
      request: SaveTimingRecordOperationPreviewRequest(input: analyzeInput),
      actor: actorCtx,
      scope: ActorScope.fullOwner(),
    );

    final tokenId = previewResult.confirmationTokenId;
    if (tokenId == null || !previewResult.canProceedToConfirm) {
      throw SaveTimingRecordOperationException(
        previewResult.confirmUnavailableReasonCode ?? '无法获取确认 token',
      );
    }

    // 3) 用同一 analyzer 复建完整 analysis，保持 token 签发和确认校验的 hash 口径一致。
    final previousAnalyzeResult = await operationAnalyzer.analyze(analyzeInput);

    // 4) token-aware 确认执行
    final execution = await adapter.executeConfirmedWithToken(
      analyzeInput: analyzeInput,
      previousAnalyzeResult: previousAnalyzeResult,
      operationId: operationId,
      tokenId: tokenId,
      actor: actorCtx,
      scope: ActorScope.fullOwner(),
      redactedPreviewHash:
          SaveTimingRecordOperationFingerprints.redactedPreviewHashFor(
            previewResult.preview,
          ),
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
    await _timingStore.loadAll();
    return SaveTimingRecordResult(
      mergeDissolved: committedImpact.mergeDissolved,
      impact: committedImpact,
    );
  }

  /// 保留的旧保存路径（后向兼容）。
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
