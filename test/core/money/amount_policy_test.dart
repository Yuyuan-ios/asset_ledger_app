import 'package:asset_ledger/core/money/amount_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AmountPolicy', () {
    test('calculates stable fen amounts for boundary work hours', () {
      const unitPrice = UnitPrice(12345);

      expect(
        AmountPolicy.calculateAmount(
          hours: const WorkHours(100),
          unitPrice: unitPrice,
        ).fen,
        1235,
      );
      expect(
        AmountPolicy.calculateAmount(
          hours: const WorkHours(500),
          unitPrice: unitPrice,
        ).fen,
        6173,
      );
      expect(
        AmountPolicy.calculateAmount(
          hours: const WorkHours(1500),
          unitPrice: unitPrice,
        ).fen,
        18518,
      );
      expect(
        AmountPolicy.calculateAmount(
          hours: const WorkHours(239000),
          unitPrice: unitPrice,
        ).fen,
        2950455,
      );
    });

    test('converts decimal yuan and hours into integer policy inputs', () {
      final amount = AmountPolicy.calculateAmount(
        hours: WorkHours.fromHours(1.5),
        unitPrice: UnitPrice.fromYuanPerHour(380),
      );

      expect(amount.fen, 57000);
      expect(amount.yuan, 570);
    });
  });
}
