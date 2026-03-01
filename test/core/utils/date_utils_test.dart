import 'package:asset_ledger/core/utils/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDateUtils.isSameYmd', () {
    test('returns true for datetimes on the same calendar day', () {
      final result = AppDateUtils.isSameYmd(
        DateTime(2026, 3, 1, 8, 30),
        DateTime(2026, 3, 1, 23, 59),
      );

      expect(result, isTrue);
    });

    test('returns false when year month or day differs', () {
      expect(
        AppDateUtils.isSameYmd(
          DateTime(2026, 3, 1),
          DateTime(2026, 3, 2),
        ),
        isFalse,
      );
      expect(
        AppDateUtils.isSameYmd(
          DateTime(2026, 3, 1),
          DateTime(2026, 4, 1),
        ),
        isFalse,
      );
      expect(
        AppDateUtils.isSameYmd(
          DateTime(2026, 3, 1),
          DateTime(2025, 3, 1),
        ),
        isFalse,
      );
    });
  });
}
