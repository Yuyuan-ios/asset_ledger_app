import 'package:asset_ledger/core/date/ymd_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YmdDate.tryParseStrict', () {
    test('accepts supported fixed-width date formats', () {
      expect(YmdDate.tryParseStrict('20260208')?.value, 20260208);
      expect(YmdDate.tryParseStrict('2026-02-08')?.value, 20260208);
      expect(YmdDate.tryParseStrict('2026.02.08')?.value, 20260208);
      expect(YmdDate.tryParseStrict('2026/02/08')?.value, 20260208);
    });

    test('rejects empty and non fixed-width input', () {
      expect(YmdDate.tryParseStrict(''), isNull);
      expect(YmdDate.tryParseStrict('2026/2/8'), isNull);
      expect(YmdDate.tryParseStrict('2026-2-08'), isNull);
    });

    test('rejects impossible calendar dates', () {
      expect(YmdDate.tryParseStrict('20250231'), isNull);
      expect(YmdDate.tryParseStrict('20241301'), isNull);
      expect(YmdDate.tryParseStrict('20260001'), isNull);
    });

    test('formats compact dashed and dotted output', () {
      final date = YmdDate.fromInt(20260208)!;

      expect(date.compact, '20260208');
      expect(date.dashed, '2026-02-08');
      expect(date.dotted, '2026.02.08');
    });
  });
}
