import 'package:asset_ledger/data/services/suggest_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SuggestService.uniqueHistory', () {
    test('trims values, removes blanks, and de-duplicates case-insensitively', () {
      final result = SuggestService.uniqueHistory([
        '  Alice  ',
        '',
        'alice',
        ' Bob ',
        'ALICE',
        'bob',
      ]);

      expect(result, ['Alice', 'Bob']);
    });
  });

  group('SuggestService.suggestStrings', () {
    test('returns prefix matches before contains matches and respects limit', () {
      final result = SuggestService.suggestStrings(
        history: ['alpha', 'Beta', 'alphabet', 'cab', 'ALPHA'],
        query: 'al',
        limit: 2,
      );

      expect(result, ['alpha', 'alphabet']);
    });

    test('returns the de-duplicated history head when query is blank', () {
      final result = SuggestService.suggestStrings(
        history: [' diesel ', 'Diesel', 'petrol'],
        query: '   ',
      );

      expect(result, ['diesel', 'petrol']);
    });
  });
}
