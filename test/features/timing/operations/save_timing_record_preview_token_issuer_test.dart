import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_scope.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/core/operations/operation_confirmation_token.dart';
import 'package:asset_ledger/core/operations/operation_models.dart';
import 'package:asset_ledger/data/models/operation_token_record.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/operation_token_repository.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_analyzer.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_command.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_fingerprints.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_preview_adapter.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_preview_redactor.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_preview_token_issuer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaveTimingRecordPreviewTokenIssuer', () {
    final now = DateTime.utc(2026, 6, 1, 12, 0, 0);

    test('owner fullOwner signs and persists issued token fields', () async {
      final repo = _FakeTokenRepository();
      final issuer = _issuer(repo);
      final request = _request();
      final response = _adapterResponse(redacted: _redactedPreview());
      final scope = ActorScope.fullOwner(ownerId: 'owner-1');

      final result = await issuer.issue(
        request: request,
        previewResponse: response,
        actor: ActorContext(actorType: OperationActorType.owner),
        scope: scope,
        now: now,
        source: 'app',
      );

      expect(result.canProceedToConfirm, isTrue);
      expect(result.tokenId, 'tok-1');
      expect(result.expiresAt, now.add(const Duration(minutes: 5)));
      expect(result.unavailableReasonCode, isNull);
      expect(repo.records, hasLength(1));

      final token = repo.records.single.token;
      expect(token.tokenId, 'tok-1');
      expect(token.operationId, response.full.preview.operationId);
      expect(token.operationType, OperationType.saveTimingRecord);
      expect(token.actorType, OperationActorType.owner);
      expect(token.actorId, isNull);
      expect(token.sessionId, isNull);
      expect(token.source, 'app');
      expect(token.createdAt, now);
      expect(token.expiresAt, now.add(const Duration(minutes: 5)));
      expect(token.status, OperationConfirmationTokenStatus.issued);
      expect(token.freshnessRequired, isTrue);
      expect(token.requiresReanalysisBeforeExecute, isTrue);
      expect(token.oneTimeUse, isTrue);
      expect(
        token.actorScopeHash,
        OperationConfirmationFingerprint.stableHash(scope.toMap()),
      );
      expect(
        token.inputHash,
        SaveTimingRecordOperationFingerprints.inputHashFor(request.input),
      );
      expect(
        token.fullAnalysisHash,
        SaveTimingRecordOperationFingerprints.fullAnalysisHashFor(
          response.full.analysis,
        ),
      );
      expect(
        token.redactedPreviewHash,
        SaveTimingRecordOperationFingerprints.redactedPreviewHashFor(
          response.redacted,
        ),
      );
    });

    test('scope denied redacted preview does not sign', () async {
      final repo = _FakeTokenRepository();
      final result = await _issuer(repo).issue(
        request: _request(),
        previewResponse: _adapterResponse(
          redacted: _redactedPreview(scopeAllowed: false),
        ),
        actor: ActorContext(actorType: OperationActorType.owner),
        scope: ActorScope.fullOwner(ownerId: 'owner-1'),
        now: now,
      );

      expect(result.canProceedToConfirm, isFalse);
      expect(result.tokenId, isNull);
      expect(
        result.unavailableReasonCode,
        SaveTimingRecordPreviewTokenIssueReason.scopeNotAllowed,
      );
      expect(repo.records, isEmpty);
    });

    test('owner limited scope does not sign', () async {
      final repo = _FakeTokenRepository();
      final result = await _issuer(repo).issue(
        request: _request(),
        previewResponse: _adapterResponse(redacted: _redactedPreview()),
        actor: ActorContext(actorType: OperationActorType.owner),
        scope: ActorScope.devices(deviceIds: const ['7']),
        now: now,
      );

      expect(result.canProceedToConfirm, isFalse);
      expect(
        result.unavailableReasonCode,
        SaveTimingRecordPreviewTokenIssueReason.permissionDenied,
      );
      expect(repo.records, isEmpty);
    });

    test('driver and partner do not sign save timing tokens', () async {
      for (final actor in [
        ActorContext(actorType: OperationActorType.driver, actorId: 'driver-1'),
        ActorContext(
          actorType: OperationActorType.partner,
          actorId: 'partner-1',
        ),
      ]) {
        final repo = _FakeTokenRepository();
        final result = await _issuer(repo).issue(
          request: _request(),
          previewResponse: _adapterResponse(redacted: _redactedPreview()),
          actor: actor,
          scope: ActorScope.fullOwner(ownerId: 'owner-1'),
          now: now,
        );

        expect(result.canProceedToConfirm, isFalse);
        expect(
          result.unavailableReasonCode,
          SaveTimingRecordPreviewTokenIssueReason.permissionDenied,
        );
        expect(repo.records, isEmpty);
      }
    });

    test('bare agent does not sign', () async {
      final repo = _FakeTokenRepository();
      final result = await _issuer(repo).issue(
        request: _request(),
        previewResponse: _adapterResponse(redacted: _redactedPreview()),
        actor: ActorContext(
          actorType: OperationActorType.agent,
          actorId: 'agent-1',
        ),
        scope: ActorScope.fullOwner(ownerId: 'owner-1'),
        now: now,
      );

      expect(result.canProceedToConfirm, isFalse);
      expect(
        result.unavailableReasonCode,
        SaveTimingRecordPreviewTokenIssueReason.delegatedActorRequired,
      );
      expect(repo.records, isEmpty);
    });

    test('agent-as-owner with session and fullOwner signs', () async {
      final repo = _FakeTokenRepository();
      final actor = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-1',
        delegatedActorType: OperationActorType.owner,
        delegatedActorId: 'owner-1',
        sessionId: 'sess-1',
      );

      final result = await _issuer(repo).issue(
        request: _request(),
        previewResponse: _adapterResponse(redacted: _redactedPreview()),
        actor: actor,
        scope: ActorScope.fullOwner(ownerId: 'owner-1'),
        now: now,
      );

      expect(result.canProceedToConfirm, isTrue);
      final token = repo.records.single.token;
      expect(token.actorType, OperationActorType.agent);
      expect(token.actorId, 'agent-1');
      expect(token.delegatedActorType, OperationActorType.owner);
      expect(token.delegatedActorId, 'owner-1');
      expect(token.sessionId, 'sess-1');
    });

    test('agent-as-owner without session does not sign', () async {
      final repo = _FakeTokenRepository();
      final result = await _issuer(repo).issue(
        request: _request(),
        previewResponse: _adapterResponse(redacted: _redactedPreview()),
        actor: ActorContext(
          actorType: OperationActorType.agent,
          actorId: 'agent-1',
          delegatedActorType: OperationActorType.owner,
          delegatedActorId: 'owner-1',
        ),
        scope: ActorScope.fullOwner(ownerId: 'owner-1'),
        now: now,
      );

      expect(result.canProceedToConfirm, isFalse);
      expect(
        result.unavailableReasonCode,
        SaveTimingRecordPreviewTokenIssueReason.sessionRequired,
      );
      expect(repo.records, isEmpty);
    });

    test('agent delegated to driver or partner does not sign', () async {
      for (final delegated in [
        OperationActorType.driver,
        OperationActorType.partner,
      ]) {
        final repo = _FakeTokenRepository();
        final result = await _issuer(repo).issue(
          request: _request(),
          previewResponse: _adapterResponse(redacted: _redactedPreview()),
          actor: ActorContext(
            actorType: OperationActorType.agent,
            actorId: 'agent-1',
            delegatedActorType: delegated,
            delegatedActorId: 'delegate-1',
            sessionId: 'sess-1',
          ),
          scope: ActorScope.fullOwner(ownerId: 'owner-1'),
          now: now,
        );

        expect(result.canProceedToConfirm, isFalse);
        expect(
          result.unavailableReasonCode,
          SaveTimingRecordPreviewTokenIssueReason.permissionDenied,
        );
        expect(repo.records, isEmpty);
      }
    });

    test('expired scope does not sign', () async {
      final repo = _FakeTokenRepository();
      final result = await _issuer(repo).issue(
        request: _request(),
        previewResponse: _adapterResponse(redacted: _redactedPreview()),
        actor: ActorContext(actorType: OperationActorType.owner),
        scope: ActorScope.fullOwner(ownerId: 'owner-1', expiresAt: now),
        now: now,
      );

      expect(result.canProceedToConfirm, isFalse);
      expect(
        result.unavailableReasonCode,
        SaveTimingRecordPreviewTokenIssueReason.scopeExpired,
      );
      expect(repo.records, isEmpty);
    });

    test('ttl is clipped by scope expiry', () async {
      final repo = _FakeTokenRepository();
      final scopeExpiresAt = now.add(const Duration(minutes: 2));
      final result = await _issuer(repo).issue(
        request: _request(),
        previewResponse: _adapterResponse(redacted: _redactedPreview()),
        actor: ActorContext(actorType: OperationActorType.owner),
        scope: ActorScope.fullOwner(
          ownerId: 'owner-1',
          expiresAt: scopeExpiresAt,
        ),
        now: now,
      );

      expect(result.canProceedToConfirm, isTrue);
      expect(result.expiresAt, scopeExpiresAt);
      expect(repo.records.single.expiresAt, scopeExpiresAt);
    });

    test(
      'insert failure returns redacted preview caller a closed issue result',
      () async {
        final repo = _FakeTokenRepository()
          ..insertError = StateError('disk full');
        final result = await _issuer(repo).issue(
          request: _request(),
          previewResponse: _adapterResponse(redacted: _redactedPreview()),
          actor: ActorContext(actorType: OperationActorType.owner),
          scope: ActorScope.fullOwner(ownerId: 'owner-1'),
          now: now,
        );

        expect(result.canProceedToConfirm, isFalse);
        expect(result.tokenId, isNull);
        expect(result.expiresAt, isNull);
        expect(
          result.unavailableReasonCode,
          SaveTimingRecordPreviewTokenIssueReason.tokenInsertFailed,
        );
        expect(repo.records, isEmpty);
      },
    );
  });
}

