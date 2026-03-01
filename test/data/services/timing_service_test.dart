import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/services/timing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimingService.currentMeter', () {
    test('returns base meter when there are no records for the device', () {
      final meter = TimingService.currentMeter(
        const [],
        1,
        baseMeterHours: 120,
      );

      expect(meter, 120);
    });

    test('returns the larger value between max endMeter and base meter', () {
      final meter = TimingService.currentMeter(
        [
          const TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260101,
            contact: 'A',
            site: '工地',
            type: TimingType.hours,
            startMeter: 100,
            endMeter: 130,
            hours: 30,
            income: 3000,
          ),
          const TimingRecord(
            id: 2,
            deviceId: 1,
            startDate: 20260102,
            contact: 'A',
            site: '工地',
            type: TimingType.hours,
            startMeter: 130,
            endMeter: 150,
            hours: 20,
            income: 2000,
          ),
        ],
        1,
        baseMeterHours: 140,
      );

      expect(meter, 150);
    });
  });

  group('TimingService.lowerBound', () {
    test('returns the max earlier endMeter and excludes the editing record', () {
      final result = TimingService.lowerBound(
        records: [
          const TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260101,
            contact: 'A',
            site: '工地',
            type: TimingType.hours,
            startMeter: 100,
            endMeter: 120,
            hours: 20,
            income: 2000,
          ),
          const TimingRecord(
            id: 2,
            deviceId: 1,
            startDate: 20260103,
            contact: 'A',
            site: '工地',
            type: TimingType.hours,
            startMeter: 120,
            endMeter: 140,
            hours: 20,
            income: 2000,
          ),
          const TimingRecord(
            id: 3,
            deviceId: 1,
            startDate: 20260105,
            contact: 'A',
            site: '工地',
            type: TimingType.hours,
            startMeter: 140,
            endMeter: 160,
            hours: 20,
            income: 2000,
          ),
        ],
        deviceId: 1,
        startDate: 20260105,
        excludeId: 3,
      );

      expect(result, 140);
    });
  });

  group('TimingService.upperBound', () {
    test('returns the min later endMeter and infinity when there is no later record', () {
      final records = [
        const TimingRecord(
          id: 1,
          deviceId: 1,
          startDate: 20260101,
          contact: 'A',
          site: '工地',
          type: TimingType.hours,
          startMeter: 100,
          endMeter: 120,
          hours: 20,
          income: 2000,
        ),
        const TimingRecord(
          id: 2,
          deviceId: 1,
          startDate: 20260103,
          contact: 'A',
          site: '工地',
          type: TimingType.hours,
          startMeter: 120,
          endMeter: 135,
          hours: 15,
          income: 1500,
        ),
        const TimingRecord(
          id: 3,
          deviceId: 1,
          startDate: 20260108,
          contact: 'A',
          site: '工地',
          type: TimingType.hours,
          startMeter: 135,
          endMeter: 150,
          hours: 15,
          income: 1500,
        ),
      ];

      final bounded = TimingService.upperBound(
        records: records,
        deviceId: 1,
        startDate: 20260101,
        excludeId: 1,
      );
      final unbounded = TimingService.upperBound(
        records: records,
        deviceId: 1,
        startDate: 20260108,
        excludeId: 3,
      );

      expect(bounded, 135);
      expect(unbounded, double.infinity);
    });
  });
}
