import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_scope.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/core/operations/operation_models.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_analyzer.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_command.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_preview_adapter.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_preview_redactor.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_preview_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
        warnings: const ['安全提示'],
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
        affectedEntities: const [],
        impactItems: const [],
        warnings: const [],
        scopeReasons: const ['device not in actor scope'],
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
        scope: ActorScope.devices(deviceIds: const ['99'], actorId: 'driver-1'),
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
        affectedEntities: const [
          OperationEntityRef(
            entityType: 'device',
            entityId: 'device:hidden',
            label: 'Hitachi',
          ),
        ],
        warnings: const ['预览基于当前本地数据，执行前必须重新分析确认。'],
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
        scope: ActorScope.devices(deviceIds: const ['7'], actorId: 'driver-1'),
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
          scope: ActorScope.devices(
            deviceIds: const ['7'],
            actorId: 'driver-1',
          ),
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
  });
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
      affectedProjectIds: redacted ? const [] : const ['project-a'],
      mergeGroupIdsToDissolve: const [],
      warnings: warnings,
    ),
    freshness: null,
    redacted: redacted,
    redactionReasons: redacted ? const ['已脱敏'] : const [],
    visibleCapabilities: const [],
    hiddenCapabilities: const [],
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
