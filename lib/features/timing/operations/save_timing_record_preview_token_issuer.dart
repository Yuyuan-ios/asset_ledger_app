import '../../../core/operations/operation_access_control.dart';
import '../../../core/operations/operation_actor_scope.dart';
import '../../../core/operations/operation_actor_type.dart';
import '../../../core/operations/operation_confirmation_token.dart';
import '../../../core/operations/operation_models.dart';
import '../../../data/models/operation_token_record.dart';
import '../../../data/repositories/operation_token_repository.dart';
import 'save_timing_record_operation_fingerprints.dart';
import 'save_timing_record_operation_preview_adapter.dart';

class SaveTimingRecordPreviewTokenIssuer {
  const SaveTimingRecordPreviewTokenIssuer({
    required this.tokenRepository,
    required this.tokenIdFactory,
    this.tokenTtl = const Duration(minutes: 5),
    OperationPermissionPolicy? permissionPolicy,
  }) : permissionPolicy = permissionPolicy ?? const OperationPermissionPolicy();

  final OperationTokenRepository tokenRepository;
  final String Function() tokenIdFactory;
  final Duration tokenTtl;
  final OperationPermissionPolicy permissionPolicy;

  Future<SaveTimingRecordPreviewTokenIssueResult> issue({
    required SaveTimingRecordOperationPreviewRequest request,
    required SaveTimingRecordOperationRedactedPreviewResponse previewResponse,
    required ActorContext actor,
    required ActorScope scope,
    required DateTime now,
    String? sessionId,
    String? source,
  }) async {
    final checkedNow = now.toUtc();
    final redacted = previewResponse.redacted;
    if (!redacted.scopeAllowed) {
      return SaveTimingRecordPreviewTokenIssueResult.unavailable(
        SaveTimingRecordPreviewTokenIssueReason.scopeNotAllowed,
      );
    }
    if (scope.isExpired(checkedNow)) {
      return SaveTimingRecordPreviewTokenIssueResult.unavailable(
        SaveTimingRecordPreviewTokenIssueReason.scopeExpired,
      );
    }
    if (actor.isAgent && !actor.hasDelegatedScope) {
      return SaveTimingRecordPreviewTokenIssueResult.unavailable(
        SaveTimingRecordPreviewTokenIssueReason.delegatedActorRequired,
      );
    }
    if (!_canSignForActor(actor: actor, scope: scope)) {
      return SaveTimingRecordPreviewTokenIssueResult.unavailable(
        SaveTimingRecordPreviewTokenIssueReason.permissionDenied,
      );
    }

    final resolvedSessionId = _trimToNull(sessionId) ?? actor.sessionId;
    if (actor.isAgent && _trimToNull(resolvedSessionId) == null) {
      return SaveTimingRecordPreviewTokenIssueResult.unavailable(
        SaveTimingRecordPreviewTokenIssueReason.sessionRequired,
      );
    }

    final expiresAt = _resolveExpiresAt(scope: scope, now: checkedNow);
    if (!expiresAt.isAfter(checkedNow)) {
      return SaveTimingRecordPreviewTokenIssueResult.unavailable(
        SaveTimingRecordPreviewTokenIssueReason.tokenExpired,
      );
    }

    final token = OperationConfirmationToken(
      tokenId: tokenIdFactory(),
      operationId: previewResponse.full.preview.operationId,
      operationType: OperationType.saveTimingRecord,
      actorType: actor.actorType,
      actorId: actor.actorId,
      delegatedActorType: actor.delegatedActorType,
      delegatedActorId: actor.delegatedActorId,
      sessionId: resolvedSessionId,
      source: _trimToNull(source) ?? actor.source,
      createdAt: checkedNow,
      expiresAt: expiresAt,
      inputHash: SaveTimingRecordOperationFingerprints.inputHashFor(
        request.input,
      ),
      fullAnalysisHash:
          SaveTimingRecordOperationFingerprints.fullAnalysisHashFor(
            previewResponse.full.analysis,
          ),
      redactedPreviewHash:
          SaveTimingRecordOperationFingerprints.redactedPreviewHashFor(
            redacted,
          ),
      actorScopeHash: OperationConfirmationFingerprint.stableHash(
        scope.toMap(),
      ),
      freshnessRequired: true,
      requiresReanalysisBeforeExecute: true,
      oneTimeUse: true,
      status: OperationConfirmationTokenStatus.issued,
    );

    try {
      await tokenRepository.insert(OperationTokenRecord(token: token));
    } catch (_) {
      return SaveTimingRecordPreviewTokenIssueResult.unavailable(
        SaveTimingRecordPreviewTokenIssueReason.tokenInsertFailed,
      );
    }

    return SaveTimingRecordPreviewTokenIssueResult.issued(
      tokenId: token.tokenId,
      expiresAt: token.expiresAt,
    );
  }

  bool _canSignForActor({
    required ActorContext actor,
    required ActorScope scope,
  }) {
    if (!scope.isFullOwner) return false;
    if (actor.isAgent) {
      return actor.delegatedActorType == OperationActorType.owner;
    }
    final decision = permissionPolicy.canPerform(
      actor: actor,
      action: OperationPermissionAction.executeSaveTimingRecord,
    );
    return decision.allowed && actor.isOwner;
  }

  DateTime _resolveExpiresAt({
    required ActorScope scope,
    required DateTime now,
  }) {
    final base = now.add(tokenTtl);
    final scopeExpiresAt = scope.expiresAt;
    if (scopeExpiresAt != null && scopeExpiresAt.isBefore(base)) {
      return scopeExpiresAt.toUtc();
    }
    return base;
  }

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}

class SaveTimingRecordPreviewTokenIssueResult {
  const SaveTimingRecordPreviewTokenIssueResult._({
    required this.tokenId,
    required this.expiresAt,
    required this.canProceedToConfirm,
    required this.unavailableReasonCode,
  });

  final String? tokenId;
  final DateTime? expiresAt;
  final bool canProceedToConfirm;
  final String? unavailableReasonCode;

  factory SaveTimingRecordPreviewTokenIssueResult.issued({
    required String tokenId,
    required DateTime expiresAt,
  }) {
    return SaveTimingRecordPreviewTokenIssueResult._(
      tokenId: tokenId,
      expiresAt: expiresAt,
      canProceedToConfirm: true,
      unavailableReasonCode: null,
    );
  }

  factory SaveTimingRecordPreviewTokenIssueResult.unavailable(
    String reasonCode,
  ) {
    return SaveTimingRecordPreviewTokenIssueResult._(
      tokenId: null,
      expiresAt: null,
      canProceedToConfirm: false,
      unavailableReasonCode: reasonCode,
    );
  }
}

abstract final class SaveTimingRecordPreviewTokenIssueReason {
  static const scopeNotAllowed = 'scope_not_allowed';
  static const scopeExpired = 'scope_expired';
  static const permissionDenied = 'permission_denied';
  static const delegatedActorRequired = 'delegated_actor_required';
  static const sessionRequired = 'session_required';
  static const tokenExpired = 'token_expired';
  static const tokenInsertFailed = 'token_insert_failed';
  static const tokenIssuerUnavailable = 'token_issuer_unavailable';
}
