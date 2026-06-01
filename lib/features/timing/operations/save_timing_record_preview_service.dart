import '../../../core/operations/operation_access_control.dart';
import '../../../core/operations/operation_actor_scope.dart';
import 'save_timing_record_operation_preview_adapter.dart';
import 'save_timing_record_preview_redactor.dart';

class SaveTimingRecordPreviewService {
  const SaveTimingRecordPreviewService({required this.previewAdapter});

  final SaveTimingRecordOperationPreviewAdapter previewAdapter;

  Future<SaveTimingRecordPreviewServiceResponse> preview({
    required SaveTimingRecordOperationPreviewRequest request,
    required ActorContext actor,
    required ActorScope scope,
    DateTime? now,
  }) async {
    final response = await previewAdapter.previewForActor(
      request: request,
      actor: actor,
      scope: scope,
      now: now,
    );
    final redacted = response.redacted;
    return SaveTimingRecordPreviewServiceResponse(
      preview: redacted,
      operationId: redacted.preview.operationId,
      canProceedToConfirm: false,
      requiresReanalysisBeforeExecute: true,
      warnings: redacted.preview.warnings,
    );
  }
}

class SaveTimingRecordPreviewServiceResponse {
  SaveTimingRecordPreviewServiceResponse({
    required this.preview,
    required this.operationId,
    required this.canProceedToConfirm,
    required this.requiresReanalysisBeforeExecute,
    List<String> warnings = const [],
  }) : warnings = List.unmodifiable(warnings);

  final RedactedSaveTimingRecordPreview preview;
  final String operationId;
  final bool canProceedToConfirm;
  final bool requiresReanalysisBeforeExecute;
  final List<String> warnings;
}
