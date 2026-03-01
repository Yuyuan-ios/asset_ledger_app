import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/data/services/fuel_suggest_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FuelSuggestService.supplierCandidates', () {
    test('extracts supplier history and removes blank or duplicate entries', () {
      final result = FuelSuggestService.supplierCandidates(const [
        FuelLog(
          id: 1,
          deviceId: 1,
          date: 20260301,
          supplier: '  中石化  ',
          liters: 20,
          cost: 160,
        ),
        FuelLog(
          id: 2,
          deviceId: 1,
          date: 20260302,
          supplier: '',
          liters: 10,
          cost: 80,
        ),
        FuelLog(
          id: 3,
          deviceId: 1,
          date: 20260303,
          supplier: '中石化',
          liters: 15,
          cost: 120,
        ),
        FuelLog(
          id: 4,
          deviceId: 1,
          date: 20260304,
          supplier: '民营油站',
          liters: 8,
          cost: 64,
        ),
      ]);

      expect(result, ['中石化', '民营油站']);
    });
  });

  group('FuelSuggestService.supplierSuggestions', () {
    test('filters with prefix-first ordering through the shared suggest rules', () {
      final result = FuelSuggestService.supplierSuggestions(
        const [
          FuelLog(
            id: 1,
            deviceId: 1,
            date: 20260301,
            supplier: '中海油',
            liters: 20,
            cost: 160,
          ),
          FuelLog(
            id: 2,
            deviceId: 1,
            date: 20260302,
            supplier: '老中石化',
            liters: 10,
            cost: 80,
          ),
          FuelLog(
            id: 3,
            deviceId: 1,
            date: 20260303,
            supplier: '中石化',
            liters: 15,
            cost: 120,
          ),
        ],
        '中',
        limit: 2,
      );

      expect(result, ['中海油', '中石化']);
    });
  });
}
