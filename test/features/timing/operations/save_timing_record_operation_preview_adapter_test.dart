import 'dart:convert';

import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_scope.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/core/operations/operation_models.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_analyzer.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_command.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_preview_adapter.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_preview_redactor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaveTimingRecordOperationPreviewAdapter', () {
    test(
      'preview delegates to analyzer and returns analysis preview',
      () async {
        final analysis = _analysis();
        final analyzer = _FakeAnalyzer(analysis: analysis);
        final adapter = SaveTimingRecordOperationPreviewAdapter(
          analyzer: analyzer,
        );
        final input = _input();

        final response = await adapter.preview(
          SaveTimingRecordOperationPreviewRequest(input: input),
        );

        expect(analyzer.analyzeCalls, 1);
        expect(analyzer.lastAnalyzeInput, same(input));
        expect(response.analysis, same(analysis));
        expect(response.preview, same(analysis.preview));
        expect(response.requiresReanalysisBeforeExecute, isTrue);
        expect(response.warnings, ['预览基于当前本地数据']);
        expect(response.freshness, isNull);
      },
    );

    test('preview has no command or audit dependency', () async {
      final analyzer = _FakeAnalyzer(analysis: _analysis());
      final adapter = SaveTimingRecordOperationPreviewAdapter(
        analyzer: analyzer,
      );

      final response = await adapter.preview(
        SaveTimingRecordOperationPreviewRequest(input: _input()),
      );

      expect(response.preview.operationType, OperationType.saveTimingRecord);
      expect(analyzer.analyzeCalls, 1);
      expect(analyzer.validateFreshnessCalls, 0);
    });

    test('preview propagates analyzer errors predictably', () async {
      final analyzer = _FakeAnalyzer(
        analysis: _analysis(),
        analyzeError: const SaveTimingRecordAnalyzeException('记录已不存在'),
      );
      final adapter = SaveTimingRecordOperationPreviewAdapter(
        analyzer: analyzer,
      );

      await expectLater(
        adapter.preview(
          SaveTimingRecordOperationPreviewRequest(input: _input()),
        ),
        throwsA(isA<SaveTimingRecordAnalyzeException>()),
      );
      expect(analyzer.analyzeCalls, 1);
      expect(analyzer.validateFreshnessCalls, 0);
    });

    test(
      'validateFreshness delegates to analyzer and returns verdict',
      () async {
        final previous = _analysis();
        final verdict = SaveTimingRecordFreshnessVerdict(
          isFresh: true,
          latest: previous,
          staleReasons: const [],
        );
        final analyzer = _FakeAnalyzer(analysis: previous, verdict: verdict);
        final adapter = SaveTimingRecordOperationPreviewAdapter(
          analyzer: analyzer,
        );
        final input = _input();

        final result = await adapter.validateFreshness(
          input: input,
          previousResult: previous,
        );

        expect(result, same(verdict));
        expect(analyzer.validateFreshnessCalls, 1);
        expect(analyzer.lastFreshnessInput, same(input));
        expect(analyzer.lastPreviousResult, same(previous));
        expect(analyzer.analyzeCalls, 0);
      },
    );

    test('stale freshness verdict is returned without side effects', () async {
      const staleReason = SaveTimingRecordStaleReason(
        type: SaveTimingRecordStaleReasonType.oldProjectChanged,
        message: '旧项目已变化',
        previousValue: 'project-a',
        latestValue: 'project-b',
      );
      final previous = _analysis();
      final latest = _analysis(
        operationId: 'op-save-1',
        oldProjectId: 'project-b',
      );
      final verdict = SaveTimingRecordFreshnessVerdict(
        isFresh: false,
        latest: latest,
        staleReasons: const [staleReason],
      );
      final analyzer = _FakeAnalyzer(analysis: previous, verdict: verdict);
      final adapter = SaveTimingRecordOperationPreviewAdapter(
        analyzer: analyzer,
      );

      final result = await adapter.validateFreshness(
        input: _input(),
        previousResult: previous,
      );

      expect(result.isFresh, isFalse);
      expect(result.staleReasons, [staleReason]);
      expect(result.latest, same(latest));
      expect(analyzer.validateFreshnessCalls, 1);
      expect(analyzer.analyzeCalls, 0);
    });

    test(
      'previewForActor returns full response and injected redaction',
      () async {
        final analysis = _analysis();
        final analyzer = _FakeAnalyzer(analysis: analysis);
        final redactor = _SpyRedactor();
        final adapter = SaveTimingRecordOperationPreviewAdapter(
          analyzer: analyzer,
          redactor: redactor,
        );
        final input = _input();
        final request = SaveTimingRecordOperationPreviewRequest(input: input);
        final actor = ActorContext(actorType: OperationActorType.owner);
        final scope = ActorScope.fullOwner(ownerId: 'owner-1');
        final now = DateTime.utc(2026, 1, 1);

        final result = await adapter.previewForActor(
          request: request,
          actor: actor,
          scope: scope,
          now: now,
        );

        expect(analyzer.analyzeCalls, 1);
        expect(redactor.calls, 1);
        expect(redactor.lastResponse, same(result.full));
        expect(redactor.lastActor, same(actor));
        expect(redactor.lastScope, same(scope));
        expect(redactor.lastNow, same(now));
        expect(result.full.analysis, same(analysis));
        expect(result.full.preview, same(analysis.preview));
        expect(result.redacted.redacted, isFalse);
        expect(result.redacted.scopeAllowed, isTrue);
        expect(result.redacted.preview, same(result.full.preview));
      },
    );

    test('owner full scope receives passthrough redacted projection', () async {
      final analysis = _analysis(willDissolveMerge: true);
      final adapter = SaveTimingRecordOperationPreviewAdapter(
        analyzer: _FakeAnalyzer(analysis: analysis),
      );

      final result = await adapter.previewForActor(
        request: SaveTimingRecordOperationPreviewRequest(input: _input()),
        actor: ActorContext(actorType: OperationActorType.owner),
        scope: ActorScope.fullOwner(ownerId: 'owner-1'),
      );

      expect(result.full.analysis, same(analysis));
      expect(result.redacted.redacted, isFalse);
      expect(result.redacted.scopeAllowed, isTrue);
      expect(
        result.redacted.preview.operationId,
        result.full.preview.operationId,
      );
      expect(result.redacted.preview.summary, contains('李杰 · 五里山'));
      expect(result.redacted.preview.riskLevel, OperationRiskLevel.high);
      expect(result.redacted.analysis.oldProjectId, 'project-a');
      expect(result.redacted.analysis.mergeGroupIdsToDissolve, [9001]);
    });

    test(
      'driver allowed device receives partial redacted projection',
      () async {
        final analysis = _analysis(
          projectChanged: true,
          willDissolveMerge: true,
          willRevokeSettlement: true,
        );
        final adapter = SaveTimingRecordOperationPreviewAdapter(
          analyzer: _FakeAnalyzer(analysis: analysis),
        );

        final result = await adapter.previewForActor(
          request: SaveTimingRecordOperationPreviewRequest(input: _input()),
          actor: ActorContext(
            actorType: OperationActorType.driver,
            actorId: 'driver-1',
          ),
          scope: ActorScope.devices(
            deviceIds: const ['7'],
            actorId: 'driver-1',
          ),
        );

        expect(result.redacted.redacted, isTrue);
        expect(result.redacted.scopeAllowed, isTrue);
        expect(result.redacted.preview.riskLevel, OperationRiskLevel.medium);
        expect(result.redacted.preview.summary, '编辑计时；设备：Hitachi');
        expect(result.redacted.preview.affectedEntities, hasLength(1));
        expect(
          result.redacted.preview.affectedEntities.single.entityId,
          'device:hidden',
        );
        expect(result.redacted.analysis.willDissolveMerge, isTrue);
        expect(result.redacted.analysis.willRevokeSettlement, isNull);
        expect(result.redacted.analysis.affectedProjectIds, isEmpty);
        expect(result.redacted.analysis.mergeGroupIdsToDissolve, isEmpty);
        _expectNoProjectLeak(result.redacted);
        expect(result.full.analysis, same(analysis));
        expect(result.full.analysis.affectedProjectIds, ['project-a']);
        expect(result.full.preview.summary, contains('李杰 · 五里山'));
      },
    );

    test('driver denied device receives minimal shell', () async {
      final adapter = SaveTimingRecordOperationPreviewAdapter(
        analyzer: _FakeAnalyzer(analysis: _analysis(willDissolveMerge: true)),
      );

      final result = await adapter.previewForActor(
        request: SaveTimingRecordOperationPreviewRequest(input: _input()),
        actor: ActorContext(
          actorType: OperationActorType.driver,
          actorId: 'driver-1',
        ),
        scope: ActorScope.devices(deviceIds: const ['99'], actorId: 'driver-1'),
      );

      expect(result.redacted.scopeAllowed, isFalse);
      expect(result.redacted.redacted, isTrue);
      expect(result.redacted.preview.summary, '预览内容已隐藏');
      expect(result.redacted.preview.affectedEntities, isEmpty);
      expect(result.redacted.preview.impactItems, isEmpty);
      expect(result.redacted.preview.warnings, isEmpty);
      expect(result.redacted.freshness, isNull);
      expect(result.redacted.analysis.willDissolveMerge, isFalse);
      expect(result.redacted.analysis.willRevokeSettlement, isNull);
      expect(result.redacted.analysis.affectedProjectIds, isEmpty);
      expect(result.redacted.preview.riskLevel, OperationRiskLevel.medium);
      _expectNoDeviceOrProjectLeak(result.redacted);
    });

    test('agent without delegated scope receives minimal shell', () async {
      final adapter = SaveTimingRecordOperationPreviewAdapter(
        analyzer: _FakeAnalyzer(
          analysis: _analysis(willRevokeSettlement: true),
        ),
      );

      final result = await adapter.previewForActor(
        request: SaveTimingRecordOperationPreviewRequest(input: _input()),
        actor: ActorContext(
          actorType: OperationActorType.agent,
          actorId: 'agent-1',
        ),
        scope: ActorScope.devices(deviceIds: const ['7'], actorId: 'agent-1'),
      );

      expect(result.redacted.scopeAllowed, isFalse);
      expect(result.redacted.scopeReasons, ['no delegated actor scope']);
      expect(result.redacted.preview.summary, '预览内容已隐藏');
      expect(result.redacted.preview.affectedEntities, isEmpty);
      expect(result.redacted.analysis.willRevokeSettlement, isNull);
      expect(result.redacted.preview.riskLevel, OperationRiskLevel.medium);
      _expectNoDeviceOrProjectLeak(result.redacted);
    });

    test('previewForActor does not mutate original full response', () async {
      final analysis = _analysis(
        projectChanged: true,
        willDissolveMerge: true,
        willRevokeSettlement: true,
      );
      final adapter = SaveTimingRecordOperationPreviewAdapter(
        analyzer: _FakeAnalyzer(analysis: analysis),
      );

      final result = await adapter.previewForActor(
        request: SaveTimingRecordOperationPreviewRequest(input: _input()),
        actor: ActorContext(
          actorType: OperationActorType.driver,
          actorId: 'driver-1',
        ),
        scope: ActorScope.devices(deviceIds: const ['7'], actorId: 'driver-1'),
      );

      expect(result.full.analysis, same(analysis));
      expect(result.full.preview, same(analysis.preview));
      expect(result.full.preview.summary, contains('李杰 · 五里山'));
      expect(result.full.preview.affectedEntities, contains(_projectRef));
      expect(result.full.analysis.mergeGroupIdsToDissolve, [9001]);
      expect(result.full.analysis.previewInput.willRevokeSettlement, isTrue);
      expect(result.redacted.analysis.mergeGroupIdsToDissolve, isEmpty);
    });
  });
}

