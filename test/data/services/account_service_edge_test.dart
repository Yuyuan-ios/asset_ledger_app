import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
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
  });
}
