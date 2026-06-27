import 'package:asset_ledger/tokens/mapper/summary_card_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('summary card chrome has no border or shadow by default', () {
    final decoration = SummaryCardTokens.cardDecoration();

    expect(SummaryCardTokens.cardBorderWidth, 0);
    expect(SummaryCardTokens.cardBorder, isNull);
    expect(SummaryCardTokens.cardShadows, isNull);
    expect(decoration.border, isNull);
    expect(decoration.boxShadow, isNull);
    expect(decoration.color, SummaryCardTokens.cardBackground);
    expect(decoration.borderRadius, SummaryCardTokens.cardBorderRadius);
  });
}