SaveTimingRecordOperationAnalyzeInput _input({
  String operationId = 'op-save-1',
}) {
  return SaveTimingRecordOperationAnalyzeInput(
    operationId: operationId,
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

SaveTimingRecordOperationAnalyzeResult _analysis({
  String operationId = 'op-save-1',
  String oldProjectId = 'project-a',
  bool projectChanged = false,
  bool willDissolveMerge = false,
  bool willRevokeSettlement = false,
}) {
  final previewInput = SaveTimingRecordOperationPreviewInput(
    operationId: operationId,
    isEditing: true,
    timingRecordId: '1',
    deviceLabel: 'Hitachi',
    projectLabel: '李杰 · 五里山',
    oldProjectLabel: '李杰 · 五里山',
    newProjectLabel: projectChanged ? '李杰 · 新工地' : null,
    projectChanged: projectChanged,
    willDissolveMerge: willDissolveMerge,
    willRevokeSettlement: willRevokeSettlement,
    affectedEntities: const [_deviceRef, _projectRef],
    warnings: const ['预览基于当前本地数据'],
  );
  final preview = SaveTimingRecordOperationCommand().preview(previewInput);
  return SaveTimingRecordOperationAnalyzeResult(
    previewInput: previewInput,
    preview: preview,
    oldProjectId: oldProjectId,
    existingNewProjectId: 'project-a',
    wouldCreateNewProject: false,
    affectedProjectIds: const ['project-a'],
    mergeGroupIdsToDissolve: willDissolveMerge ? const [9001] : const [],
    requiresReanalysisBeforeExecute: true,
    warnings: const ['预览基于当前本地数据'],
  );
}

const _deviceRef = OperationEntityRef(
  entityType: 'device',
  entityId: '7',
  label: 'Hitachi',
  deviceId: '7',
);

const _projectRef = OperationEntityRef(
  entityType: 'project',
  entityId: 'project-a',
  label: '李杰 · 五里山',
  projectId: 'project-a',
);

String _serialize(RedactedSaveTimingRecordPreview redacted) {
  return jsonEncode(redacted.toMap());
}

void _expectNoProjectLeak(RedactedSaveTimingRecordPreview redacted) {
  final text = _serialize(redacted);
  for (final needle in const ['李杰', '五里山', 'project-a', 'project:']) {
    expect(
      text,
      isNot(contains(needle)),
      reason: 'redacted preview must not leak $needle; got $text',
    );
  }
}

void _expectNoDeviceOrProjectLeak(RedactedSaveTimingRecordPreview redacted) {
  final text = _serialize(redacted);
  for (final needle in const [
    'Hitachi',
    '7',
    '李杰',
    '五里山',
    'project-a',
    'project:',
  ]) {
    expect(
      text,
      isNot(contains(needle)),
      reason: 'minimal shell must not leak $needle; got $text',
    );
  }
}

class _FakeAnalyzer extends SaveTimingRecordOperationAnalyzer {
  _FakeAnalyzer({required this.analysis, this.verdict, this.analyzeError})
    : super(command: const SaveTimingRecordOperationCommand());

  final SaveTimingRecordOperationAnalyzeResult analysis;
  final SaveTimingRecordFreshnessVerdict? verdict;
  final Object? analyzeError;

  int analyzeCalls = 0;
  int validateFreshnessCalls = 0;
  SaveTimingRecordOperationAnalyzeInput? lastAnalyzeInput;
  SaveTimingRecordOperationAnalyzeInput? lastFreshnessInput;
  SaveTimingRecordOperationAnalyzeResult? lastPreviousResult;

  @override
  Future<SaveTimingRecordOperationAnalyzeResult> analyze(
    SaveTimingRecordOperationAnalyzeInput input,
  ) async {
    analyzeCalls += 1;
    lastAnalyzeInput = input;
    final error = analyzeError;
    if (error != null) throw error;
    return analysis;
  }

  @override
  Future<SaveTimingRecordFreshnessVerdict> validateFreshness({
    required SaveTimingRecordOperationAnalyzeInput input,
    required SaveTimingRecordOperationAnalyzeResult previousResult,
  }) async {
    validateFreshnessCalls += 1;
    lastFreshnessInput = input;
    lastPreviousResult = previousResult;
    return verdict ??
        SaveTimingRecordFreshnessVerdict(
          isFresh: true,
          latest: analysis,
          staleReasons: const [],
        );
  }
}

class _SpyRedactor extends SaveTimingRecordPreviewRedactor {
  _SpyRedactor();

  int calls = 0;
  SaveTimingRecordOperationPreviewResponse? lastResponse;
  ActorContext? lastActor;
  ActorScope? lastScope;
  DateTime? lastNow;

  @override
  RedactedSaveTimingRecordPreview redact({
    required SaveTimingRecordOperationPreviewResponse response,
    required ActorContext actor,
    required ActorScope scope,
    DateTime? now,
  }) {
    calls += 1;
    lastResponse = response;
    lastActor = actor;
    lastScope = scope;
    lastNow = now;
    return super.redact(
      response: response,
      actor: actor,
      scope: scope,
      now: now,
    );
  }
}
