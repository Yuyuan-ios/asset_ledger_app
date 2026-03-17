import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/services/account_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountService edge cases', () {
    test('calcMoney returns a null ratio when receivable is effectively zero', () {
      const agg = ProjectAgg(
        projectKey: 'Alice||Yard A',
        contact: 'Alice',
        site: 'Yard A',
        minYmd: 20260301,
        deviceIds: [99],
        hoursByDevice: {99: 5},
        normalHoursByDevice: {99: 5},
        breakingHoursByDevice: {},
        rentIncomeTotal: 0,
      );

      final money = AccountService.calcMoney(
        agg: agg,
        devices: const [],
        rates: const [],
        payments: const [],
      );

      expect(money.receivable, 0);
      expect(money.received, 0);
      expect(money.remaining, 0);
      expect(money.ratio, isNull);
    });

    test('buildEffectiveRateMap keeps defaults and allows override-only device ids', () {
      final result = AccountService.buildEffectiveRateMap(
        projectKey: 'Alice||Yard A',
        devices: const [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
        ],
        rates: const [
          ProjectDeviceRate(
            projectKey: 'Alice||Yard A',
            deviceId: 1,
            rate: 120,
          ),
          ProjectDeviceRate(
            projectKey: 'Alice||Yard A',
            deviceId: 8,
            rate: 200,
          ),
          ProjectDeviceRate(
            projectKey: 'Bob||Yard B',
            deviceId: 1,
            rate: 300,
          ),
        ],
      );

      expect(result, {
        1: 120.0,
        8: 200.0,
      });
    });

    test('calcRateInfo returns null minRate when no positive effective rate is used', () {
      const agg = ProjectAgg(
        projectKey: 'Alice||Yard A',
        contact: 'Alice',
        site: 'Yard A',
        minYmd: 20260301,
        deviceIds: [1],
        hoursByDevice: {1: 5},
        normalHoursByDevice: {1: 5},
        breakingHoursByDevice: {},
        rentIncomeTotal: 0,
      );

      final info = AccountService.calcRateInfo(
        agg: agg,
        devices: const [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 0,
            baseMeterHours: 0,
          ),
        ],
        rates: const [],
      );

      expect(info.minRate, isNull);
      expect(info.isMultiDevice, isFalse);
    });

    test('calcMoney allows over-received amounts and returns negative remaining', () {
      const agg = ProjectAgg(
        projectKey: 'Over||Pay',
        contact: 'Over',
        site: 'Pay',
        minYmd: 20260301,
        deviceIds: [1],
        hoursByDevice: {1: 5},
        normalHoursByDevice: {1: 5},
        breakingHoursByDevice: {},
        rentIncomeTotal: 0,
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
        ],
        rates: const [],
        payments: const [
          AccountPayment(
            id: 1,
            projectKey: 'Over||Pay',
            ymd: 20260302,
            amount: 300,
          ),
          AccountPayment(
            id: 2,
            projectKey: 'Over||Pay',
            ymd: 20260303,
            amount: 350,
          ),
        ],
      );

      expect(money.receivable, 500);
      expect(money.received, 650);
      expect(money.remaining, -150);
      expect(money.ratio, closeTo(1.3, 0.000001));
    });

    test('buildProjects merges same key after trim and keeps project boundaries', () {
      final projects = AccountService.buildProjects(
        timingRecords: const [
          TimingRecord(
            id: 101,
            deviceId: 1,
            startDate: 20260302,
            contact: '  Alpha ',
            site: ' Site A ',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 2,
            hours: 2,
            income: 0,
          ),
          TimingRecord(
            id: 102,
            deviceId: 1,
            startDate: 20260301,
            contact: 'Alpha',
            site: 'Site A',
            type: TimingType.rent,
            startMeter: 2,
            endMeter: 2,
            hours: 0,
            income: 100,
          ),
          TimingRecord(
            id: 103,
            deviceId: 2,
            startDate: 20260303,
            contact: 'Alpha',
            site: 'Site A',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 3,
            hours: 3,
            income: 0,
          ),
          TimingRecord(
            id: 104,
            deviceId: 3,
            startDate: 20260304,
            contact: 'Alpha',
            site: 'Site B',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 1,
            hours: 1,
            income: 0,
          ),
          TimingRecord(
            id: 105,
            deviceId: 9,
            startDate: 20260305,
            contact: '   ',
            site: 'Site A',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 2,
            hours: 2,
            income: 0,
          ),
        ],
      );

      expect(projects.keys.toSet(), {'Alpha||Site A', 'Alpha||Site B'});
      expect(projects['Alpha||Site A']!.minYmd, 20260301);
      expect(projects['Alpha||Site A']!.deviceIds, [1, 2]);
      expect(projects['Alpha||Site A']!.hoursByDevice, {1: 2, 2: 3});
      expect(projects['Alpha||Site A']!.rentIncomeTotal, 100);
      expect(projects['Alpha||Site B']!.hoursByDevice, {3: 1});
    });

    test('calcReceivableByDevice applies non-positive project overrides directly', () {
      final totals = AccountService.calcReceivableByDevice(
        timingRecords: const [
          TimingRecord(
            id: 201,
            deviceId: 1,
            startDate: 20260301,
            contact: 'P',
            site: 'S',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 2,
            hours: 2,
            income: 0,
          ),
          TimingRecord(
            id: 202,
            deviceId: 1,
            startDate: 20260302,
            contact: 'P',
            site: 'S',
            type: TimingType.hours,
            isBreaking: true,
            startMeter: 2,
            endMeter: 3,
            hours: 1,
            income: 0,
          ),
          TimingRecord(
            id: 203,
            deviceId: 2,
            startDate: 20260303,
            contact: 'P',
            site: 'S',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 3,
            hours: 3,
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
            defaultUnitPrice: 80,
            baseMeterHours: 0,
          ),
        ],
        rates: const [
          ProjectDeviceRate(
            projectKey: 'P||S',
            deviceId: 1,
            rate: 0,
            isBreaking: false,
          ),
          ProjectDeviceRate(
            projectKey: 'P||S',
            deviceId: 1,
            rate: -20,
            isBreaking: true,
          ),
        ],
      );

      // device1: 2*0 + 1*(-20) = -20
      // device2: 3*80 = 240
      expect(totals.length, 2);
      expect(totals[1], -20);
      expect(totals[2], 240);
    });
  });
}
