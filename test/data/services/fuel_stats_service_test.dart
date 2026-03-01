import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/data/services/fuel_stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FuelStatsService.summarizeCurrentYear', () {
    test('sums only logs inside the resolved year range', () {
      final summary = FuelStatsService.summarizeCurrentYear(
        logs: const [
          FuelLog(
            id: 1,
            deviceId: 1,
            date: 20260101,
            supplier: '张三',
            liters: 100,
            cost: 800,
          ),
          FuelLog(
            id: 2,
            deviceId: 1,
            date: 20260601,
            supplier: '张三',
            liters: 50,
            cost: 450,
          ),
          FuelLog(
            id: 3,
            deviceId: 1,
            date: 20251231,
            supplier: '张三',
            liters: 200,
            cost: 1600,
          ),
        ],
        nowYmd: 20260301,
      );

      expect(summary.yearLabel, 2026);
      expect(summary.liters, 150);
      expect(summary.cost, 1250);
    });

    test('filters supplier by contains match when provided', () {
      final summary = FuelStatsService.summarizeCurrentYear(
        logs: const [
          FuelLog(
            id: 1,
            deviceId: 1,
            date: 20260301,
            supplier: '何小波',
            liters: 100,
            cost: 900,
          ),
          FuelLog(
            id: 2,
            deviceId: 1,
            date: 20260302,
            supplier: '老何',
            liters: 20,
            cost: 180,
          ),
          FuelLog(
            id: 3,
            deviceId: 1,
            date: 20260303,
            supplier: '修文加油站',
            liters: 10,
            cost: 90,
          ),
        ],
        nowYmd: 20260310,
        supplier: '何',
      );

      expect(summary.liters, 120);
      expect(summary.cost, 1080);
    });
  });
}
