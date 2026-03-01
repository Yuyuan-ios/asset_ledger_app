import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/data/services/fuel_stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FuelStatsService edge cases', () {
    test('returns zero totals when no log falls in the resolved year', () {
      final summary = FuelStatsService.summarizeCurrentYear(
        logs: const [
          FuelLog(
            id: 1,
            deviceId: 1,
            date: 20251231,
            supplier: '张三',
            liters: 100,
            cost: 800,
          ),
        ],
        nowYmd: 20260301,
      );

      expect(summary.yearLabel, 2026);
      expect(summary.liters, 0);
      expect(summary.cost, 0);
    });

    test('treats blank supplier filter as no filter and includes zero values', () {
      final summary = FuelStatsService.summarizeCurrentYear(
        logs: const [
          FuelLog(
            id: 1,
            deviceId: 1,
            date: 20260301,
            supplier: '甲供应商',
            liters: 0,
            cost: 0,
          ),
          FuelLog(
            id: 2,
            deviceId: 1,
            date: 20260302,
            supplier: '乙供应商',
            liters: 10,
            cost: 80,
          ),
        ],
        nowYmd: 20260310,
        supplier: '   ',
      );

      expect(summary.liters, 10);
      expect(summary.cost, 80);
    });

    test('uses contains matching for supplier filtering', () {
      final summary = FuelStatsService.summarizeCurrentYear(
        logs: const [
          FuelLog(
            id: 1,
            deviceId: 1,
            date: 20260301,
            supplier: '贵阳中石化南站',
            liters: 20,
            cost: 160,
          ),
          FuelLog(
            id: 2,
            deviceId: 1,
            date: 20260302,
            supplier: '中海油',
            liters: 10,
            cost: 85,
          ),
        ],
        nowYmd: 20260310,
        supplier: '石化',
      );

      expect(summary.liters, 20);
      expect(summary.cost, 160);
    });
  });
}
