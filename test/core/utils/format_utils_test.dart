import 'package:asset_ledger/core/utils/format_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FormatUtils basic formatting', () {
    test('formats money hours liters and percent with the shared precision', () {
      expect(FormatUtils.money(1234.6), '¥1235');
      expect(FormatUtils.hours(12.34), '12.3 h');
      expect(FormatUtils.liters(8), '8.0');
      expect(FormatUtils.meter(9.96), '10.0');
      expect(FormatUtils.moneyNumber(15), '15.0');
      expect(FormatUtils.percent1(0.126), '12.6%');
      expect(FormatUtils.percent1(null), '-');
    });
  });

  group('FormatUtils date formatting', () {
    test('formats and parses dates using the configured dotted style', () {
      expect(FormatUtils.date(20260301), '2026.03.01');
      expect(FormatUtils.date(202631), '202631');
      expect(FormatUtils.parseDate('2026-03-01'), 20260301);
      expect(FormatUtils.parseDate('2026.03.01'), 20260301);
      expect(FormatUtils.parseDate('2026/03/01'), 20260301);
      expect(FormatUtils.parseDate('2026/3/1'), isNull);
    });

    test('builds today values and round-trips ymd conversions', () {
      final now = DateTime(2026, 3, 1);

      expect(FormatUtils.todayYmd(now: now), '20260301');
      expect(FormatUtils.todayDisplayDate(now: now), '2026.03.01');
      expect(FormatUtils.ymdFromDate(now), 20260301);

      final rebuilt = FormatUtils.dateFromYmd(20260301);
      expect(rebuilt.year, 2026);
      expect(rebuilt.month, 3);
      expect(rebuilt.day, 1);
    });
  });

  group('FormatUtils date copy text', () {
    test('exposes input copy that matches the configured date style', () {
      expect(FormatUtils.ymdInputLabel, '日期（YYYY.MM.DD）');
      expect(FormatUtils.ymdInputHint, '例如：2026.02.08');
      expect(
        FormatUtils.ymdInvalidMsg,
        '保存失败：日期格式应为 YYYY.MM.DD（例如 2026.02.08）',
      );
    });
  });
}
