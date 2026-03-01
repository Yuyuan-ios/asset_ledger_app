import 'package:asset_ledger/core/utils/extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StringX.isBlank', () {
    test('returns true for empty and whitespace-only strings', () {
      expect(''.isBlank, isTrue);
      expect('   '.isBlank, isTrue);
      expect('\n\t'.isBlank, isTrue);
    });

    test('returns false when the string contains non-whitespace text', () {
      expect(' a '.isBlank, isFalse);
      expect('0'.isBlank, isFalse);
    });
  });
}
