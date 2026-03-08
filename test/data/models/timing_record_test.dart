import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimingRecord', () {
    test('copyWith overrides fields including enum and exclude flag', () {
      const record = TimingRecord(
        id: 1,
        deviceId: 2,
        startDate: 20260301,
        contact: 'Alice',
        site: 'Yard A',
        type: TimingType.hours,
        startMeter: 100,
        endMeter: 105,
        hours: 5,
        income: 500,
      );

      final updated = record.copyWith(
        type: TimingType.rent,
        income: 900,
        excludeFromFuelEfficiency: true,
      );

      expect(updated.id, 1);
      expect(updated.deviceId, 2);
      expect(updated.startDate, 20260301);
      expect(updated.type, TimingType.rent);
      expect(updated.income, 900);
      expect(updated.excludeFromFuelEfficiency, isTrue);
    });

    test('toMap and fromMap encode enum names and bool flags for storage', () {
      const record = TimingRecord(
        id: 2,
        deviceId: 3,
        startDate: 20260302,
        contact: 'Bob',
        site: 'Yard B',
        type: TimingType.rent,
        startMeter: 50,
        endMeter: 50,
        hours: 0,
        income: 1200,
        excludeFromFuelEfficiency: true,
      );

      expect(record.toMap(), {
        'id': 2,
        'device_id': 3,
        'start_date': 20260302,
        'contact': 'Bob',
        'site': 'Yard B',
        'type': 'rent',
        'start_meter': 50.0,
        'end_meter': 50.0,
        'hours': 0.0,
        'income': 1200.0,
        'exclude_from_fuel_eff': 1,
        'is_breaking': 0,
      });

      final rebuilt = TimingRecord.fromMap({
        'id': 4,
        'device_id': 7,
        'start_date': 20260305,
        'contact': null,
        'site': null,
        'type': 'hours',
        'start_meter': 10,
        'end_meter': 15,
        'hours': 5,
        'income': 300,
      });

      expect(rebuilt.id, 4);
      expect(rebuilt.deviceId, 7);
      expect(rebuilt.contact, '');
      expect(rebuilt.site, '');
      expect(rebuilt.type, TimingType.hours);
      expect(rebuilt.startMeter, 10);
      expect(rebuilt.endMeter, 15);
      expect(rebuilt.hours, 5);
      expect(rebuilt.income, 300);
      expect(rebuilt.excludeFromFuelEfficiency, isFalse);
      expect(rebuilt.toString(), contains('excludeFuel:false'));
    });
  });
}
