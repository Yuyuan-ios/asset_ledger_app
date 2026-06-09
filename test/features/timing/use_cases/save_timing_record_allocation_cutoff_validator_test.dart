import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/timing/use_cases/save_timing_record_allocation_cutoff_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('displayEndDate is ignored by allocation cutoff validator', () {
    expect(
      () => SaveTimingRecordAllocationCutoffValidator.validate(
        record: _record(displayEndDate: 20260501),
        sameDeviceRecords: [_record(id: 2, startDate: 20260601)],
      ),
      returnsNormally,
    );
  });

  test(
    'allocationCutoffDate still validates independently of displayEndDate',
    () {
      expect(
        () => SaveTimingRecordAllocationCutoffValidator.validate(
          record: _record(
            allocationCutoffDate: 20260620,
            displayEndDate: 20260501,
          ),
          sameDeviceRecords: [_record(id: 2, startDate: 20260610)],
        ),
        throwsA(
          isA<SaveTimingRecordAllocationCutoffValidationException>().having(
            (error) => error.code,
            'code',
            SaveTimingRecordAllocationCutoffValidationException
                .cutoffAfterNextSameDeviceStartDate,
          ),
        ),
      );
    },
  );
}

TimingRecord _record({
  int id = 1,
  int startDate = 20260601,
  int? allocationCutoffDate,
  int? displayEndDate,
}) {
  return TimingRecord(
    id: id,
    deviceId: 1,
    startDate: startDate,
    allocationCutoffDate: allocationCutoffDate,
    displayEndDate: displayEndDate,
    contact: '甲方',
    site: 'alpha',
    type: TimingType.hours,
    startMeter: 0,
    endMeter: 2,
    hours: 2,
    income: 200,
  );
}
