import 'package:asset_ledger/core/measure/measure_unit.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimingRecord', () {
    test('copyWith overrides fields including enum and exclude flag', () {
      final record = TimingRecord(
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
      final record = TimingRecord(
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
      final record = TimingRecord(
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
      final record = TimingRecord(
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
      final record = TimingRecord(
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
      final record = TimingRecord(
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
        'income_fen': 120000,
        // S2/v33：统一计量镜像与 type/hours 双写；rent 行 quantity 为 null。
        'unit': 'RENT',
        'quantity_scaled': null,
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
        'income_fen': 30000,
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
      // S2/v33：legacy 行缺 unit/quantity_scaled 时按 type/hours 派生镜像。
      expect(rebuilt.unit, MeasureUnit.hour);
      expect(rebuilt.quantityScaled, 5000);
    });

    test('unit and quantity_scaled mirror storage values and derive for '
        'legacy rows', () {
      // 存储值优先：DB 已落 unit/quantity_scaled 时读原值。
      final stored = TimingRecord.fromMap({
        'id': 1,
        'device_id': 1,
        'start_date': 20260601,
        'contact': 'A',
        'site': 'B',
        'type': 'hours',
        'start_meter': 0,
        'end_meter': 7.5,
        'hours': 7.5,
        'income_fen': 0,
        'unit': 'HOUR',
        'quantity_scaled': 7500,
      });
      expect(stored.unit, MeasureUnit.hour);
      expect(stored.quantityScaled, 7500);

      // 未知 unit 值防御回退（不抛异常，按 type 派生）。
      final unknownUnit = TimingRecord.fromMap({
        'id': 2,
        'device_id': 1,
        'start_date': 20260601,
        'contact': 'A',
        'site': 'B',
        'type': 'rent',
        'start_meter': 0,
        'end_meter': 0,
        'hours': 0,
        'income_fen': 80000,
        'unit': 'GALLON',
      });
      expect(unknownUnit.unit, MeasureUnit.rent);
      expect(unknownUnit.quantityScaled, isNull);

      // 双写：toMap 总是带 unit/quantity_scaled。
      final hoursRecord = TimingRecord(
        deviceId: 1,
        startDate: 20260601,
        contact: 'A',
        site: 'B',
        type: TimingType.hours,
        startMeter: 0,
        endMeter: 7.5,
        hours: 7.5,
        income: 0,
      );
      final map = hoursRecord.toMap();
      expect(map['unit'], 'HOUR');
      expect(map['quantity_scaled'], 7500);
    });

    test('toMap writes non-null display end and fromMap restores it', () {
      final record = TimingRecord(
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
      final record = TimingRecord(
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
        final record = TimingRecord(
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
      final record = TimingRecord(
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
        'income_fen': 30000,
      });

      expect(rebuilt.type, TimingType.hours);
    });

    test('fromMap accepts valid yyyymmdd start_date', () {
      final rebuilt = TimingRecord.fromMap({
        'id': 4,
        'device_id': 7,
        'start_date': 20260305,
        'contact': 'Alice',
        'site': 'Yard A',
        'type': 'hours',
        'start_meter': 10,
        'end_meter': 15,
        'hours': 5,
        'income_fen': 30000,
      });

      expect(rebuilt.startDate, 20260305);
    });

    test('fromMap rejects invalid start_date values', () {
      Map<String, Object?> rowWith(Object? startDate) => {
        'id': 4,
        'device_id': 7,
        'start_date': startDate,
        'contact': 'Alice',
        'site': 'Yard A',
        'type': 'hours',
        'start_meter': 10,
        'end_meter': 15,
        'hours': 5,
        'income_fen': 30000,
      };

      for (final startDate in <Object?>[null, -1, 0, 20261332, 20260230]) {
        expect(
          () => TimingRecord.fromMap(rowWith(startDate)),
          throwsA(isA<FormatException>()),
          reason: 'start_date=$startDate',
        );
      }
    });
  });
}
