import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/services/timing_suggest_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const records = [
    TimingRecord(
      id: 1,
      deviceId: 1,
      startDate: 20260301,
      contact: '  Alice  ',
      site: 'Alpha Yard',
      type: TimingType.hours,
      startMeter: 10,
      endMeter: 20,
      hours: 10,
      income: 1000,
    ),
    TimingRecord(
      id: 2,
      deviceId: 1,
      startDate: 20260302,
      contact: 'ALICE',
      site: 'Beta Yard',
      type: TimingType.hours,
      startMeter: 20,
      endMeter: 30,
      hours: 10,
      income: 1000,
    ),
    TimingRecord(
      id: 3,
      deviceId: 1,
      startDate: 20260303,
      contact: 'Bob',
      site: 'alpha annex',
      type: TimingType.hours,
      startMeter: 30,
      endMeter: 40,
      hours: 10,
      income: 1000,
    ),
  ];

  group('TimingSuggestService.contactCandidates', () {
    test('extracts distinct contacts from timing records', () {
      final result = TimingSuggestService.contactCandidates(records);

      expect(result, ['Alice', 'Bob']);
    });
  });

  group('TimingSuggestService.contactSuggestions', () {
    test('matches contacts case-insensitively with prefix before contains', () {
      final result = TimingSuggestService.contactSuggestions(
        records,
        'al',
      );

      expect(result, ['Alice']);
    });
  });

  group('TimingSuggestService.siteSuggestions', () {
    test('returns prefix matches before contains matches for sites', () {
      final result = TimingSuggestService.siteSuggestions(records, 'alpha');

      expect(result, ['Alpha Yard', 'alpha annex']);
    });
  });
}
