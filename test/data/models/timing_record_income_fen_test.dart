import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/core/money/amount_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// R5.26-B3：TimingRecord.income_fen 双写地基的 model 行为。
///
/// 口径：income (REAL) 仍是业务主口径（读路径本轮不切换）；incomeFen 是其整数分
/// 镜像 round(income * 100)，hours / rent 一视同仁。toMap 双写 income + income_fen，
/// fromMap 缺 income_fen 的 legacy map 也能由 income 派生。
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
      expect(
        buildRecord(type: TimingType.hours, income: 200).incomeFen,
        20000,
      );
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

    test('toMap double-writes income and income_fen', () {
      final map = buildRecord(type: TimingType.hours, income: 200).toMap();
      expect(map['income'], 200.0);
      expect(map['income_fen'], 20000);
    });

    test('toMap keeps income_fen alongside explicit null allocation cutoff', () {
      final map = buildRecord(
        type: TimingType.rent,
        income: 1200,
      ).toMap(includeNullAllocationCutoffDate: true);
      expect(map['allocation_cutoff_date'], isNull);
      expect(map['income_fen'], 120000);
    });

    test('fromMap derives incomeFen for legacy map missing income_fen', () {
      final record = TimingRecord.fromMap({
        'id': 4,
        'device_id': 7,
        'start_date': 20260305,
        'contact': '甲方',
        'site': '工地',
        'type': 'hours',
        'start_meter': 10,
        'end_meter': 15,
        'hours': 5,
        'income': 300,
        // 无 income_fen（legacy 行）
      });
      expect(record.income, 300.0);
      expect(record.incomeFen, 30000);
    });

    test('fromMap keeps income (REAL) as the canonical business value', () {
      // 读路径本轮不切换：income 仍取自 income 列；incomeFen 由 income 派生。
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
        'income': 88.8,
        'income_fen': 8880,
      });
      expect(record.income, 88.8);
      expect(record.incomeFen, 8880);
      // round-trip 保持一致。
      expect(record.toMap()['income_fen'], 8880);
    });
  });
}
