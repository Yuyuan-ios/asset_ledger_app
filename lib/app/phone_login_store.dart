import 'package:shared_preferences/shared_preferences.dart';

class PhoneLoginSession {
  const PhoneLoginSession({
    required this.loggedIn,
    required this.privacyAccepted,
    this.phoneNumber,
    this.authToken,
    this.tokenExpiresAt,
  });

  final bool loggedIn;
  final bool privacyAccepted;
  final String? phoneNumber;
  final String? authToken;
  final int? tokenExpiresAt;
}

abstract class PhoneLoginStore {
  Future<PhoneLoginSession> read();

  Future<void> save(PhoneLoginSession session);
}

class SharedPreferencesPhoneLoginStore implements PhoneLoginStore {
  const SharedPreferencesPhoneLoginStore();

  static const String loggedInKey = 'app.phoneLogin.loggedIn.v1';
  static const String phoneNumberKey = 'app.phoneLogin.phoneNumber.v1';
  static const String authTokenKey = 'app.phoneLogin.authToken.v1';
  static const String tokenExpiresAtKey = 'app.phoneLogin.tokenExpiresAt.v1';
  static const String privacyAcceptedKey = 'app.privacyNotice.acknowledged.v1';

  @override
  Future<PhoneLoginSession> read() async {
    final prefs = await SharedPreferences.getInstance();
    final phoneNumber = prefs.getString(phoneNumberKey);
    final authToken = prefs.getString(authTokenKey);
    final tokenExpiresAt = prefs.getInt(tokenExpiresAtKey);
    final loggedIn = prefs.getBool(loggedInKey) ?? false;
    final privacyAccepted = prefs.getBool(privacyAcceptedKey) ?? false;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final tokenValid =
        authToken != null &&
        authToken.isNotEmpty &&
        (tokenExpiresAt == null || tokenExpiresAt > nowSeconds);

    return PhoneLoginSession(
      loggedIn:
          loggedIn &&
          phoneNumber != null &&
          phoneNumber.isNotEmpty &&
          tokenValid,
      privacyAccepted: privacyAccepted,
      phoneNumber: phoneNumber,
      authToken: authToken,
      tokenExpiresAt: tokenExpiresAt,
    );
  }

  @override
  Future<void> save(PhoneLoginSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(loggedInKey, session.loggedIn);
    await prefs.setBool(privacyAcceptedKey, session.privacyAccepted);
    final phoneNumber = session.phoneNumber;
    if (phoneNumber == null || phoneNumber.isEmpty) {
      await prefs.remove(phoneNumberKey);
      await prefs.remove(authTokenKey);
      await prefs.remove(tokenExpiresAtKey);
    } else {
      await prefs.setString(phoneNumberKey, phoneNumber);
      final authToken = session.authToken;
      if (authToken == null || authToken.isEmpty) {
        await prefs.remove(authTokenKey);
      } else {
        await prefs.setString(authTokenKey, authToken);
      }
      final tokenExpiresAt = session.tokenExpiresAt;
      if (tokenExpiresAt == null) {
        await prefs.remove(tokenExpiresAtKey);
      } else {
        await prefs.setInt(tokenExpiresAtKey, tokenExpiresAt);
      }
    }
  }
}
