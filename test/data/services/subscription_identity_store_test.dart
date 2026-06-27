import 'package:asset_ledger/data/services/subscription_identity_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPreferencesSubscriptionIdentityStore', () {
    test('creates and reuses a stable appAccountToken', () async {
      SharedPreferences.setMockInitialValues({});
      var generated = 0;
      final secureStore = MemorySecureTokenStore();
      final store = SharedPreferencesSubscriptionIdentityStore(
        secureTokenStore: secureStore,
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
      expect(secureStore.token, first);
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

    test('writes a verified appAccountToken for later reuse', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesSubscriptionIdentityStore.appAccountTokenKey:
            '00000000-0000-4000-8000-000000000123',
      });
      final secureStore = MemorySecureTokenStore();
      final store = SharedPreferencesSubscriptionIdentityStore(
        secureTokenStore: secureStore,
      );

      await store.writeAppAccountToken('00000000-0000-4000-8000-000000000456');

      expect(
        await store.readOrCreateAppAccountToken(),
        '00000000-0000-4000-8000-000000000456',
      );
      expect(secureStore.token, '00000000-0000-4000-8000-000000000456');
    });

    test(
      'migrates legacy SharedPreferences token into secure storage',
      () async {
        SharedPreferences.setMockInitialValues({
          SharedPreferencesSubscriptionIdentityStore.appAccountTokenKey:
              '00000000-0000-4000-8000-000000000789',
        });
        final secureStore = MemorySecureTokenStore();
        final store = SharedPreferencesSubscriptionIdentityStore(
          secureTokenStore: secureStore,
        );

        final token = await store.readOrCreateAppAccountToken();

        expect(token, '00000000-0000-4000-8000-000000000789');
        expect(secureStore.token, token);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(
            SharedPreferencesSubscriptionIdentityStore.appAccountTokenKey,
          ),
          isNull,
        );
      },
    );

    test(
      'falls back to SharedPreferences when secure storage is unavailable',
      () async {
        SharedPreferences.setMockInitialValues({});
        final store = SharedPreferencesSubscriptionIdentityStore(
          secureTokenStore: FailingSecureTokenStore(),
          tokenGenerator: () => '00000000-0000-4000-8000-000000000321',
        );

        final token = await store.readOrCreateAppAccountToken();

        expect(token, '00000000-0000-4000-8000-000000000321');
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(
            SharedPreferencesSubscriptionIdentityStore.appAccountTokenKey,
          ),
          token,
        );
      },
    );
  });
}

class MemorySecureTokenStore implements SubscriptionSecureTokenStore {
  String? token;

  @override
  Future<void> delete() async {
    token = null;
  }

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async {
    this.token = token;
  }
}

class FailingSecureTokenStore implements SubscriptionSecureTokenStore {
  @override
  Future<void> delete() async {
    throw PlatformException(code: 'unavailable');
  }

  @override
  Future<String?> read() async {
    throw PlatformException(code: 'unavailable');
  }

  @override
  Future<void> write(String token) async {
    throw PlatformException(code: 'unavailable');
  }
}
