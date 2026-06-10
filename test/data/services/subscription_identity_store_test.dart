import 'package:asset_ledger/data/services/subscription_identity_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPreferencesSubscriptionIdentityStore', () {
    test('creates and reuses a stable appAccountToken', () async {
      SharedPreferences.setMockInitialValues({});
      var generated = 0;
      final store = SharedPreferencesSubscriptionIdentityStore(
        tokenGenerator: () {
          generated++;
          return '00000000-0000-4000-8000-000000000123';
        },
      );

      final first = await store.readOrCreateAppAccountToken();
      final second = await store.readOrCreateAppAccountToken();
      final readOnly = await store.readAppAccountToken();

      expect(first, '00000000-0000-4000-8000-000000000123');
      expect(second, first);
      expect(readOnly, first);
      expect(generated, 1);
    });

    test('generated token is a UUID v4 string', () {
      final token =
          SharedPreferencesSubscriptionIdentityStore.generateAppAccountToken();

      expect(
        token,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });
  });
}
