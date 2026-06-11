import 'package:asset_ledger/core/measure/quantity.dart';
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

    test('rounds negative amounts symmetrically away from zero', () {
      const unitPrice = UnitPrice(12345);

      expect(
        AmountPolicy.calculateAmount(
          hours: const WorkHours(-100),
          unitPrice: unitPrice,
        ).fen,
        -1235,
      );
      expect(
        AmountPolicy.calculateAmount(
          hours: const WorkHours(-500),
          unitPrice: unitPrice,
        ).fen,
        -6173,
      );
      expect(
        AmountPolicy.calculateAmount(
          hours: const WorkHours(-239000),
          unitPrice: unitPrice,
        ).fen,
        -2950455,
      );

      // Exactly 0.5 fen magnitude rounds away from zero for both signs.
      const halfUnit = UnitPrice(5);
      expect(
        AmountPolicy.calculateAmount(
          hours: const WorkHours(100),
          unitPrice: halfUnit,
        ).fen,
        1,
      );
      expect(
        AmountPolicy.calculateAmount(
          hours: const WorkHours(-100),
          unitPrice: halfUnit,
        ).fen,
        -1,
      );
    });
  });

  group('AmountPolicy.calculateAmountForQuantity', () {
    test('HOUR legacy path delegates to the generic quantity path', () {
      const unitPrice = UnitPrice(12345);
      for (final milli in [100, 500, 1500, 239000, -100, -239000]) {
        expect(
          AmountPolicy.calculateAmountForQuantity(
            quantity: Quantity(milli),
            unitPrice: unitPrice,
          ).fen,
          AmountPolicy.calculateAmount(
            hours: WorkHours(milli),
            unitPrice: unitPrice,
          ).fen,
        );
      }
    });

    test('calculates outline boundary cases without float drift', () {
      // 12.5 亩 × 80 元/亩 = 1000 元。
      expect(
        AmountPolicy.calculateAmountForQuantity(
          quantity: Quantity.fromValue(12.5),
          unitPrice: const UnitPrice(8000),
        ).fen,
        100000,
      );
      // 3 趟（整数趟次）× 350 元/趟 = 1050 元。
      expect(
        AmountPolicy.calculateAmountForQuantity(
          quantity: Quantity.fromValue(3),
          unitPrice: const UnitPrice(35000),
        ).fen,
        105000,
      );
      // 1.5 台班 × 1200 元/台班 = 1800 元。
      expect(
        AmountPolicy.calculateAmountForQuantity(
          quantity: const Quantity(1500),
          unitPrice: const UnitPrice(120000),
        ).fen,
        180000,
      );
      // 0.1 计量单位 × 123.45 元 = 12.345 元 → 12.35 元（半分进位）。
      expect(
        AmountPolicy.calculateAmountForQuantity(
          quantity: const Quantity(100),
          unitPrice: const UnitPrice(12345),
        ).fen,
        1235,
      );
      // 12.5 亩 × 80.01 元/亩 = 1000.125 元 → 100013 分（精确半分离零进位）。
      expect(
        AmountPolicy.calculateAmountForQuantity(
          quantity: const Quantity(12500),
          unitPrice: const UnitPrice(8001),
        ).fen,
        100013,
      );
    });

    test('scaled decimal input matches direct integer scaling', () {
      expect(Quantity.fromValue(7.5).scaled, 7500);
      expect(Quantity.fromValue(12.5).scaled, 12500);
      expect(Quantity.fromValue(3).scaled, 3000);
      expect(Quantity.fromValue(1.5).scaled, 1500);
      expect(Quantity.fromValue(0.1).scaled, 100);
    });
  });
}
