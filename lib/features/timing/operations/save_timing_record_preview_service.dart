import '../../../core/operations/operation_access_control.dart';
import '../../../core/operations/operation_actor_scope.dart';
import 'save_timing_record_operation_preview_adapter.dart';
import 'save_timing_record_preview_redactor.dart';
import 'save_timing_record_preview_token_issuer.dart';

class SaveTimingRecordPreviewService {
  const SaveTimingRecordPreviewService({
    required this.previewAdapter,
    this.tokenIssuer,
  });

  final SaveTimingRecordOperationPreviewAdapter previewAdapter;
  final SaveTimingRecordPreviewTokenIssuer? tokenIssuer;

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

  Future<SaveTimingRecordPreviewServiceResponse> previewWithToken({
    required SaveTimingRecordOperationPreviewRequest request,
    required ActorContext actor,
    required ActorScope scope,
    DateTime? now,
    String? sessionId,
    String? source,
  }) async {
    final checkedNow = now ?? DateTime.now().toUtc();
    final response = await previewAdapter.previewForActor(
      request: request,
      actor: actor,
      scope: scope,
      now: checkedNow,
    );
    final redacted = response.redacted;
    final issuer = tokenIssuer;
    final issue = issuer == null
        ? SaveTimingRecordPreviewTokenIssueResult.unavailable(
            SaveTimingRecordPreviewTokenIssueReason.tokenIssuerUnavailable,
          )
        : await issuer.issue(
            request: request,
            previewResponse: response,
            actor: actor,
            scope: scope,
            now: checkedNow,
            sessionId: sessionId,
            source: source,
          );
    return SaveTimingRecordPreviewServiceResponse(
      preview: redacted,
      operationId: redacted.preview.operationId,
      canProceedToConfirm: issue.canProceedToConfirm,
      requiresReanalysisBeforeExecute: true,
      warnings: redacted.preview.warnings,
      confirmationTokenId: issue.tokenId,
      confirmationExpiresAt: issue.expiresAt,
      confirmUnavailableReasonCode: issue.unavailableReasonCode,
    );
  }
}

class SaveTimingRecordPreviewServiceResponse {
  SaveTimingRecordPreviewServiceResponse({
    required this.preview,
    required this.operationId,
    required this.canProceedToConfirm,
    required this.requiresReanalysisBeforeExecute,
    this.confirmationTokenId,
    this.confirmationExpiresAt,
    this.confirmUnavailableReasonCode,
    List<String> warnings = const [],
  }) : warnings = List.unmodifiable(warnings);

  final RedactedSaveTimingRecordPreview preview;
  final String operationId;
  final bool canProceedToConfirm;
  final bool requiresReanalysisBeforeExecute;
  final String? confirmationTokenId;
  final DateTime? confirmationExpiresAt;
  final String? confirmUnavailableReasonCode;
  final List<String> warnings;
}
