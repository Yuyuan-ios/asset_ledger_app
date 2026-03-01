import 'package:asset_ledger/data/services/suggest_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SuggestService edge cases', () {
    test('returns contains matches after prefix matches in original order', () {
      final result = SuggestService.suggestStrings(
        history: ['Beta yard', 'yard-alpha', 'Alpha yard', 'shipyard'],
        query: 'yard',
      );

      expect(result, ['yard-alpha', 'Beta yard', 'Alpha yard', 'shipyard']);
    });

    test('returns an empty list when limit is zero', () {
      final result = SuggestService.suggestStrings(
        history: ['alpha', 'beta'],
        query: '',
        limit: 0,
      );

      expect(result, isEmpty);
    });
  });
}
