import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/services/timing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimingService edge cases', () {
    test('currentMeter ignores records from other devices', () {
      final result = TimingService.currentMeter(
        [
          const TimingRecord(
            id: 1,
            deviceId: 2,
            startDate: 20260301,
            contact: 'A',
            site: 'Yard',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 999,
            hours: 1,
            income: 0,
          ),
        ],
        1,
        baseMeterHours: 50,
      );

      expect(result, 50);
    });

    test('lowerBound ignores records on the same day because only earlier dates count', () {
      final result = TimingService.lowerBound(
        records: [
          const TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260301,
            contact: 'A',
            site: 'Yard',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 80,
            hours: 1,
            income: 0,
          ),
          const TimingRecord(
            id: 2,
            deviceId: 1,
            startDate: 20260302,
            contact: 'A',
            site: 'Yard',
            type: TimingType.hours,
            startMeter: 80,
            endMeter: 120,
            hours: 1,
            income: 0,
          ),
        ],
        deviceId: 1,
        startDate: 20260302,
      );

      expect(result, 80);
    });

    test('upperBound ignores records on the same day because only later dates count', () {
      final result = TimingService.upperBound(
        records: [
          const TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260302,
            contact: 'A',
            site: 'Yard',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 200,
            hours: 1,
            income: 0,
          ),
          const TimingRecord(
            id: 2,
            deviceId: 1,
            startDate: 20260303,
            contact: 'A',
            site: 'Yard',
            type: TimingType.hours,
            startMeter: 200,
            endMeter: 150,
            hours: 1,
            income: 0,
          ),
        ],
        deviceId: 1,
        startDate: 20260302,
      );

      expect(result, 150);
    });
  });
}
