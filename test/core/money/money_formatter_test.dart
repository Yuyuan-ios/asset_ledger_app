import 'package:asset_ledger/core/money/money_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyFormatter', () {
    test('formats yuan amounts through fen rounding', () {
      expect(MoneyFormatter.yuan(1234.6), '¥1235');
      expect(MoneyFormatter.number(15), '15.0');
      expect(MoneyFormatter.fen(126000), '¥1260');
    });
  });
}
