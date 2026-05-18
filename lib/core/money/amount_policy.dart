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

class UnitPrice {
  final int fenPerHour;

  const UnitPrice(this.fenPerHour);

  factory UnitPrice.fromYuanPerHour(double yuanPerHour) {
    return UnitPrice((yuanPerHour * 100).round());
  }
}

class AmountPolicy {
  const AmountPolicy._();

  static Money calculateAmount({
    required WorkHours hours,
    required UnitPrice unitPrice,
  }) {
    final scaled = hours.milliHours * unitPrice.fenPerHour;
    if (scaled >= 0) {
      return Money((scaled + 500) ~/ 1000);
    }
    return Money(-((-scaled + 500) ~/ 1000));
  }
}
