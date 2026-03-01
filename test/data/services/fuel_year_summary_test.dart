import 'package:asset_ledger/data/services/fuel_stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FuelYearSummary', () {
    test('copyWith overrides selected fields and keeps others', () {
      const summary = FuelYearSummary(
        yearLabel: 2026,
        liters: 120.5,
        cost: 980,
      );

      final updated = summary.copyWith(
        liters: 150,
      );

      expect(updated.yearLabel, 2026);
      expect(updated.liters, 150);
      expect(updated.cost, 980);
    });

    test('toString exposes the stable debug representation', () {
      const summary = FuelYearSummary(
        yearLabel: 2026,
        liters: 88,
        cost: 666,
      );

      expect(
        summary.toString(),
        'FuelYearSummary(year=2026, liters=88.0, cost=666.0)',
      );
    });
  });
}
