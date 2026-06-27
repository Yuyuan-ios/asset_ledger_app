import 'package:shared_preferences/shared_preferences.dart';

typedef SubscriptionLoginTokenProvider = Future<String?> Function();

class SharedPreferencesSubscriptionLoginTokenProvider {
  const SharedPreferencesSubscriptionLoginTokenProvider();

  static const String loggedInKey = 'app.phoneLogin.loggedIn.v1';
  static const String authTokenKey = 'app.phoneLogin.authToken.v1';
  static const String phoneNumberKey = 'app.phoneLogin.phoneNumber.v1';
  static const String tokenExpiresAtKey = 'app.phoneLogin.tokenExpiresAt.v1';

  Future<String?> call() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(loggedInKey) ?? false;
    final phoneNumber = prefs.getString(phoneNumberKey);
    final authToken = prefs.getString(authTokenKey);
    final tokenExpiresAt = prefs.getInt(tokenExpiresAtKey);
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final tokenValid =
        authToken != null &&
        authToken.isNotEmpty &&
        (tokenExpiresAt == null || tokenExpiresAt > nowSeconds);
    final authenticated =
        loggedIn && phoneNumber != null && phoneNumber.isNotEmpty && tokenValid;
    if (!authenticated) return null;
    return authToken;
  }
}