SaveTimingRecordPreviewTokenIssuer _issuer(_FakeTokenRepository repo) {
  return SaveTimingRecordPreviewTokenIssuer(
    tokenRepository: repo,
    tokenIdFactory: () => 'tok-${repo.records.length + 1}',
  );
}

SaveTimingRecordOperationPreviewRequest _request() {
  return SaveTimingRecordOperationPreviewRequest(input: _input());
}

SaveTimingRecordOperationAnalyzeInput _input() {
  return SaveTimingRecordOperationAnalyzeInput(
    operationId: 'op-service-1',
    draftRecord: const TimingRecord(
      id: 1,
      deviceId: 7,
      startDate: 20260531,
      projectId: 'project-a',
      contact: '李杰',
      site: '五里山',
      type: TimingType.hours,
      startMeter: 10,
      endMeter: 17,
      hours: 7,
      income: 700,
    ),
    editingRecordId: 1,
  );
}

SaveTimingRecordOperationRedactedPreviewResponse _adapterResponse({
  required RedactedSaveTimingRecordPreview redacted,
}) {
  final previewInput = SaveTimingRecordOperationPreviewInput(
    operationId: redacted.preview.operationId,
    isEditing: true,
    timingRecordId: '1',
    deviceLabel: 'Hitachi',
    projectLabel: '李杰 · 五里山',
    affectedEntities: redacted.preview.affectedEntities,
    warnings: redacted.preview.warnings,
  );
  final preview = OperationPreview(
    operationId: redacted.preview.operationId,
    operationType: OperationType.saveTimingRecord,
    title: '修改计时记录',
    summary: '编辑计时；设备：Hitachi；项目：李杰 · 五里山',
    requiresConfirmation: true,
    riskLevel: OperationRiskLevel.high,
  );
  final analysis = SaveTimingRecordOperationAnalyzeResult(
    previewInput: previewInput,
    preview: preview,
    oldProjectId: 'project-a',
    existingNewProjectId: 'project-a',
    wouldCreateNewProject: false,
    affectedProjectIds: const ['project-a'],
    mergeGroupIdsToDissolve: const [],
    requiresReanalysisBeforeExecute: true,
    warnings: previewInput.warnings,
  );
  return SaveTimingRecordOperationRedactedPreviewResponse(
    full: SaveTimingRecordOperationPreviewResponse(
      analysis: analysis,
      preview: preview,
    ),
    redacted: redacted,
  );
}

