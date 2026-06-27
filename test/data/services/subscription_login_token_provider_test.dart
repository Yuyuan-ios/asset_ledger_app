import 'package:asset_ledger/data/services/subscription_login_token_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPreferencesSubscriptionLoginTokenProvider', () {
    test(
      'returns auth token for an authenticated unexpired login session',
      () async {
        final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        SharedPreferences.setMockInitialValues({
          SharedPreferencesSubscriptionLoginTokenProvider.loggedInKey: true,
          SharedPreferencesSubscriptionLoginTokenProvider.phoneNumberKey:
              '13800138000',
          SharedPreferencesSubscriptionLoginTokenProvider.authTokenKey:
              'login-token',
          SharedPreferencesSubscriptionLoginTokenProvider.tokenExpiresAtKey:
              nowSeconds + 3600,
        });

        const provider = SharedPreferencesSubscriptionLoginTokenProvider();

        expect(await provider(), 'login-token');
      },
    );

    test(
      'returns null when login token is expired or session is skipped',
      () async {
        final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        const provider = SharedPreferencesSubscriptionLoginTokenProvider();

        SharedPreferences.setMockInitialValues({
          SharedPreferencesSubscriptionLoginTokenProvider.loggedInKey: true,
          SharedPreferencesSubscriptionLoginTokenProvider.phoneNumberKey:
              '13800138000',
          SharedPreferencesSubscriptionLoginTokenProvider.authTokenKey:
              'expired-token',
          SharedPreferencesSubscriptionLoginTokenProvider.tokenExpiresAtKey:
              nowSeconds - 1,
        });
        expect(await provider(), isNull);

        SharedPreferences.setMockInitialValues({
          SharedPreferencesSubscriptionLoginTokenProvider.loggedInKey: false,
          SharedPreferencesSubscriptionLoginTokenProvider.phoneNumberKey:
              '13800138000',
          SharedPreferencesSubscriptionLoginTokenProvider.authTokenKey:
              'skipped-token',
        });
        expect(await provider(), isNull);
      },
    );
  });
}
