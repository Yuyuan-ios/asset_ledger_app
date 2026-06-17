import 'package:asset_ledger/core/measure/measure_unit.dart';
import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/fuel/state/fuel_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FuelStore.buildEfficiencyByDevice', () {
    test(
      'keeps efficiency denominator separate from displayed total timing',
      () {
        final result = FuelStore.buildEfficiencyByDevice(
          fuelLogs: [
            FuelLog(
              deviceId: 1,
              date: 20260601,
              supplier: 'A',
              liters: 40,
              cost: 400,
            ),
          ],
          timingRecords: [
            _timing(deviceId: 1, type: TimingType.hours, hours: 10),
            _timing(deviceId: 1, type: TimingType.rent, hours: 2),
            _timing(
              deviceId: 1,
              type: TimingType.rent,
              unit: MeasureUnit.shift,
              hours: 1.5,
            ),
          ],
        );

        final agg = result[1]!;

        expect(agg.totalTimingHours, 13.5);
        expect(agg.totalHours, 10);
        expect(agg.litersPerHour, 4);
        expect(agg.costPerHour, 40);
      },
    );
  });
}

TimingRecord _timing({
  required int deviceId,
  required TimingType type,
  required double hours,
  MeasureUnit? unit,
}) {
  return TimingRecord(
    deviceId: deviceId,
    startDate: 20260601,
    contact: 'A',
    site: 'Yard',
    type: type,
    startMeter: 0,
    endMeter: hours,
    hours: hours,
    income: 100,
    unit: unit,
  );
}
