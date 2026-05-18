import 'amount_policy.dart';

class MoneyFormatter {
  const MoneyFormatter._();

  static String yuan(double amount) {
    return '¥${Money.fromYuan(amount).yuan.toStringAsFixed(0)}';
  }

  static String number(double amount) {
    return Money.fromYuan(amount).yuan.toStringAsFixed(1);
  }

  static String fen(int amountFen) {
    return '¥${Money(amountFen).yuan.toStringAsFixed(0)}';
  }
}
