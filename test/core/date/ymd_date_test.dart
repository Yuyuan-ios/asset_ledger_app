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

  group('YmdDate ordinal days', () {
    test('anchors epoch day at 1970-01-01 and supports negative days', () {
      expect(YmdDate.fromInt(19700101)!.toEpochDay(), 0);
      expect(YmdDate.fromInt(19700102)!.toEpochDay(), 1);
      expect(YmdDate.fromInt(19691231)!.toEpochDay(), -1);
    });

    test('counts calendar days across leap years', () {
      final feb28 = YmdDate.fromInt(20240228)!;
      final mar01 = YmdDate.fromInt(20240301)!;
      final nonLeapFeb28 = YmdDate.fromInt(20230228)!;
      final nonLeapMar01 = YmdDate.fromInt(20230301)!;

      expect(feb28.daysBetween(mar01), 2);
      expect(mar01.daysBetween(feb28), -2);
      expect(nonLeapFeb28.daysBetween(nonLeapMar01), 1);
    });

    test('counts civil days across DST boundaries without time zones', () {
      final beforeDst = YmdDate.fromInt(20260307)!;
      final afterDst = YmdDate.fromInt(20260309)!;

      expect(beforeDst.daysBetween(afterDst), 2);
      expect(afterDst.daysBetween(beforeDst), -2);
    });
  });
}