RedactedSaveTimingRecordPreview _redactedPreview({bool scopeAllowed = true}) {
  return RedactedSaveTimingRecordPreview(
    preview: const OperationPreview(
      operationId: 'op-service-1',
      operationType: OperationType.saveTimingRecord,
      title: '修改计时记录',
      summary: '编辑计时；设备：Hitachi；项目：李杰 · 五里山',
      warnings: ['预览基于当前本地数据'],
      affectedEntities: [
        OperationEntityRef(
          entityType: 'device',
          entityId: '7',
          label: 'Hitachi',
          deviceId: '7',
        ),
      ],
      requiresConfirmation: true,
      riskLevel: OperationRiskLevel.medium,
    ),
    analysis: const RedactedSaveTimingRecordAnalysis(
      wouldCreateNewProject: false,
      willDissolveMerge: false,
      willRevokeSettlement: false,
      oldProjectId: 'project-a',
      existingNewProjectId: 'project-a',
      affectedProjectIds: ['project-a'],
      mergeGroupIdsToDissolve: [],
      warnings: ['预览基于当前本地数据'],
    ),
    freshness: null,
    redacted: false,
    redactionReasons: const [],
    visibleCapabilities: const [],
    hiddenCapabilities: const [],
    scopeAllowed: scopeAllowed,
    scopeReasons: scopeAllowed ? const [] : const ['scope missing'],
  );
}

