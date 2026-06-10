import 'package:asset_ledger/app/phone_login_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const store = SharedPreferencesPhoneLoginStore();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('save authenticated clears skipped flag', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesPhoneLoginStore.skippedKey: true,
    });

    await store.save(
      PhoneLoginSession(
        loggedIn: true,
        privacyAccepted: true,
        loginSkipped: true,
        phoneNumber: '13800138000',
        authToken: 'token',
        tokenExpiresAt: _futureEpochSeconds(),
      ),
    );

    final session = await store.read();

    expect(session.authState, PhoneLoginAuthState.authenticated);
    expect(session.isSkipped, isFalse);
    expect(session.phoneNumber, '13800138000');
    expect(session.authToken, 'token');
  });

  test('save skipped clears phone token and expiry', () async {
    SharedPreferences.setMockInitialValues(_authenticatedPrefs());

    await store.save(const PhoneLoginSession.skipped(privacyAccepted: true));
    final session = await store.read();

    expect(session.authState, PhoneLoginAuthState.skipped);
    expect(session.isAuthenticated, isFalse);
    expect(session.phoneNumber, isNull);
    expect(session.authToken, isNull);
    expect(session.tokenExpiresAt, isNull);
  });

  test('save unauthenticated clears credentials and skipped flag', () async {
    SharedPreferences.setMockInitialValues({
      ..._authenticatedPrefs(),
      SharedPreferencesPhoneLoginStore.skippedKey: true,
    });

    await store.save(
      const PhoneLoginSession.unauthenticated(privacyAccepted: true),
    );
    final session = await store.read();

    expect(session.authState, PhoneLoginAuthState.unauthenticated);
    expect(session.isSkipped, isFalse);
    expect(session.phoneNumber, isNull);
    expect(session.authToken, isNull);
    expect(session.tokenExpiresAt, isNull);
  });

  test(
    'read authenticates when credentials exist and token is valid',
    () async {
      SharedPreferences.setMockInitialValues(_authenticatedPrefs());

      final session = await store.read();

      expect(session.authState, PhoneLoginAuthState.authenticated);
      expect(session.isSkipped, isFalse);
    },
  );

  test('read does not authenticate when token expired', () async {
    SharedPreferences.setMockInitialValues(
      _authenticatedPrefs(tokenExpiresAt: _pastEpochSeconds()),
    );

    final session = await store.read();

    expect(session.authState, PhoneLoginAuthState.unauthenticated);
    expect(session.isAuthenticated, isFalse);
  });

  test('read does not authenticate when phone is missing', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesPhoneLoginStore.loggedInKey: true,
      SharedPreferencesPhoneLoginStore.authTokenKey: 'token',
      SharedPreferencesPhoneLoginStore.tokenExpiresAtKey: _futureEpochSeconds(),
    });

    final session = await store.read();

    expect(session.authState, PhoneLoginAuthState.unauthenticated);
    expect(session.isAuthenticated, isFalse);
  });

  test('read does not authenticate when token is missing', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesPhoneLoginStore.loggedInKey: true,
      SharedPreferencesPhoneLoginStore.phoneNumberKey: '13800138000',
      SharedPreferencesPhoneLoginStore.tokenExpiresAtKey: _futureEpochSeconds(),
    });

    final session = await store.read();

    expect(session.authState, PhoneLoginAuthState.unauthenticated);
    expect(session.isAuthenticated, isFalse);
  });

  test('read keeps skipped when loggedIn has invalid credentials', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesPhoneLoginStore.loggedInKey: true,
      SharedPreferencesPhoneLoginStore.skippedKey: true,
      SharedPreferencesPhoneLoginStore.phoneNumberKey: '13800138000',
      SharedPreferencesPhoneLoginStore.authTokenKey: 'token',
      SharedPreferencesPhoneLoginStore.tokenExpiresAtKey: _pastEpochSeconds(),
    });

    final session = await store.read();

    expect(session.authState, PhoneLoginAuthState.skipped);
    expect(session.isAuthenticated, isFalse);
  });
}

Map<String, Object> _authenticatedPrefs({int? tokenExpiresAt}) {
  return {
    SharedPreferencesPhoneLoginStore.loggedInKey: true,
    SharedPreferencesPhoneLoginStore.skippedKey: false,
    SharedPreferencesPhoneLoginStore.phoneNumberKey: '13800138000',
    SharedPreferencesPhoneLoginStore.authTokenKey: 'token',
    SharedPreferencesPhoneLoginStore.tokenExpiresAtKey:
        tokenExpiresAt ?? _futureEpochSeconds(),
  };
}

int _futureEpochSeconds() {
  return DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
}

int _pastEpochSeconds() {
  return DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600;
}
