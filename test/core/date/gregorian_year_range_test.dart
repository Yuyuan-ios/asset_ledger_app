import 'package:asset_ledger/core/date/gregorian_year_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GregorianYearRange', () {
    test('uses January 1 inclusive and next January 1 exclusive', () {
      final range = GregorianYearRange.forYear(2026);

      expect(range.containsYmd(20260101), isTrue);
      expect(range.containsYmd(20261231), isTrue);
      expect(range.containsYmd(20270101), isFalse);
    });

    test('parses dashed date text for the same calendar-year scope', () {
      final range = GregorianYearRange.forYear(2026);

      expect(range.containsDateText('2026-01-01'), isTrue);
      expect(range.containsDateText('2026-12-31'), isTrue);
      expect(range.containsDateText('2027-01-01'), isFalse);
    });
  });
}
