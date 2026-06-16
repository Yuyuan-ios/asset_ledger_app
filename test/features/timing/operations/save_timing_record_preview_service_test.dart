import 'dart:convert';

import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_scope.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/core/operations/operation_confirmation_token.dart';
import 'package:asset_ledger/core/operations/operation_models.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/operation_audit_log.dart';
import 'package:asset_ledger/data/models/operation_token_record.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/operation_audit_log_repository.dart';
import 'package:asset_ledger/data/repositories/operation_token_repository.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_analyzer.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_command.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_confirm_adapter.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_preview_adapter.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_preview_redactor.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_preview_service.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_preview_token_issuer.dart';
import 'package:asset_ledger/features/timing/use_cases/save_timing_record_with_impact_use_case.dart';
import 'package:asset_ledger/infrastructure/local/operations/local_operation_transaction_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  group('SaveTimingRecordPreviewService', () {
    test('preview delegates to adapter.previewForActor', () async {
      final redacted = _redactedPreview();
      final adapter = _FakePreviewAdapter(
        response: _adapterResponse(redacted: redacted),
      );
      final service = SaveTimingRecordPreviewService(previewAdapter: adapter);
      final request = SaveTimingRecordOperationPreviewRequest(input: _input());
      final actor = ActorContext(actorType: OperationActorType.owner);
      final scope = ActorScope.fullOwner(ownerId: 'owner-1');
      final now = DateTime.utc(2026, 1, 1);

      final result = await service.preview(
        request: request,
        actor: actor,
        scope: scope,
        now: now,
      );

      expect(adapter.calls, 1);
      expect(adapter.lastRequest, same(request));
      expect(adapter.lastActor, same(actor));
      expect(adapter.lastScope, same(scope));
      expect(adapter.lastNow, same(now));
      expect(result.preview, same(redacted));
    });

    test('response exposes redacted projection only', () async {
      final redacted = _redactedPreview(
        operationId: 'op-service-only-redacted',
        warnings: ['安全提示'],
      );
      final service = SaveTimingRecordPreviewService(
        previewAdapter: _FakePreviewAdapter(
          response: _adapterResponse(redacted: redacted),
        ),
      );

      final result = await service.preview(
        request: SaveTimingRecordOperationPreviewRequest(input: _input()),
        actor: ActorContext(actorType: OperationActorType.owner),
        scope: ActorScope.fullOwner(ownerId: 'owner-1'),
      );

      expect(result.preview, same(redacted));
      expect(result.operationId, 'op-service-only-redacted');
      expect(result.warnings, ['安全提示']);
      expect(result.canProceedToConfirm, isFalse);
      expect(result.confirmationTokenId, isNull);
      expect(result.confirmationExpiresAt, isNull);
      expect(result.confirmUnavailableReasonCode, isNull);
    });

    test('owner response keeps passthrough projection', () async {
      final redacted = _redactedPreview(redacted: false, scopeAllowed: true);
      final service = SaveTimingRecordPreviewService(
        previewAdapter: _FakePreviewAdapter(
          response: _adapterResponse(redacted: redacted),
        ),
      );

      final result = await service.preview(
        request: SaveTimingRecordOperationPreviewRequest(input: _input()),
        actor: ActorContext(actorType: OperationActorType.owner),
        scope: ActorScope.fullOwner(ownerId: 'owner-1'),
      );

      expect(result.preview.redacted, isFalse);
      expect(result.preview.scopeAllowed, isTrue);
      expect(result.canProceedToConfirm, isFalse);
    });

    test('driver denied response stays minimal shell', () async {
      final redacted = _redactedPreview(
        redacted: true,
        scopeAllowed: false,
        summary: '预览内容已隐藏',
        affectedEntities: [],
        impactItems: [],
        warnings: [],
        scopeReasons: ['device not in actor scope'],
      );
      final service = SaveTimingRecordPreviewService(
        previewAdapter: _FakePreviewAdapter(
          response: _adapterResponse(redacted: redacted),
        ),
      );

      final result = await service.preview(
        request: SaveTimingRecordOperationPreviewRequest(input: _input()),
        actor: ActorContext(
          actorType: OperationActorType.driver,
          actorId: 'driver-1',
        ),
        scope: ActorScope.devices(deviceIds: ['99'], actorId: 'driver-1'),
      );

      expect(result.preview.scopeAllowed, isFalse);
      expect(result.preview.preview.summary, '预览内容已隐藏');
      expect(result.preview.preview.affectedEntities, isEmpty);
      expect(result.preview.preview.impactItems, isEmpty);
      expect(result.canProceedToConfirm, isFalse);
    });

    test('driver allowed response returns partial projection', () async {
      final redacted = _redactedPreview(
        redacted: true,
        scopeAllowed: true,
        summary: '编辑计时；设备：Hitachi',
        affectedEntities: [
          OperationEntityRef(
            entityType: 'device',
            entityId: 'device:hidden',
            label: 'Hitachi',
          ),
        ],
        warnings: ['预览基于当前本地数据，执行前必须重新分析确认。'],
      );
      final service = SaveTimingRecordPreviewService(
        previewAdapter: _FakePreviewAdapter(
          response: _adapterResponse(redacted: redacted),
        ),
      );

      final result = await service.preview(
        request: SaveTimingRecordOperationPreviewRequest(input: _input()),
        actor: ActorContext(
          actorType: OperationActorType.driver,
          actorId: 'driver-1',
        ),
        scope: ActorScope.devices(deviceIds: ['7'], actorId: 'driver-1'),
      );

      expect(result.preview.redacted, isTrue);
      expect(result.preview.scopeAllowed, isTrue);
      expect(result.preview.preview.summary, '编辑计时；设备：Hitachi');
      expect(
        result.preview.preview.affectedEntities.single.entityId,
        'device:hidden',
      );
      expect(result.canProceedToConfirm, isFalse);
    });

    test('canProceedToConfirm is always false', () async {
      for (final actorAndScope in [
        (
          actor: ActorContext(actorType: OperationActorType.owner),
          scope: ActorScope.fullOwner(ownerId: 'owner-1'),
        ),
        (
          actor: ActorContext(
            actorType: OperationActorType.driver,
            actorId: 'driver-1',
          ),
          scope: ActorScope.devices(deviceIds: ['7'], actorId: 'driver-1'),
        ),
      ]) {
        final service = SaveTimingRecordPreviewService(
          previewAdapter: _FakePreviewAdapter(
            response: _adapterResponse(redacted: _redactedPreview()),
          ),
        );

        final result = await service.preview(
          request: SaveTimingRecordOperationPreviewRequest(input: _input()),
          actor: actorAndScope.actor,
          scope: actorAndScope.scope,
        );

        expect(result.canProceedToConfirm, isFalse);
        expect(result.confirmationTokenId, isNull);
        expect(result.confirmationExpiresAt, isNull);
      }
    });

    test('requiresReanalysisBeforeExecute is fixed to true', () async {
      final service = SaveTimingRecordPreviewService(
        previewAdapter: _FakePreviewAdapter(
          response: _adapterResponse(redacted: _redactedPreview()),
        ),
      );

      final result = await service.preview(
        request: SaveTimingRecordOperationPreviewRequest(input: _input()),
        actor: ActorContext(actorType: OperationActorType.owner),
        scope: ActorScope.fullOwner(ownerId: 'owner-1'),
      );

      expect(result.requiresReanalysisBeforeExecute, isTrue);
    });

    test('adapter error propagates without a success response', () async {
      final service = SaveTimingRecordPreviewService(
        previewAdapter: _FakePreviewAdapter(
          response: _adapterResponse(redacted: _redactedPreview()),
          error: StateError('preview failed'),
        ),
      );

      await expectLater(
        service.preview(
          request: SaveTimingRecordOperationPreviewRequest(input: _input()),
          actor: ActorContext(actorType: OperationActorType.owner),
          scope: ActorScope.fullOwner(ownerId: 'owner-1'),
        ),
        throwsStateError,
      );
    });

    test(
      'previewWithToken signs only through token issuer handle fields',
      () async {
        final redacted = _redactedPreview();
        final tokenRepo = _FakeTokenRepository();
        final service = SaveTimingRecordPreviewService(
          previewAdapter: _FakePreviewAdapter(
            response: _adapterResponse(redacted: redacted),
          ),
          tokenIssuer: SaveTimingRecordPreviewTokenIssuer(
            tokenRepository: tokenRepo,
            tokenIdFactory: () => 'tok-1',
          ),
        );
        final now = DateTime.utc(2026, 6, 1, 12, 0);

        final result = await service.previewWithToken(
          request: SaveTimingRecordOperationPreviewRequest(input: _input()),
          actor: ActorContext(actorType: OperationActorType.owner),
          scope: ActorScope.fullOwner(ownerId: 'owner-1'),
          now: now,
        );

        expect(result.preview, same(redacted));
        expect(result.canProceedToConfirm, isTrue);
        expect(result.confirmationTokenId, 'tok-1');
        expect(
          result.confirmationExpiresAt,
          now.add(const Duration(minutes: 5)),
        );
        expect(result.confirmUnavailableReasonCode, isNull);
        expect(tokenRepo.records, hasLength(1));
        expect(tokenRepo.records.single.id, 'tok-1');
      },
    );

    test('previewWithToken without issuer fails closed', () async {
      final redacted = _redactedPreview();
      final service = SaveTimingRecordPreviewService(
        previewAdapter: _FakePreviewAdapter(
          response: _adapterResponse(redacted: redacted),
        ),
      );

      final result = await service.previewWithToken(
        request: SaveTimingRecordOperationPreviewRequest(input: _input()),
        actor: ActorContext(actorType: OperationActorType.owner),
        scope: ActorScope.fullOwner(ownerId: 'owner-1'),
        now: DateTime.utc(2026, 6, 1, 12, 0),
      );

      expect(result.preview, same(redacted));
      expect(result.canProceedToConfirm, isFalse);
      expect(result.confirmationTokenId, isNull);
      expect(result.confirmationExpiresAt, isNull);
      expect(
        result.confirmUnavailableReasonCode,
        SaveTimingRecordPreviewTokenIssueReason.tokenIssuerUnavailable,
      );
    });
  });

  group('previewWithToken -> executeConfirmedWithToken e2e', () {
    final actor = ActorContext(actorType: OperationActorType.owner);
    final scope = ActorScope.fullOwner(ownerId: 'owner-1');
    final now = DateTime.utc(2026, 6, 1, 12, 0);

    late SqfliteOperationTokenRepository tokenRepository;
    late SqfliteOperationAuditLogRepository auditRepository;

    setUp(() async {
      await AppDatabase.resetForTest();
      await _openCurrentInMemoryDb();
      tokenRepository = SqfliteOperationTokenRepository();
      auditRepository = SqfliteOperationAuditLogRepository();
    });

    tearDown(() async {
      await AppDatabase.resetForTest();
    });

    test(
      'previewWithToken issued token can be consumed by executeConfirmedWithToken',
      () async {
        final request = SaveTimingRecordOperationPreviewRequest(
          input: _input(),
        );
        final previewAdapter = _FakePreviewAdapter(
          response: _adapterResponse(redacted: _redactedPreview()),
        );
        final service = SaveTimingRecordPreviewService(
          previewAdapter: previewAdapter,
          tokenIssuer: SaveTimingRecordPreviewTokenIssuer(
            tokenRepository: tokenRepository,
            tokenIdFactory: () => 'tok-e2e',
          ),
        );

        final previewResult = await service.previewWithToken(
          request: request,
          actor: actor,
          scope: scope,
          now: now,
        );

        expect(previewResult.canProceedToConfirm, isTrue);
        expect(previewResult.confirmationTokenId, 'tok-e2e');
        expect(previewResult.confirmationExpiresAt, isNotNull);
        expect(previewResult.confirmUnavailableReasonCode, isNull);

        final issued = await tokenRepository.findById('tok-e2e');
        expect(issued, isNotNull);
        expect(issued!.status, OperationConfirmationTokenStatus.issued);

        var auditSequence = 0;
        final command = SaveTimingRecordOperationCommand(
          transactionRunner: const LocalOperationTransactionRunner(),
          auditRepository: auditRepository,
          auditIdFactory: () => 'audit-e2e-${++auditSequence}',
        );
        final confirmAdapter = SaveTimingRecordOperationConfirmAdapter(
          analyzer: _FreshAnalyzer(),
          command: command,
          tokenRepository: tokenRepository,
          auditRepository: auditRepository,
          auditIdFactory: () => 'audit-e2e-${++auditSequence}',
        );
        final full = previewAdapter.response.full;
        final redactedPreviewHash = issued.token.redactedPreviewHash;
        var businessCalls = 0;

        final result = await confirmAdapter.executeConfirmedWithToken(
          analyzeInput: request.input,
          previousAnalyzeResult: full.analysis,
          operationId: full.preview.operationId,
          tokenId: 'tok-e2e',
          actor: actor,
          scope: scope,
          now: now,
          redactedPreviewHash: redactedPreviewHash,
          executeSaveWithExecutor: (_) async {
            businessCalls += 1;
            return _saveResult(userMessage: 'saved through e2e');
          },
        );

        expect(result.success, isTrue);
        expect(businessCalls, 1);
        expect(
          (await tokenRepository.findById('tok-e2e'))!.status,
          OperationConfirmationTokenStatus.consumed,
        );

        final successLogs = await auditRepository.listByTokenId('tok-e2e');
        expect(successLogs, hasLength(1));
        final successAudit = successLogs.single;
        expect(successAudit.id, 'audit-e2e-1');
        expect(successAudit.result, OperationAuditResult.success);
        expect(successAudit.confirmed, isTrue);
        expect(successAudit.tokenId, 'tok-e2e');

        final replay = await confirmAdapter.executeConfirmedWithToken(
          analyzeInput: request.input,
          previousAnalyzeResult: full.analysis,
          operationId: full.preview.operationId,
          tokenId: 'tok-e2e',
          actor: actor,
          scope: scope,
          now: now,
          redactedPreviewHash: redactedPreviewHash,
          executeSaveWithExecutor: (_) async {
            businessCalls += 1;
            return _saveResult(userMessage: 'should not run');
          },
        );

        expect(replay.success, isFalse);
        expect(replay.error, contains('token_not_issued'));
        expect(businessCalls, 1);

        final logsAfterReplay = await auditRepository.listByTokenId('tok-e2e');
        expect(logsAfterReplay, hasLength(2));
        expect(logsAfterReplay.first.result, OperationAuditResult.success);
        final replayAudit = logsAfterReplay.last;
        expect(replayAudit.result, OperationAuditResult.failure);
        expect(replayAudit.confirmed, isTrue);
        expect(replayAudit.tokenId, 'tok-e2e');
        final errorJson =
            jsonDecode(replayAudit.errorMessage!) as Map<String, Object?>;
        expect(errorJson['code'], 'token_invalid');
        expect(errorJson['reasons'], ['token_not_issued']);
      },
    );

    test(
      'previewWithToken denied actor does not create consumable token',
      () async {
        final previewAdapter = _FakePreviewAdapter(
          response: _adapterResponse(redacted: _redactedPreview()),
        );
        final service = SaveTimingRecordPreviewService(
          previewAdapter: previewAdapter,
          tokenIssuer: SaveTimingRecordPreviewTokenIssuer(
            tokenRepository: tokenRepository,
            tokenIdFactory: () => 'tok-denied',
          ),
        );

        final result = await service.previewWithToken(
          request: SaveTimingRecordOperationPreviewRequest(input: _input()),
          actor: ActorContext(
            actorType: OperationActorType.driver,
            actorId: 'driver-1',
          ),
          scope: scope,
          now: now,
        );

        expect(result.canProceedToConfirm, isFalse);
        expect(result.confirmationTokenId, isNull);
        expect(result.confirmationExpiresAt, isNull);
        expect(result.confirmUnavailableReasonCode, isNotNull);
        expect(
          await tokenRepository.listByOperationId(_input().operationId),
          isEmpty,
        );
      },
    );
  });
}

