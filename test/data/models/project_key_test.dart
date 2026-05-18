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

    test('round trips contact and site containing the separator', () {
      final key = ProjectKey.buildKey(contact: '甲方||分公司', site: '一号||二号工地');

      final decoded = ProjectKey.fromKey(key);

      expect(decoded.contact, '甲方||分公司');
      expect(decoded.site, '一号||二号工地');
      expect(key.split('||'), hasLength(2));
    });

    test('round trips values that look like encoded project key parts', () {
      final key = ProjectKey.buildKey(contact: '~b64:甲方', site: '工地');

      final decoded = ProjectKey.fromKey(key);

      expect(decoded.contact, '~b64:甲方');
      expect(decoded.site, '工地');
    });

    test('damaged encoded parts fall back without crashing', () {
      final decoded = ProjectKey.fromKey('~b64:not-valid||工地');

      expect(decoded.contact, '~b64:not-valid');
      expect(decoded.site, '工地');
    });

    test('empty contact and site keep a stable legacy shape', () {
      final key = ProjectKey.buildKey(contact: '', site: '');
      final decoded = ProjectKey.fromKey(key);

      expect(key, '||');
      expect(decoded.contact, '');
      expect(decoded.site, '');
    });
  });
}
