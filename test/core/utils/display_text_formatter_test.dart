import 'package:asset_ledger/core/utils/display_text_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DisplayTextFormatter', () {
    test('joins non-empty parts with the shared display separator', () {
      expect(
        DisplayTextFormatter.joinParts(['何小波', '2026.05.21']),
        '何小波 · 2026.05.21',
      );
    });

    test('trims and skips empty parts without dangling separators', () {
      expect(
        DisplayTextFormatter.joinParts([' 何小波 ', '', null, ' 2026.05.21 ']),
        '何小波 · 2026.05.21',
      );
    });

    test('uses fallback when all parts are empty', () {
      expect(
        DisplayTextFormatter.joinParts([' ', null], fallback: '未命名'),
        '未命名',
      );
    });
  });
}
