import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/project_key.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/services/timing_monthly_income_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimingMonthlyIncomeService.computeMonthlyIncomeRealtime', () {
    test('dynamically amortizes across months by target month end', () {
      final monthlyAtFeb = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: [
          const TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260101,
            contact: '小朱',
            site: '永寿',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 6,
            hours: 6,
            income: 0, // 图表逻辑不再依赖该字段
          ),
          const TimingRecord(
            id: 2,
            deviceId: 1,
            startDate: 20260205,
            contact: '小朱',
            site: '永寿',
            type: TimingType.hours,
            startMeter: 6,
            endMeter: 9,
            hours: 3,
            income: 0,
            isBreaking: true,
          ),
        ],
        devices: const [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 200,
            breakingUnitPrice: 250,
            baseMeterHours: 0,
          ),
        ],
        rates: const [],
        targetYear: 2026,
        targetMonth: 2,
        asOfDate: DateTime(2026, 2, 28),
      );

      expect(monthlyAtFeb[0], closeTo(1062.8571, 0.001));
      expect(monthlyAtFeb[1], closeTo(887.1429, 0.001));
      expect(monthlyAtFeb.sublist(2).every((v) => v == 0.0), isTrue);

      final monthlyAtMar = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: [
          const TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260101,
            contact: '小朱',
            site: '永寿',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 6,
            hours: 6,
            income: 0,
          ),
          const TimingRecord(
            id: 2,
            deviceId: 1,
            startDate: 20260205,
            contact: '小朱',
            site: '永寿',
            type: TimingType.hours,
            startMeter: 6,
            endMeter: 9,
            hours: 3,
            income: 0,
            isBreaking: true,
          ),
        ],
        devices: const [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 200,
            breakingUnitPrice: 250,
            baseMeterHours: 0,
          ),
        ],
        rates: const [],
        targetYear: 2026,
        targetMonth: 3,
        asOfDate: DateTime(2026, 3, 31),
      );

      expect(monthlyAtMar[0], closeTo(1062.8571, 0.001));
      expect(monthlyAtMar[1], closeTo(464.4156, 0.001));
      expect(monthlyAtMar[2], closeTo(422.7273, 0.001));
    });

    test('keeps only the last record per device/day before segmenting', () {
      final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: [
          const TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260110,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 10,
            hours: 10,
            income: 9999,
          ),
          const TimingRecord(
            id: 2,
            deviceId: 1,
            startDate: 20260110,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 5,
            endMeter: 6,
            hours: 1,
            income: 9999,
          ),
          const TimingRecord(
            id: 4,
            deviceId: 1,
            startDate: 20260110,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 5,
            endMeter: 7,
            hours: 2,
            income: 9999,
          ),
          const TimingRecord(
            id: 3,
            deviceId: 1,
            startDate: 20260112,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 7,
            endMeter: 9,
            hours: 2,
            income: 9999,
          ),
        ],
        devices: const [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 200,
            baseMeterHours: 0,
          ),
        ],
        rates: const [],
        targetYear: 2026,
        targetMonth: 1,
        asOfDate: DateTime(2026, 1, 31),
      );

      // 仅应保留 2026-01-10 的最后一条（id:4，hours:2）+ 2026-01-12 记录（hours:2）
      expect(monthly[0], closeTo(800.0, 0.001));
      expect(monthly.sublist(1).every((v) => v == 0.0), isTrue);
    });

    test('uses project overrides and breaking fallback/default consistently', () {
      final projectKey = ProjectKey.buildKey(contact: '李洋', site: '万达');
      final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: const [
          TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260101,
            contact: '李洋',
            site: '万达',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 2,
            hours: 2,
            income: 0,
          ),
          TimingRecord(
            id: 2,
            deviceId: 1,
            startDate: 20260115,
            contact: '李洋',
            site: '万达',
            type: TimingType.hours,
            startMeter: 2,
            endMeter: 3,
            hours: 1,
            income: 0,
            isBreaking: true,
          ),
          TimingRecord(
            id: 3,
            deviceId: 2,
            startDate: 20260110,
            contact: '李洋',
            site: '万达',
            type: TimingType.hours,
            startMeter: 10,
            endMeter: 13,
            hours: 3,
            income: 0,
          ),
        ],
        devices: const [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 200,
            breakingUnitPrice: 250,
            baseMeterHours: 0,
          ),
          Device(
            id: 2,
            name: 'LIUGONG 1#',
            brand: 'LIUGONG',
            defaultUnitPrice: 150,
            breakingUnitPrice: 170,
            baseMeterHours: 0,
          ),
        ],
        rates: [
          ProjectDeviceRate(
            projectKey: projectKey,
            deviceId: 1,
            rate: 180,
          ),
          ProjectDeviceRate(
            projectKey: projectKey,
            deviceId: 1,
            isBreaking: true,
            rate: 230,
          ),
        ],
        targetYear: 2026,
        targetMonth: 1,
        asOfDate: DateTime(2026, 1, 31),
      );

      // dev1 normal: 2h * 180 = 360
      // dev1 breaking: 1h * 230 = 230
      // dev2 normal(default): 3h * 150 = 450
      expect(monthly[0], closeTo(1040.0, 0.001));
    });

    test('skips non-positive realtime income and records beyond target month end', () {
      final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: const [
          TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260101,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 1,
            hours: 1,
            income: 9999,
          ),
          TimingRecord(
            id: 2,
            deviceId: 3, // 设备单价为 0 -> realtimeIncome = 0
            startDate: 20260105,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 10,
            hours: 10,
            income: 9999,
          ),
          TimingRecord(
            id: 3,
            deviceId: 1,
            startDate: 20270101, // 超出目标年/目标月末，应跳过
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 1,
            endMeter: 2,
            hours: 1,
            income: 9999,
          ),
        ],
        devices: const [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
          Device(
            id: 3,
            name: 'ZERO 1#',
            brand: 'ZERO',
            defaultUnitPrice: 0,
            baseMeterHours: 0,
          ),
        ],
        rates: const [],
        targetYear: 2026,
        targetMonth: 1,
        asOfDate: DateTime(2026, 1, 31),
      );

      expect(monthly[0], closeTo(100.0, 0.001));
      expect(monthly.sublist(1).every((v) => v == 0.0), isTrue);
    });

    test('extends open segment only to cutoffDate for unfinished device timeline', () {
      final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: const [
          TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260315,
            contact: 'A',
            site: 'Y',
            type: TimingType.hours,
            startMeter: 100,
            endMeter: 117,
            hours: 17,
            income: 0,
          ),
        ],
        devices: const [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
        ],
        rates: const [],
        targetYear: 2026,
        targetMonth: 5,
        asOfDate: DateTime(2026, 5, 20),
      );

      expect(monthly[2], closeTo(431.3433, 0.001)); // 3月
      expect(monthly[3], closeTo(761.1940, 0.001)); // 4月
      expect(monthly[4], closeTo(507.4627, 0.001)); // 5月(仅到 5/20)
      expect(monthly[2] + monthly[3] + monthly[4], closeTo(1700.0, 0.001));
    });

    test('keeps april income when april records exist under realtime rules', () {
      final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: const [
          TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260101,
            contact: '小朱',
            site: '永寿',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 6,
            hours: 6,
            income: 0,
          ),
          TimingRecord(
            id: 2,
            deviceId: 1,
            startDate: 20260205,
            contact: '小朱',
            site: '永寿',
            type: TimingType.hours,
            startMeter: 6,
            endMeter: 9,
            hours: 3,
            income: 0,
            isBreaking: true,
          ),
          TimingRecord(
            id: 3,
            deviceId: 1,
            startDate: 20260301,
            contact: '小朱',
            site: '永寿',
            type: TimingType.hours,
            startMeter: 9,
            endMeter: 27,
            hours: 18,
            income: 0,
          ),
          TimingRecord(
            id: 4,
            deviceId: 1,
            startDate: 20260430,
            contact: '小朱',
            site: '永寿',
            type: TimingType.hours,
            startMeter: 27,
            endMeter: 84,
            hours: 57,
            income: 0,
          ),
        ],
        devices: const [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 200,
            breakingUnitPrice: 250,
            baseMeterHours: 0,
          ),
        ],
        rates: const [],
        targetYear: 2026,
        targetMonth: 4,
        asOfDate: DateTime(2026, 4, 30),
      );

      expect(monthly[0], closeTo(1062.8571, 0.001)); // 1月
      expect(monthly[1], closeTo(887.1429, 0.001)); // 2月
      expect(monthly[2], closeTo(1860.0, 0.001)); // 3月
      expect(monthly[3], closeTo(13140.0, 0.001)); // 4月
      expect(monthly[3], greaterThan(0.0));
    });

    test('keeps last by id for same day and same startMeter conflicts', () {
      final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: const [
          TimingRecord(
            id: 10,
            deviceId: 1,
            startDate: 20260110,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 5,
            endMeter: 15,
            hours: 10,
            income: 0,
          ),
          TimingRecord(
            id: 11,
            deviceId: 1,
            startDate: 20260110,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 5,
            endMeter: 6,
            hours: 1,
            income: 0,
          ),
        ],
        devices: const [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
        ],
        rates: const [],
        targetYear: 2026,
        targetMonth: 1,
        asOfDate: DateTime(2026, 1, 31),
      );

      // 仅保留 id=11（最后一条），收入=1 * 100
      expect(monthly[0], closeTo(100.0, 0.001));
      expect(monthly.sublist(1).every((v) => v == 0.0), isTrue);
    });

    test('handles multi-device mixed override/default rates with cross-month segments', () {
      final projectKey = ProjectKey.buildKey(contact: '李洋', site: '万达');
      final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: const [
          TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260110,
            contact: '李洋',
            site: '万达',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 10,
            hours: 10,
            income: 0,
          ),
          TimingRecord(
            id: 2,
            deviceId: 1,
            startDate: 20260210,
            contact: '李洋',
            site: '万达',
            type: TimingType.hours,
            startMeter: 10,
            endMeter: 14,
            hours: 4,
            income: 0,
          ),
          TimingRecord(
            id: 3,
            deviceId: 2,
            startDate: 20260120,
            contact: '李洋',
            site: '万达',
            type: TimingType.hours,
            startMeter: 100,
            endMeter: 105,
            hours: 5,
            income: 0,
          ),
        ],
        devices: const [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
          Device(
            id: 2,
            name: 'LIUGONG 1#',
            brand: 'LIUGONG',
            defaultUnitPrice: 200,
            baseMeterHours: 0,
          ),
        ],
        rates: [
          ProjectDeviceRate(
            projectKey: projectKey,
            deviceId: 1,
            rate: 150, // dev1 使用项目覆写
          ),
          // dev2 不覆写，使用设备默认价 200
        ],
        targetYear: 2026,
        targetMonth: 2,
        asOfDate: DateTime(2026, 2, 28),
      );

      // dev1@150:
      // r1 1500 in [01-10..02-09] => Jan 22d + Feb 9d
      // r2  600 in [02-10..02-28] => Feb 19d
      // dev2@200:
      // r3 1000 in [01-20..02-28] => Jan 12d + Feb 28d
      expect(monthly[0], closeTo(1364.5161, 0.001)); // 1月
      expect(monthly[1], closeTo(1735.4839, 0.001)); // 2月
      expect(monthly.sublist(2).every((v) => v == 0.0), isTrue);
    });
  });
}
