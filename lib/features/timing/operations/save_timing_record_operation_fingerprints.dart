import '../../../core/operations/operation_confirmation_token.dart';
import 'save_timing_record_operation_analyzer.dart';
import 'save_timing_record_preview_redactor.dart';

abstract final class SaveTimingRecordOperationFingerprints {
  static String inputHashFor(SaveTimingRecordOperationAnalyzeInput input) {
    return OperationConfirmationFingerprint.stableHash(
      _analyzeInputCanonicalMap(input),
    );
  }

  static String fullAnalysisHashFor(
    SaveTimingRecordOperationAnalyzeResult result,
  ) {
    return OperationConfirmationFingerprint.stableHash(
      _analysisCanonicalMap(result),
    );
  }

  static String redactedPreviewHashFor(
    RedactedSaveTimingRecordPreview redacted,
  ) {
    return OperationConfirmationFingerprint.stableHash(redacted.toMap());
  }

  static Map<String, Object?> _analyzeInputCanonicalMap(
    SaveTimingRecordOperationAnalyzeInput input,
  ) {
    return {
      'operation_id': input.operationId,
      'editing_record_id': input.editingRecordId,
      'draft': input.draftRecord.toMap(),
    };
  }

  static Map<String, Object?> _analysisCanonicalMap(
    SaveTimingRecordOperationAnalyzeResult result,
  ) {
    final affectedProjectIds = [...result.affectedProjectIds]..sort();
    final mergeGroupIds = [...result.mergeGroupIdsToDissolve]..sort();
    final warnings = [...result.warnings]..sort();
    final input = result.previewInput;
    return {
      'preview': result.preview.toMap(),
      'old_project_id': result.oldProjectId,
      'existing_new_project_id': result.existingNewProjectId,
      'would_create_new_project': result.wouldCreateNewProject,
      'affected_project_ids': affectedProjectIds,
      'merge_group_ids_to_dissolve': mergeGroupIds,
      'requires_reanalysis_before_execute':
          result.requiresReanalysisBeforeExecute,
      'warnings': warnings,
      'preview_input': {
        'operation_id': input.operationId,
        'is_editing': input.isEditing,
        'timing_record_id': input.timingRecordId,
        'device_label': input.deviceLabel,
        'project_label': input.projectLabel,
        'old_project_label': input.oldProjectLabel,
        'new_project_label': input.newProjectLabel,
        'project_changed': input.projectChanged,
        'will_dissolve_merge': input.willDissolveMerge,
        'will_revoke_settlement': input.willRevokeSettlement,
      },
    };
  }
}
