import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/data/services/fuel_stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FuelStatsService year boundaries', () {
    test('includes logs exactly on the start and end dates of the resolved year', () {
      final summary = FuelStatsService.summarizeCurrentYear(
        logs: const [
          FuelLog(
            id: 1,
            deviceId: 1,
            date: 20260101,
            supplier: '甲',
            liters: 10,
            cost: 80,
          ),
          FuelLog(
            id: 2,
            deviceId: 1,
            date: 20261231,
            supplier: '乙',
            liters: 20,
            cost: 160,
          ),
          FuelLog(
            id: 3,
            deviceId: 1,
            date: 20270101,
            supplier: '丙',
            liters: 30,
            cost: 240,
          ),
        ],
        nowYmd: 20260601,
      );

      expect(summary.yearLabel, 2026);
      expect(summary.liters, 30);
      expect(summary.cost, 240);
    });

    test('trims the supplier filter before applying contains matching', () {
      final summary = FuelStatsService.summarizeCurrentYear(
        logs: const [
          FuelLog(
            id: 1,
            deviceId: 1,
            date: 20260301,
            supplier: '贵阳石化站',
            liters: 10,
            cost: 80,
          ),
          FuelLog(
            id: 2,
            deviceId: 1,
            date: 20260302,
            supplier: '中海油',
            liters: 20,
            cost: 160,
          ),
        ],
        nowYmd: 20260310,
        supplier: '  石化  ',
      );

      expect(summary.liters, 10);
      expect(summary.cost, 80);
    });
  });
}
