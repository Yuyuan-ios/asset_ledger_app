import 'package:asset_ledger/core/operations/operation_models.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_analyzer.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_command.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_preview_adapter.dart';
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
}) {
  final previewInput = SaveTimingRecordOperationPreviewInput(
    operationId: operationId,
    isEditing: true,
    timingRecordId: '1',
    deviceLabel: 'Hitachi',
    projectLabel: '李杰 · 五里山',
    oldProjectLabel: '李杰 · 五里山',
    affectedEntities: const [_projectRef],
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
    mergeGroupIdsToDissolve: const [],
    requiresReanalysisBeforeExecute: true,
    warnings: const ['预览基于当前本地数据'],
  );
}

const _projectRef = OperationEntityRef(
  entityType: 'project',
  entityId: 'project-a',
  label: '李杰 · 五里山',
  projectId: 'project-a',
);

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
