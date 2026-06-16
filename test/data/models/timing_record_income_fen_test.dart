import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/core/money/amount_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Track A / A4-7：TimingRecord.income_fen fen-only model 行为。
///
/// 口径：incomeFen 是唯一存储权威，income 是 incomeFen / 100 派生 getter。
/// 构造函数仍接收 income double 便利参数并立即 round 到整数分。
void main() {
  group('TimingRecord income_fen', () {
    TimingRecord buildRecord({
      required TimingType type,
      required double income,
      double hours = 5,
    }) {
      return TimingRecord(
        id: 1,
        deviceId: 2,
        startDate: 20260601,
        contact: '甲方',
        site: '工地',
        type: type,
        startMeter: 100,
        endMeter: 105,
        hours: hours,
        income: income,
      );
    }

    test('incomeFen mirrors round(income * 100) for hours and rent', () {
      expect(buildRecord(type: TimingType.hours, income: 200).incomeFen, 20000);
      expect(
        buildRecord(type: TimingType.rent, income: 1200).incomeFen,
        120000,
      );
      // 与项目统一的 Money.fromYuan round 口径一致。
      expect(
        buildRecord(type: TimingType.rent, income: 19.99).incomeFen,
        Money.fromYuan(19.99).fen,
      );
      expect(
        buildRecord(type: TimingType.hours, income: 0.1).incomeFen,
        Money.fromYuan(0.1).fen,
      );
    });

    test('toMap writes only income_fen for stored income', () {
      final map = buildRecord(type: TimingType.hours, income: 200).toMap();
      expect(map.containsKey('income'), isFalse);
      expect(map['income_fen'], 20000);
    });

    test(
      'toMap keeps income_fen alongside explicit null allocation cutoff',
      () {
        final map = buildRecord(
          type: TimingType.rent,
          income: 1200,
        ).toMap(includeNullAllocationCutoffDate: true);
        expect(map['allocation_cutoff_date'], isNull);
        expect(map['income_fen'], 120000);
      },
    );

    test('fromMap requires income_fen', () {
      expect(
        () => TimingRecord.fromMap({
          'id': 4,
          'device_id': 7,
          'start_date': 20260305,
          'contact': '甲方',
          'site': '工地',
          'type': 'hours',
          'start_meter': 10,
          'end_meter': 15,
          'hours': 5,
        }),
        throwsA(isA<StateError>()),
      );
    });

    test('fromMap uses income_fen as the canonical business value', () {
      final record = TimingRecord.fromMap({
        'id': 5,
        'device_id': 7,
        'start_date': 20260305,
        'contact': '甲方',
        'site': '工地',
        'type': 'rent',
        'start_meter': 0,
        'end_meter': 0,
        'hours': 0,
        'income_fen': 8881,
      });
      expect(record.income, 88.81);
      expect(record.incomeFen, 8881);
      // round-trip 保持一致。
      expect(record.toMap()['income_fen'], 8881);
    });
  });
}
