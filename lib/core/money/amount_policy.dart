import '../measure/quantity.dart';

class Money {
  final int fen;

  const Money(this.fen);

  factory Money.fromYuan(double yuan) {
    return Money((yuan * 100).round());
  }

  double get yuan => fen / 100;
}

class WorkHours {
  final int milliHours;

  const WorkHours(this.milliHours);

  factory WorkHours.fromHours(double hours) {
    return WorkHours((hours * 1000).round());
  }
}

/// 每一个计量单位的单价(整数分)。字段名 fenPerHour 是 HOUR 时代的历史命名,
/// 语义上是「分/单位」——台班/亩/吨/趟次等口径下同样适用,见 [fenPerUnit]。
class UnitPrice {
  final int fenPerHour;

  const UnitPrice(this.fenPerHour);

  factory UnitPrice.fromYuanPerHour(double yuanPerHour) {
    return UnitPrice((yuanPerHour * 100).round());
  }

  /// 通用口径别名:每一个计量单位(小时/台班/亩/吨/趟…)的单价,整数分。
  int get fenPerUnit => fenPerHour;
}

class AmountPolicy {
  const AmountPolicy._();

  /// 统一计算口径:amount_fen = round(quantity_scaled × unit_price_fen / 1000),
  /// 四舍五入对称离零。任意计量单位共用这一条整数路径,杜绝浮点漂移。
  static Money calculateAmountForQuantity({
    required Quantity quantity,
    required UnitPrice unitPrice,
  }) {
    final scaled = quantity.scaled * unitPrice.fenPerUnit;
    if (scaled >= 0) {
      return Money((scaled + 500) ~/ 1000);
    }
    return Money(-((-scaled + 500) ~/ 1000));
  }

  /// HOUR 特例:hours_milli 即 quantity_scaled 在工时单位下的旧名。
  static Money calculateAmount({
    required WorkHours hours,
    required UnitPrice unitPrice,
  }) {
    return calculateAmountForQuantity(
      quantity: Quantity(hours.milliHours),
      unitPrice: unitPrice,
    );
  }
}
