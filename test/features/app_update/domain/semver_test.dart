import 'package:asset_ledger/features/app_update/domain/semver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SemverVersion', () {
    test('compares equal, greater, and lower versions numerically', () {
      expect(SemverVersion.compareStrings('1.4.0', '1.4.0'), 0);
      expect(SemverVersion.compareStrings('1.4.1', '1.4.0'), 1);
      expect(SemverVersion.compareStrings('1.3.9', '1.4.0'), -1);
      expect(SemverVersion.compareStrings('2.0.0', '10.0.0'), -1);
    });

    test('rejects missing version segments', () {
      expect(SemverVersion.tryParse('1.4'), isNull);
      expect(SemverVersion.tryParse('1'), isNull);
      expect(SemverVersion.compareStrings('1.4', '1.4.0'), isNull);
    });

    test('ignores build metadata and prerelease segments', () {
      expect(
        SemverVersion.tryParse('1.4.0+12'),
        const SemverVersion(major: 1, minor: 4, patch: 0),
      );
      expect(SemverVersion.compareStrings('1.4.0+12', '1.4.0+1'), 0);
      expect(SemverVersion.compareStrings('1.4.0-beta+12', '1.4.0'), 0);
    });

    test('rejects invalid strings', () {
      expect(SemverVersion.tryParse('latest'), isNull);
      expect(SemverVersion.tryParse('1.two.0'), isNull);
      expect(SemverVersion.tryParse('1.4.'), isNull);
      expect(SemverVersion.tryParse(''), isNull);
    });
  });
}