class _FakeTokenRepository implements OperationTokenRepository {
  final records = <OperationTokenRecord>[];
  Object? insertError;

  @override
  Future<void> insert(OperationTokenRecord record) async {
    final error = insertError;
    if (error != null) throw error;
    records.add(record);
  }

  @override
  Future<void> insertWithExecutor(
    Object? executor,
    OperationTokenRecord record,
  ) {
    return insert(record);
  }

  @override
  Future<OperationTokenRecord?> findById(String id) async {
    return records.where((record) => record.id == id).firstOrNull;
  }

  @override
  Future<OperationTokenRecord?> findByIdWithExecutor(
    Object? executor,
    String id,
  ) {
    return findById(id);
  }

  @override
  Future<List<OperationTokenRecord>> listByOperationId(
    String operationId,
  ) async {
    return records
        .where((record) => record.operationId == operationId)
        .toList(growable: false);
  }

  @override
  Future<List<OperationTokenRecord>> listActiveByActorSession({
    required OperationActorType actorType,
    String? actorId,
    String? sessionId,
    required DateTime now,
    int limit = 50,
  }) async {
    return const [];
  }

  @override
  Future<bool> claimForConsume({
    required String id,
    required DateTime now,
  }) async {
    return false;
  }

  @override
  Future<bool> claimForConsumeWithExecutor(
    Object? executor, {
    required String id,
    required DateTime now,
  }) async {
    return false;
  }

  @override
  Future<bool> markCancelled({
    required String id,
    required DateTime cancelledAt,
    String? reason,
  }) async {
    return false;
  }

  @override
  Future<int> markExpiredBefore(DateTime now) async {
    return 0;
  }
}
