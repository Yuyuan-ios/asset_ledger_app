import '../../../core/operations/operation_models.dart';
import 'save_timing_record_operation_analyzer.dart';

/// 未来 Agent / MCP 使用的保存计时只读预览入口。
///
/// D20 只负责把现有 DB-backed analyzer 包成稳定的 preview-only 契约：
/// - 不执行保存；
/// - 不写 audit；
/// - 不接界面层 / MCP transport；
/// - 不接 outbox。
class SaveTimingRecordOperationPreviewAdapter {
  const SaveTimingRecordOperationPreviewAdapter({required this.analyzer});

  final SaveTimingRecordOperationAnalyzer analyzer;

  Future<SaveTimingRecordOperationPreviewResponse> preview(
    SaveTimingRecordOperationPreviewRequest request,
  ) async {
    final analysis = await analyzer.analyze(request.input);
    return SaveTimingRecordOperationPreviewResponse(
      analysis: analysis,
      preview: analysis.preview,
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
