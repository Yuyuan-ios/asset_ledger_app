import 'package:asset_ledger/features/account/domain/services/project_finance_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectFinanceCalculator', () {
    test('returns null rates for zero receivable', () {
      final summary = ProjectFinanceCalculator.summarizeTotals(
        receivableFen: 0,
        receivedFen: 0,
        writeOffFen: 0,
      );

      expect(summary.remainingFen, 0);
      expect(summary.cashRate, isNull);
      expect(summary.settlementRate, isNull);
      expect(summary.isSettled, isTrue);
    });

    test('handles zero received and zero write-off', () {
      final summary = ProjectFinanceCalculator.summarizeTotals(
        receivableFen: 100000,
        receivedFen: 0,
        writeOffFen: 0,
      );

      expect(summary.remainingFen, 100000);
      expect(summary.cashRate, 0);
      expect(summary.settlementRate, 0);
      expect(summary.isSettled, isFalse);
    });

    test('calculates partial cash collection', () {
      final summary = ProjectFinanceCalculator.summarizeTotals(
        receivableFen: 100000,
        receivedFen: 25000,
        writeOffFen: 0,
      );

      expect(summary.remainingFen, 75000);
      expect(summary.cashRate, 0.25);
      expect(summary.settlementRate, 0.25);
    });

    test('detects exact settlement', () {
      final summary = ProjectFinanceCalculator.summarizeTotals(
        receivableFen: 100000,
        receivedFen: 100000,
        writeOffFen: 0,
      );

      expect(summary.remainingFen, 0);
      expect(summary.overPaidFen, 0);
      expect(summary.isSettled, isTrue);
    });

    test('detects over payment', () {
      final summary = ProjectFinanceCalculator.summarizeTotals(
        receivableFen: 100000,
        receivedFen: 100001,
        writeOffFen: 0,
      );

      expect(summary.remainingFen, -1);
      expect(summary.overPaidFen, 1);
      expect(summary.isSettled, isTrue);
    });

    test('settles with write-off only', () {
      final summary = ProjectFinanceCalculator.summarizeTotals(
        receivableFen: 6000,
        receivedFen: 0,
        writeOffFen: 6000,
      );

      expect(summary.cashRate, 0);
      expect(summary.settlementRate, 1);
      expect(summary.remainingFen, 0);
    });

    test('settles with received plus write-off', () {
      final summary = ProjectFinanceCalculator.summarizeTotals(
        receivableFen: 126000,
        receivedFen: 120000,
        writeOffFen: 6000,
      );

      expect(summary.cashRate, closeTo(120000 / 126000, 0.000001));
      expect(summary.settlementRate, 1);
      expect(summary.isSettled, isTrue);
    });

    test('recalculates after deleting payment', () {
      final summary = ProjectFinanceCalculator.summarize(
        receivableFen: 100000,
        receivedFenParts: const [20000, 30000],
        writeOffFenParts: const [10000],
      );
      final afterDelete = ProjectFinanceCalculator.summarize(
        receivableFen: 100000,
        receivedFenParts: const [20000],
        writeOffFenParts: const [10000],
      );

      expect(summary.remainingFen, 40000);
      expect(afterDelete.remainingFen, 70000);
    });

    test('recalculates after deleting write-off', () {
      final summary = ProjectFinanceCalculator.summarize(
        receivableFen: 100000,
        receivedFenParts: const [70000],
        writeOffFenParts: const [30000],
      );
      final afterDelete = ProjectFinanceCalculator.summarize(
        receivableFen: 100000,
        receivedFenParts: const [70000],
      );

      expect(summary.isSettled, isTrue);
      expect(afterDelete.remainingFen, 30000);
      expect(afterDelete.isSettled, isFalse);
    });

    test('rejects negative money', () {
      expect(
        () => ProjectFinanceCalculator.summarizeTotals(
          receivableFen: 100,
          receivedFen: -1,
          writeOffFen: 0,
        ),
        throwsArgumentError,
      );
    });

    test('absorbs one fen tolerance', () {
      final summary = ProjectFinanceCalculator.summarizeTotals(
        receivableFen: 100000,
        receivedFen: 99999,
        writeOffFen: 0,
        toleranceFen: 1,
      );

      expect(summary.remainingFen, 0);
      expect(summary.isSettled, isTrue);
    });

    test('calculates rent project totals', () {
      final rentFen = ProjectFinanceCalculator.yuanToFen(22000);
      final summary = ProjectFinanceCalculator.summarizeTotals(
        receivableFen: rentFen,
        receivedFen: ProjectFinanceCalculator.yuanToFen(12000),
        writeOffFen: 0,
      );

      expect(summary.receivable, 22000);
      expect(summary.remaining, 10000);
    });

    test('calculates normal work amount with milli-hours', () {
      final amountFen = ProjectFinanceCalculator.calculateWorkAmountFen(
        hoursMilli: 2500,
        unitPriceFenPerHour: 12000,
      );

      expect(amountFen, 30000);
    });

    test('calculates breaking work amount with separate price', () {
      final amountFen = ProjectFinanceCalculator.calculateWorkAmountFen(
        hoursMilli: 1500,
        unitPriceFenPerHour: 20000,
      );

      expect(amountFen, 30000);
    });

    test('combines normal and breaking work amounts', () {
      final normal = ProjectFinanceCalculator.calculateWorkAmountFen(
        hoursMilli: 2000,
        unitPriceFenPerHour: 10000,
      );
      final breaking = ProjectFinanceCalculator.calculateWorkAmountFen(
        hoursMilli: 1000,
        unitPriceFenPerHour: 18000,
      );

      expect(normal + breaking, 38000);
    });

    test('summarizes merged project totals', () {
      final summary = ProjectFinanceCalculator.summarize(
        receivableFen: 200000,
        receivedFenParts: const [30000, 40000],
        writeOffFenParts: const [10000, 20000],
      );

      expect(summary.receivedFen, 70000);
      expect(summary.writeOffFen, 30000);
      expect(summary.remainingFen, 100000);
    });

    test('supports legacy project key fallback totals after id resolution', () {
      final summary = ProjectFinanceCalculator.summarizeTotals(
        receivableFen: ProjectFinanceCalculator.yuanToFen(1260),
        receivedFen: ProjectFinanceCalculator.yuanToFen(1200),
        writeOffFen: ProjectFinanceCalculator.yuanToFen(60),
      );

      expect(summary.remainingFen, 0);
      expect(summary.settlementRate, 1);
    });
  });
}
