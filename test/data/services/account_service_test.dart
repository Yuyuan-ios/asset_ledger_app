import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/services/account_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountService.buildProjects', () {
    test('groups by trimmed project key and separates rent income from hours', () {
      final projects = AccountService.buildProjects(
        timingRecords: const [
          TimingRecord(
            id: 1,
            deviceId: 2,
            startDate: 20260303,
            contact: ' Alice ',
            site: ' Yard A ',
            type: TimingType.hours,
            startMeter: 10,
            endMeter: 14,
            hours: 4,
            income: 0,
          ),
          TimingRecord(
            id: 2,
            deviceId: 2,
            startDate: 20260301,
            contact: 'Alice',
            site: 'Yard A',
            type: TimingType.rent,
            startMeter: 14,
            endMeter: 14,
            hours: 0,
            income: 800,
          ),
          TimingRecord(
            id: 3,
            deviceId: 3,
            startDate: 20260302,
            contact: '',
            site: 'Ignored',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 1,
            hours: 1,
            income: 100,
          ),
        ],
      );

      final project = projects['Alice||Yard A']!;

      expect(projects.keys, ['Alice||Yard A']);
      expect(project.minYmd, 20260301);
      expect(project.deviceIds, [2]);
      expect(project.hoursByDevice[2], 4);
      expect(project.rentIncomeTotal, 800);
    });

    test(
      'aggregates multi-device multi-mode hours with interleaved dates and correct minYmd',
      () {
        final projects = AccountService.buildProjects(
          timingRecords: const [
            TimingRecord(
              id: 11,
              deviceId: 2,
              startDate: 20260305,
              contact: 'Mix',
              site: 'Site',
              type: TimingType.hours,
              startMeter: 10,
              endMeter: 14,
              hours: 4,
              income: 0,
            ),
            TimingRecord(
              id: 12,
              deviceId: 1,
              startDate: 20260301,
              contact: 'Mix',
              site: 'Site',
              type: TimingType.hours,
              isBreaking: true,
              startMeter: 20,
              endMeter: 21.5,
              hours: 1.5,
              income: 0,
            ),
            TimingRecord(
              id: 13,
              deviceId: 1,
              startDate: 20260303,
              contact: 'Mix',
              site: 'Site',
              type: TimingType.hours,
              startMeter: 21.5,
              endMeter: 23.5,
              hours: 2,
              income: 0,
            ),
            TimingRecord(
              id: 14,
              deviceId: 2,
              startDate: 20260302,
              contact: 'Mix',
              site: 'Site',
              type: TimingType.hours,
              isBreaking: true,
              startMeter: 14,
              endMeter: 17,
              hours: 3,
              income: 0,
            ),
            TimingRecord(
              id: 15,
              deviceId: 2,
              startDate: 20260228,
              contact: 'Mix',
              site: 'Site',
              type: TimingType.rent,
              startMeter: 17,
              endMeter: 17,
              hours: 0,
              income: 900,
            ),
          ],
        );

        final project = projects['Mix||Site']!;

        expect(project.deviceIds, [1, 2]);
        expect(project.minYmd, 20260228);
        expect(project.hoursByDevice, {1: 3.5, 2: 7.0});
        expect(project.normalHoursByDevice, {1: 2.0, 2: 4.0});
        expect(project.breakingHoursByDevice, {1: 1.5, 2: 3.0});
        expect(project.rentIncomeTotal, 900);
      },
    );
  });

  group('AccountService money helpers', () {
    test('uses project overrides and can exclude a payment from received total', () {
      const agg = ProjectAgg(
        projectKey: 'Alice||Yard A',
        contact: 'Alice',
        site: 'Yard A',
        minYmd: 20260301,
        deviceIds: [1, 2],
        hoursByDevice: {1: 2, 2: 3},
        normalHoursByDevice: {1: 2, 2: 3},
        breakingHoursByDevice: {},
        rentIncomeTotal: 500,
      );

      final money = AccountService.calcMoney(
        agg: agg,
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
            name: 'CAT 1#',
            brand: 'CAT',
            defaultUnitPrice: 200,
            baseMeterHours: 0,
          ),
        ],
        rates: const [
          ProjectDeviceRate(
            projectKey: 'Alice||Yard A',
            deviceId: 2,
            rate: 250,
          ),
        ],
        payments: const [
          AccountPayment(
            id: 1,
            projectKey: 'Alice||Yard A',
            ymd: 20260310,
            amount: 300,
          ),
          AccountPayment(
            id: 2,
            projectKey: 'Alice||Yard A',
            ymd: 20260311,
            amount: 100,
          ),
        ],
      );

      final receivedExcluding = AccountService.sumReceivedByProject(
        projectKey: 'Alice||Yard A',
        payments: const [
          AccountPayment(
            id: 1,
            projectKey: 'Alice||Yard A',
            ymd: 20260310,
            amount: 300,
          ),
          AccountPayment(
            id: 2,
            projectKey: 'Alice||Yard A',
            ymd: 20260311,
            amount: 100,
          ),
        ],
        excludePaymentId: 2,
      );

      final rateInfo = AccountService.calcRateInfo(
        agg: agg,
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
            name: 'CAT 1#',
            brand: 'CAT',
            defaultUnitPrice: 200,
            baseMeterHours: 0,
          ),
        ],
        rates: const [
          ProjectDeviceRate(
            projectKey: 'Alice||Yard A',
            deviceId: 2,
            rate: 250,
          ),
        ],
      );

      expect(money.receivable, 1450);
      expect(money.received, 400);
      expect(money.remaining, 1050);
      expect(money.ratio, closeTo(400 / 1450, 0.000001));
      expect(receivedExcluding, 300);
      expect(rateInfo.minRate, 100);
      expect(rateInfo.isMultiDevice, isTrue);
    });

    test(
      'calcMoney computes receivable/remaining/ratio with normal+breaking+rent mix',
      () {
        const agg = ProjectAgg(
          projectKey: 'Alpha||Site X',
          contact: 'Alpha',
          site: 'Site X',
          minYmd: 20260301,
          deviceIds: [1, 2],
          hoursByDevice: {1: 13, 2: 2},
          normalHoursByDevice: {1: 10},
          breakingHoursByDevice: {1: 3, 2: 2},
          rentIncomeTotal: 500,
        );

        final money = AccountService.calcMoney(
          agg: agg,
          devices: const [
            Device(
              id: 1,
              name: 'SANY 1#',
              brand: 'SANY',
              defaultUnitPrice: 100,
              breakingUnitPrice: 180,
              baseMeterHours: 0,
            ),
            Device(
              id: 2,
              name: 'CAT 1#',
              brand: 'CAT',
              defaultUnitPrice: 80,
              baseMeterHours: 0,
            ),
          ],
          rates: const [
            ProjectDeviceRate(
              projectKey: 'Alpha||Site X',
              deviceId: 1,
              rate: 120,
              isBreaking: false,
            ),
            ProjectDeviceRate(
              projectKey: 'Alpha||Site X',
              deviceId: 1,
              rate: 260,
              isBreaking: true,
            ),
          ],
          payments: const [
            AccountPayment(
              id: 1,
              projectKey: 'Alpha||Site X',
              ymd: 20260310,
              amount: 300,
            ),
            AccountPayment(
              id: 2,
              projectKey: 'Alpha||Site X',
              ymd: 20260311,
              amount: 500,
            ),
          ],
        );

        // receivable = (10*120) + (3*260) + (2*80) + 500 = 2640
        expect(money.receivable, 2640);
        expect(money.received, 800);
        expect(money.remaining, 1840);
        expect(money.ratio, closeTo(800 / 2640, 0.000001));
      },
    );

    test(
      'buildEffectiveRateMap in breaking mode uses override first, then breaking fallback/default',
      () {
        final result = AccountService.buildEffectiveRateMap(
          projectKey: 'Alpha||Site X',
          devices: const [
            Device(
              id: 1,
              name: 'SANY 1#',
              brand: 'SANY',
              defaultUnitPrice: 100,
              breakingUnitPrice: 160,
              baseMeterHours: 0,
            ),
            Device(
              id: 2,
              name: 'CAT 1#',
              brand: 'CAT',
              defaultUnitPrice: 90,
              baseMeterHours: 0,
            ),
          ],
          rates: const [
            ProjectDeviceRate(
              projectKey: 'Alpha||Site X',
              deviceId: 1,
              rate: 130,
              isBreaking: false,
            ),
            ProjectDeviceRate(
              projectKey: 'Alpha||Site X',
              deviceId: 1,
              rate: 240,
              isBreaking: true,
            ),
            ProjectDeviceRate(
              projectKey: 'Other||Site',
              deviceId: 2,
              rate: 300,
              isBreaking: true,
            ),
          ],
          isBreaking: true,
        );

        expect(result.length, 2);
        expect(result[1], 240); // project breaking override wins
        expect(result[2], 90); // no breaking price -> fallback to default
      },
    );

    test('calcRateInfo marks same-device normal+breaking hours as multi-mode', () {
      const agg = ProjectAgg(
        projectKey: 'Alpha||Site X',
        contact: 'Alpha',
        site: 'Site X',
        minYmd: 20260301,
        deviceIds: [1],
        hoursByDevice: {1: 7},
        normalHoursByDevice: {1: 5},
        breakingHoursByDevice: {1: 2},
        rentIncomeTotal: 0,
      );

      final info = AccountService.calcRateInfo(
        agg: agg,
        devices: const [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            breakingUnitPrice: 150,
            baseMeterHours: 0,
          ),
        ],
        rates: const [],
      );

      expect(info.isMultiMode, isTrue);
      expect(info.isMultiDevice, isFalse);
      expect(info.minRate, 100);
    });

    test('calcRateInfo uses breaking rate when a project only has breaking hours', () {
      const agg = ProjectAgg(
        projectKey: 'Zhao||Shangyi',
        contact: '赵六',
        site: '尚义',
        minYmd: 20260317,
        deviceIds: [1],
        hoursByDevice: {1: 9},
        normalHoursByDevice: {},
        breakingHoursByDevice: {1: 9},
        rentIncomeTotal: 0,
      );

      final info = AccountService.calcRateInfo(
        agg: agg,
        devices: const [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 120,
            breakingUnitPrice: 200,
            baseMeterHours: 0,
          ),
        ],
        rates: const [],
      );

      expect(info.isMultiMode, isFalse);
      expect(info.isMultiDevice, isFalse);
      expect(info.minRate, 200);
    });

    test('calcReceivableByDevice aggregates same device across projects with per-project overrides', () {
      final totals = AccountService.calcReceivableByDevice(
        timingRecords: const [
          // Project A: device 1
          TimingRecord(
            id: 21,
            deviceId: 1,
            startDate: 20260301,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 10,
            hours: 10,
            income: 0,
          ),
          TimingRecord(
            id: 22,
            deviceId: 1,
            startDate: 20260302,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            isBreaking: true,
            startMeter: 10,
            endMeter: 12,
            hours: 2,
            income: 0,
          ),
          // rent should not be included in per-device receivable
          TimingRecord(
            id: 23,
            deviceId: 1,
            startDate: 20260303,
            contact: 'A',
            site: 'X',
            type: TimingType.rent,
            startMeter: 12,
            endMeter: 12,
            hours: 0,
            income: 700,
          ),
          // Project B: device 1 + device 2
          TimingRecord(
            id: 24,
            deviceId: 1,
            startDate: 20260304,
            contact: 'B',
            site: 'Y',
            type: TimingType.hours,
            startMeter: 100,
            endMeter: 103,
            hours: 3,
            income: 0,
          ),
          TimingRecord(
            id: 25,
            deviceId: 1,
            startDate: 20260305,
            contact: 'B',
            site: 'Y',
            type: TimingType.hours,
            isBreaking: true,
            startMeter: 103,
            endMeter: 104,
            hours: 1,
            income: 0,
          ),
          TimingRecord(
            id: 26,
            deviceId: 2,
            startDate: 20260306,
            contact: 'B',
            site: 'Y',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 4,
            hours: 4,
            income: 0,
          ),
        ],
        devices: const [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            breakingUnitPrice: 150,
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
        rates: const [
          // Project A override
          ProjectDeviceRate(
            projectKey: 'A||X',
            deviceId: 1,
            rate: 120,
            isBreaking: false,
          ),
          // Project B overrides
          ProjectDeviceRate(
            projectKey: 'B||Y',
            deviceId: 1,
            rate: 180,
            isBreaking: false,
          ),
          ProjectDeviceRate(
            projectKey: 'B||Y',
            deviceId: 1,
            rate: 260,
            isBreaking: true,
          ),
          ProjectDeviceRate(
            projectKey: 'B||Y',
            deviceId: 2,
            rate: 250,
            isBreaking: false,
          ),
        ],
      );

      // device 1 total: 10*120 + 2*150 + 3*180 + 1*260 = 2300
      // device 2 total: 4*250 = 1000
      expect(totals.length, 2);
      expect(totals[1], 2300);
      expect(totals[2], 1000);
    });
  });
}
