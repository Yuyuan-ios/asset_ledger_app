import '../../../core/operations/operation_access_control.dart';
import '../../../core/operations/operation_actor_scope.dart';
import '../../../core/operations/operation_models.dart';
import 'save_timing_record_operation_analyzer.dart';
import 'save_timing_record_preview_redactor.dart';

/// 未来 Agent / MCP 使用的保存计时只读预览入口。
///
/// D20 只负责把现有 DB-backed analyzer 包成稳定的 preview-only 契约：
/// - 不执行保存；
/// - 不写 audit；
/// - 不接界面层 / MCP transport；
/// - 不接 outbox。
class SaveTimingRecordOperationPreviewAdapter {
  const SaveTimingRecordOperationPreviewAdapter({
    required this.analyzer,
    SaveTimingRecordPreviewRedactor? redactor,
  }) : redactor = redactor ?? const SaveTimingRecordPreviewRedactor();

  final SaveTimingRecordOperationAnalyzer analyzer;
  final SaveTimingRecordPreviewRedactor redactor;

  Future<SaveTimingRecordOperationPreviewResponse> preview(
    SaveTimingRecordOperationPreviewRequest request,
  ) async {
    final analysis = await analyzer.analyze(request.input);
    return SaveTimingRecordOperationPreviewResponse(
      analysis: analysis,
      preview: analysis.preview,
    );
  }

  /// 返回完整 preview 与面向具体 actor/scope 的脱敏投影。
  ///
  /// [full] 仍是 owner/server 侧持有的完整结果，可用于后续 freshness /
  /// confirm；[redacted] 仅用于展示，不能作为 confirm / execute 凭据。
  Future<SaveTimingRecordOperationRedactedPreviewResponse> previewForActor({
    required SaveTimingRecordOperationPreviewRequest request,
    required ActorContext actor,
    required ActorScope scope,
    DateTime? now,
  }) async {
    final full = await preview(request);
    final redacted = redactor.redact(
      response: full,
      actor: actor,
      scope: scope,
      now: now,
    );
    return SaveTimingRecordOperationRedactedPreviewResponse(
      full: full,
      redacted: redacted,
    );
  }

  Future<SaveTimingRecordFreshnessVerdict> validateFreshness({
    required SaveTimingRecordOperationAnalyzeInput input,
    required SaveTimingRecordOperationAnalyzeResult previousResult,
  }) {
    return analyzer.validateFreshness(
      input: input,
      previousResult: previousResult,
    );
  }
}

/// preview adapter 的 actor-aware 只读输出。
///
/// [full] 与 [redacted] 刻意同时存在并保持分离：
/// - [full] 保留完整 analysis / preview / freshness，用于内部确认链路；
/// - [redacted] 是给 actor 展示的安全投影，不可用于 confirm / execute。
class SaveTimingRecordOperationRedactedPreviewResponse {
  const SaveTimingRecordOperationRedactedPreviewResponse({
    required this.full,
    required this.redacted,
  });

  final SaveTimingRecordOperationPreviewResponse full;
  final RedactedSaveTimingRecordPreview redacted;
}

class SaveTimingRecordOperationPreviewRequest {
  const SaveTimingRecordOperationPreviewRequest({required this.input});

  final SaveTimingRecordOperationAnalyzeInput input;
}

class SaveTimingRecordOperationPreviewResponse {
  const SaveTimingRecordOperationPreviewResponse({
    required this.analysis,
    required this.preview,
    this.freshness,
  });

  final SaveTimingRecordOperationAnalyzeResult analysis;
  final OperationPreview preview;
  final SaveTimingRecordFreshnessVerdict? freshness;

  bool get requiresReanalysisBeforeExecute {
    return analysis.requiresReanalysisBeforeExecute;
  }

  List<String> get warnings => analysis.warnings;
}
