import 'package:asset_ledger/data/models/project_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectKey', () {
    test('builds trimmed key and display name', () {
      const key = ProjectKey(contact: ' Alice ', site: ' Yard A ');

      expect(key.key, 'Alice||Yard A');
      expect(key.displayName, 'Alice + Yard A');
      expect(
        ProjectKey.buildKey(contact: ' Alice ', site: ' Yard A '),
        'Alice||Yard A',
      );
    });

    test('fromKey splits the first two parts and tolerates missing site', () {
      final full = ProjectKey.fromKey('Alice||Yard A||ignored');
      final partial = ProjectKey.fromKey('Alice');

      expect(full.contact, 'Alice');
      expect(full.site, 'Yard A');
      expect(partial.contact, 'Alice');
      expect(partial.site, '');
    });
  });
}
