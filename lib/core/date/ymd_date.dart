class YmdDate {
  const YmdDate._(this.value);

  final int value;

  int get year => value ~/ 10000;
  int get month => (value ~/ 100) % 100;
  int get day => value % 100;

  DateTime toDateTime() => DateTime(year, month, day);

  /// 1970-01-01 = 0 的序日（proleptic Gregorian，无时区/无 DST）。
  int toEpochDay() {
    final y = month <= 2 ? year - 1 : year;
    final era = (y >= 0 ? y : y - 399) ~/ 400;
    final yoe = y - era * 400;
    final doy = (153 * (month > 2 ? month - 3 : month + 9) + 2) ~/ 5 + day - 1;
    final doe = yoe * 365 + yoe ~/ 4 - yoe ~/ 100 + doy;
    return era * 146097 + doe - 719468;
  }

  int daysBetween(YmdDate other) => other.toEpochDay() - toEpochDay();

  String get compact => value.toString().padLeft(8, '0');

  String get dashed {
    final s = compact;
    return '${s.substring(0, 4)}-${s.substring(4, 6)}-${s.substring(6, 8)}';
  }

  String get dotted {
    final s = compact;
    return '${s.substring(0, 4)}.${s.substring(4, 6)}.${s.substring(6, 8)}';
  }

  static YmdDate? fromInt(int ymd) {
    if (ymd < 10000101 || ymd > 99991231) return null;
    return _fromParts(
      year: ymd ~/ 10000,
      month: (ymd ~/ 100) % 100,
      day: ymd % 100,
    );
  }

  static YmdDate? tryParseStrict(String input) {
    final source = input.trim();
    if (source.isEmpty) return null;

    final match = RegExp(
      r'^(\d{4})(?:([.\-/]?)(\d{2})\2(\d{2}))$',
    ).firstMatch(source);
    if (match == null) return null;

    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(3)!);
    final day = int.tryParse(match.group(4)!);
    if (year == null || month == null || day == null) return null;
    return _fromParts(year: year, month: month, day: day);
  }

  static YmdDate? _fromParts({
    required int year,
    required int month,
    required int day,
  }) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return YmdDate._(year * 10000 + month * 100 + day);
  }
}
