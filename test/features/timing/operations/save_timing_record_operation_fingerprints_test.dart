import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_analyzer.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_fingerprints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaveTimingRecordOperationFingerprints allocation cutoff', () {
    test(
      'input hash preserves null legacy payload and changes for non-null cutoff',
      () {
        final legacyDraft = TimingRecord(
          deviceId: 1,
          startDate: 20260601,
          projectId: 'project:alpha',
          contact: '甲方',
          site: 'alpha',
          type: TimingType.hours,
          startMeter: 0,
          endMeter: 8,
          hours: 8,
          income: 800,
        );
        final cutoffDraft = TimingRecord(
          deviceId: 1,
          startDate: 20260601,
          allocationCutoffDate: 20260610,
          projectId: 'project:alpha',
          contact: '甲方',
          site: 'alpha',
          type: TimingType.hours,
          startMeter: 0,
          endMeter: 8,
          hours: 8,
          income: 800,
        );

        final legacyInput = SaveTimingRecordOperationAnalyzeInput(
          operationId: 'op-save',
          draftRecord: legacyDraft,
        );
        final sameLegacyInput = SaveTimingRecordOperationAnalyzeInput(
          operationId: 'op-save',
          draftRecord: legacyDraft,
        );
        final cutoffInput = SaveTimingRecordOperationAnalyzeInput(
          operationId: 'op-save',
          draftRecord: cutoffDraft,
        );
        final clearedInput = SaveTimingRecordOperationAnalyzeInput(
          operationId: 'op-save',
          draftRecord: cutoffDraft.copyWith(allocationCutoffDate: null),
        );

        expect(
          legacyDraft.toMap().containsKey('allocation_cutoff_date'),
          isFalse,
        );
        expect(cutoffDraft.toMap()['allocation_cutoff_date'], 20260610);
        expect(
          SaveTimingRecordOperationFingerprints.inputHashFor(legacyInput),
          SaveTimingRecordOperationFingerprints.inputHashFor(sameLegacyInput),
        );
        expect(
          SaveTimingRecordOperationFingerprints.inputHashFor(cutoffInput),
          isNot(
            SaveTimingRecordOperationFingerprints.inputHashFor(legacyInput),
          ),
        );
        expect(
          SaveTimingRecordOperationFingerprints.inputHashFor(clearedInput),
          isNot(
            SaveTimingRecordOperationFingerprints.inputHashFor(cutoffInput),
          ),
        );
        expect(
          SaveTimingRecordOperationFingerprints.inputHashFor(clearedInput),
          SaveTimingRecordOperationFingerprints.inputHashFor(legacyInput),
        );
      },
    );
  });
}
