import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/models/project_id.dart';
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
      expect(updated.allocationCutoffDate, isNull);
      expect(updated.type, TimingType.rent);
      expect(updated.income, 900);
      expect(updated.excludeFromFuelEfficiency, isTrue);
    });

    test('copyWith preserves allocationCutoffDate when omitted', () {
      const record = TimingRecord(
        id: 1,
        deviceId: 2,
        startDate: 20260601,
        allocationCutoffDate: 20260610,
        contact: 'Alice',
        site: 'Yard A',
        type: TimingType.hours,
        startMeter: 100,
        endMeter: 105,
        hours: 5,
        income: 500,
      );

      final updated = record.copyWith(income: 600);

      expect(updated.allocationCutoffDate, 20260610);
      expect(updated.income, 600);
    });

    test('copyWith updates allocationCutoffDate when provided', () {
      const record = TimingRecord(
        id: 1,
        deviceId: 2,
        startDate: 20260601,
        contact: 'Alice',
        site: 'Yard A',
        type: TimingType.hours,
        startMeter: 100,
        endMeter: 105,
        hours: 5,
        income: 500,
      );

      final updated = record.copyWith(allocationCutoffDate: 20260610);

      expect(updated.allocationCutoffDate, 20260610);
    });

    test('copyWith clears allocationCutoffDate when requested', () {
      const record = TimingRecord(
        id: 1,
        deviceId: 2,
        startDate: 20260601,
        allocationCutoffDate: 20260610,
        contact: 'Alice',
        site: 'Yard A',
        type: TimingType.hours,
        startMeter: 100,
        endMeter: 105,
        hours: 5,
        income: 500,
      );

      final updated = record.copyWith(allocationCutoffDate: null);

      expect(updated.allocationCutoffDate, isNull);
      expect(updated.income, 500);
    });

    test('copyWith can set and clear displayEndDate independently', () {
      const record = TimingRecord(
        id: 1,
        deviceId: 2,
        startDate: 20260601,
        allocationCutoffDate: 20260610,
        contact: 'Alice',
        site: 'Yard A',
        type: TimingType.rent,
        startMeter: 100,
        endMeter: 105,
        hours: 5,
        income: 500,
      );

      final withDisplayEnd = record.copyWith(displayEndDate: 20260630);
      final cleared = withDisplayEnd.copyWith(displayEndDate: null);

      expect(withDisplayEnd.displayEndDate, 20260630);
      expect(withDisplayEnd.allocationCutoffDate, 20260610);
      expect(cleared.displayEndDate, isNull);
      expect(cleared.allocationCutoffDate, 20260610);
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

      expect(record.toMap().containsKey('allocation_cutoff_date'), isFalse);
      expect(record.toMap(), {
        'id': 2,
        'project_id': ProjectId.legacyFromParts(contact: 'Bob', site: 'Yard B'),
        'device_id': 3,
        'start_date': 20260302,
        'contact': 'Bob',
        'site': 'Yard B',
        'type': 'rent',
        'start_meter': 50.0,
        'end_meter': 50.0,
        'hours': 0.0,
        'income': 1200.0,
        // R5.26-B3：income 的 fen 镜像与 income 双写。
        'income_fen': 120000,
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
      expect(rebuilt.allocationCutoffDate, isNull);
      expect(rebuilt.displayEndDate, isNull);
      expect(rebuilt.contact, '');
      expect(rebuilt.site, '');
      expect(
        rebuilt.effectiveProjectId,
        ProjectId.legacyFromParts(contact: '', site: ''),
      );
      expect(rebuilt.type, TimingType.hours);
      expect(rebuilt.startMeter, 10);
      expect(rebuilt.endMeter, 15);
      expect(rebuilt.hours, 5);
      expect(rebuilt.income, 300);
      expect(rebuilt.excludeFromFuelEfficiency, isFalse);
      expect(rebuilt.toString(), contains('excludeFuel:false'));
    });

    test('toMap writes non-null display end and fromMap restores it', () {
      const record = TimingRecord(
        id: 9,
        deviceId: 3,
        startDate: 20260601,
        allocationCutoffDate: 20260610,
        displayEndDate: 20260630,
        contact: 'Bob',
        site: 'Yard B',
        type: TimingType.rent,
        startMeter: 10,
        endMeter: 15,
        hours: 5,
        income: 500,
      );

      final map = record.toMap();
      final rebuilt = TimingRecord.fromMap(map);

      expect(map['display_end_date'], 20260630);
      expect(rebuilt.displayEndDate, 20260630);
      expect(rebuilt.allocationCutoffDate, 20260610);
    });

    test('toMap writes non-null allocation cutoff and fromMap restores it', () {
      const record = TimingRecord(
        id: 9,
        deviceId: 3,
        startDate: 20260601,
        allocationCutoffDate: 20260610,
        contact: 'Bob',
        site: 'Yard B',
        type: TimingType.hours,
        startMeter: 10,
        endMeter: 15,
        hours: 5,
        income: 500,
      );

      final map = record.toMap();

      expect(map['allocation_cutoff_date'], 20260610);
      expect(TimingRecord.fromMap(map).allocationCutoffDate, 20260610);
    });

    test(
      'toMap can explicitly include null allocation cutoff for sync payload',
      () {
        const record = TimingRecord(
          id: 9,
          deviceId: 3,
          startDate: 20260601,
          contact: 'Bob',
          site: 'Yard B',
          type: TimingType.hours,
          startMeter: 10,
          endMeter: 15,
          hours: 5,
          income: 500,
        );

        expect(record.toMap().containsKey('allocation_cutoff_date'), isFalse);
        expect(
          record
              .toMap(includeNullAllocationCutoffDate: true)
              .containsKey('allocation_cutoff_date'),
          isTrue,
        );
        expect(
          record.toMap(
            includeNullAllocationCutoffDate: true,
          )['allocation_cutoff_date'],
          isNull,
        );
      },
    );

    test('toMap can explicitly include null display end for sync payload', () {
      const record = TimingRecord(
        id: 9,
        deviceId: 3,
        startDate: 20260601,
        contact: 'Bob',
        site: 'Yard B',
        type: TimingType.rent,
        startMeter: 10,
        endMeter: 15,
        hours: 5,
        income: 500,
      );

      expect(record.toMap().containsKey('display_end_date'), isFalse);
      expect(
        record.toMap(includeNullDisplayEndDate: true)['display_end_date'],
        isNull,
      );
      expect(
        record
            .toMap(includeNullAllocationCutoffDate: true)
            .containsKey('display_end_date'),
        isFalse,
      );
    });

    test('fromMap falls back to hours for unknown timing type', () {
      final rebuilt = TimingRecord.fromMap({
        'id': 4,
        'device_id': 7,
        'start_date': 20260305,
        'contact': 'Alice',
        'site': 'Yard A',
        'type': 'monthly',
        'start_meter': 10,
        'end_meter': 15,
        'hours': 5,
        'income': 300,
      });

      expect(rebuilt.type, TimingType.hours);
    });
  });
}
