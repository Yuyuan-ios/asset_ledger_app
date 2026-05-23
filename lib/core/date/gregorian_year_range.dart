import 'ymd_date.dart';

class GregorianYearRange {
  const GregorianYearRange._({
    required this.year,
    required this.startInclusiveYmd,
    required this.endExclusiveYmd,
  });

  final int year;
  final int startInclusiveYmd;
  final int endExclusiveYmd;

  factory GregorianYearRange.forYear(int year) {
    return GregorianYearRange._(
      year: year,
      startInclusiveYmd: year * 10000 + 101,
      endExclusiveYmd: (year + 1) * 10000 + 101,
    );
  }

  factory GregorianYearRange.containingYmd(int ymd) {
    final parsed = YmdDate.fromInt(ymd);
    return GregorianYearRange.forYear(parsed?.year ?? ymd ~/ 10000);
  }

  bool containsYmd(int ymd) {
    return ymd >= startInclusiveYmd && ymd < endExclusiveYmd;
  }

  bool containsDateText(String value) {
    final parsed = YmdDate.tryParseStrict(value);
    return parsed != null && containsYmd(parsed.value);
  }
}
