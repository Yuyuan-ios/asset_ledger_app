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
  });
}