SaveTimingRecordOperationAnalyzeInput _input() {
  return SaveTimingRecordOperationAnalyzeInput(
    operationId: 'op-service-1',
    draftRecord: TimingRecord(
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
    affectedProjectIds: ['project-a'],
    mergeGroupIdsToDissolve: [],
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

RedactedSaveTimingRecordPreview _redactedPreview({
  String operationId = 'op-service-1',
  bool redacted = false,
  bool scopeAllowed = true,
  String summary = '编辑计时；设备：Hitachi；项目：李杰 · 五里山',
  List<OperationEntityRef> affectedEntities = const [
    OperationEntityRef(
      entityType: 'device',
      entityId: '7',
      label: 'Hitachi',
      deviceId: '7',
    ),
  ],
  List<OperationImpactItem> impactItems = const [],
  List<String> warnings = const ['预览基于当前本地数据'],
  List<String> scopeReasons = const [],
}) {
  return RedactedSaveTimingRecordPreview(
    preview: OperationPreview(
      operationId: operationId,
      operationType: OperationType.saveTimingRecord,
      title: '修改计时记录',
      summary: summary,
      warnings: warnings,
      affectedEntities: affectedEntities,
      impactItems: impactItems,
      requiresConfirmation: true,
      riskLevel: OperationRiskLevel.medium,
    ),
    analysis: RedactedSaveTimingRecordAnalysis(
      wouldCreateNewProject: redacted ? null : false,
      willDissolveMerge: false,
      willRevokeSettlement: redacted ? null : false,
      oldProjectId: redacted ? null : 'project-a',
      existingNewProjectId: redacted ? null : 'project-a',
      affectedProjectIds: redacted ? [] : ['project-a'],
      mergeGroupIdsToDissolve: [],
      warnings: warnings,
    ),
    freshness: null,
    redacted: redacted,
    redactionReasons: redacted ? ['已脱敏'] : [],
    visibleCapabilities: [],
    hiddenCapabilities: [],
    scopeAllowed: scopeAllowed,
    scopeReasons: scopeReasons,
  );
}

class _FakePreviewAdapter extends SaveTimingRecordOperationPreviewAdapter {
  _FakePreviewAdapter({required this.response, this.error})
    : super(
        analyzer: SaveTimingRecordOperationAnalyzer(
          command: const SaveTimingRecordOperationCommand(),
        ),
      );

  final SaveTimingRecordOperationRedactedPreviewResponse response;
  final Object? error;
  int calls = 0;
  SaveTimingRecordOperationPreviewRequest? lastRequest;
  ActorContext? lastActor;
  ActorScope? lastScope;
  DateTime? lastNow;

  @override
  Future<SaveTimingRecordOperationRedactedPreviewResponse> previewForActor({
    required SaveTimingRecordOperationPreviewRequest request,
    required ActorContext actor,
    required ActorScope scope,
    DateTime? now,
  }) async {
    calls += 1;
    lastRequest = request;
    lastActor = actor;
    lastScope = scope;
    lastNow = now;
    final thrown = error;
    if (thrown != null) throw thrown;
    return response;
  }
}

class _FakeTokenRepository implements OperationTokenRepository {
  final records = <OperationTokenRecord>[];

  @override
  Future<void> insert(OperationTokenRecord record) async {
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
    return [];
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

class _FreshAnalyzer extends SaveTimingRecordOperationAnalyzer {
  _FreshAnalyzer() : super(command: const SaveTimingRecordOperationCommand());

  @override
  Future<SaveTimingRecordFreshnessVerdict> validateFreshness({
    required SaveTimingRecordOperationAnalyzeInput input,
    required SaveTimingRecordOperationAnalyzeResult previousResult,
  }) async {
    return SaveTimingRecordFreshnessVerdict(
      isFresh: true,
      latest: previousResult,
      staleReasons: [],
    );
  }
}

SaveTimingRecordWithImpactResult _saveResult({String? userMessage}) {
  return SaveTimingRecordWithImpactResult(
    savedRecord: _input().draftRecord,
    projectChanged: false,
    mergeDissolved: false,
    settlementRevoked: false,
    affectedProjectIds: ['project-a'],
    revokedProjectIds: [],
    userMessage: userMessage,
  );
}

Future<Database> _openCurrentInMemoryDb() {
  AppDatabase.debugInitDbOverride = () {
    return openDatabase(
      inMemoryDatabasePath,
      version: AppDatabase.schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, _) => DbSchema.create(db),
    );
  };
  return AppDatabase.database;
}
