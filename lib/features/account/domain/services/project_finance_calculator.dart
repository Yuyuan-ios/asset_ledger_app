import 'dart:math' as math;

import '../../../../core/money/amount_policy.dart';

class ProjectFinanceCalculator {
  const ProjectFinanceCalculator._();

  static ProjectFinanceSummary summarize({
    required int receivableFen,
    Iterable<int> receivedFenParts = const [],
    Iterable<int> writeOffFenParts = const [],
    int toleranceFen = 0,
  }) {
    return summarizeTotals(
      receivableFen: receivableFen,
      receivedFen: _sumNonNegative(receivedFenParts, 'receivedFenParts'),
      writeOffFen: _sumNonNegative(writeOffFenParts, 'writeOffFenParts'),
      toleranceFen: toleranceFen,
    );
  }

  static ProjectFinanceSummary summarizeTotals({
    required int receivableFen,
    required int receivedFen,
    required int writeOffFen,
    int toleranceFen = 0,
  }) {
    _rejectNegative(receivableFen, 'receivableFen');
    _rejectNegative(receivedFen, 'receivedFen');
    _rejectNegative(writeOffFen, 'writeOffFen');
    _rejectNegative(toleranceFen, 'toleranceFen');

    final rawRemainingFen = receivableFen - receivedFen - writeOffFen;
    final remainingFen = rawRemainingFen.abs() <= toleranceFen
        ? 0
        : rawRemainingFen;
    final settledAmountFen = receivedFen + writeOffFen;

    return ProjectFinanceSummary(
      receivableFen: receivableFen,
      receivedFen: receivedFen,
      writeOffFen: writeOffFen,
      remainingFen: remainingFen,
      cashRate: receivableFen <= 0 ? null : receivedFen / receivableFen,
      settlementRate: receivableFen <= 0
          ? null
          : settledAmountFen / receivableFen,
      overPaidFen: math.max(0, settledAmountFen - receivableFen),
      isSettled: remainingFen <= 0,
    );
  }

  static int calculateWorkAmountFen({
    required int hoursMilli,
    required int unitPriceFenPerHour,
  }) {
    _rejectNegative(hoursMilli, 'hoursMilli');
    _rejectNegative(unitPriceFenPerHour, 'unitPriceFenPerHour');
    return AmountPolicy.calculateAmount(
      hours: WorkHours(hoursMilli),
      unitPrice: UnitPrice(unitPriceFenPerHour),
    ).fen;
  }

  static int yuanToFen(double yuan) => Money.fromYuan(yuan).fen;

  static double fenToYuan(int fen) => Money(fen).yuan;

  static int hoursToMilli(double hours) =>
      WorkHours.fromHours(hours).milliHours;

  static int yuanPerHourToFen(double yuanPerHour) {
    return UnitPrice.fromYuanPerHour(yuanPerHour).fenPerHour;
  }

  static int _sumNonNegative(Iterable<int> values, String name) {
    var total = 0;
    for (final value in values) {
      _rejectNegative(value, name);
      total += value;
    }
    return total;
  }

  static void _rejectNegative(int value, String name) {
    if (value < 0) {
      throw ArgumentError.value(value, name, '金额或工时不能为负数');
    }
  }
}

class ProjectFinanceSummary {
  const ProjectFinanceSummary({
    required this.receivableFen,
    required this.receivedFen,
    required this.writeOffFen,
    required this.remainingFen,
    required this.cashRate,
    required this.settlementRate,
    required this.overPaidFen,
    required this.isSettled,
  });

  final int receivableFen;
  final int receivedFen;
  final int writeOffFen;
  final int remainingFen;
  final double? cashRate;
  final double? settlementRate;
  final int overPaidFen;
  final bool isSettled;

  double get receivable => ProjectFinanceCalculator.fenToYuan(receivableFen);
  double get received => ProjectFinanceCalculator.fenToYuan(receivedFen);
  double get writeOff => ProjectFinanceCalculator.fenToYuan(writeOffFen);
  double get remaining => ProjectFinanceCalculator.fenToYuan(remainingFen);
  double get overPaid => ProjectFinanceCalculator.fenToYuan(overPaidFen);
}
