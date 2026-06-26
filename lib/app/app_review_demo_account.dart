/// App Review demo account contract.
///
/// This is intentionally narrow: the fixed verification code is accepted only
/// when the phone number normalizes to Apple's review account. It is not a
/// general SMS bypass and does not grant subscription entitlement.
class AppReviewDemoAccount {
  const AppReviewDemoAccount._();

  static const String displayPhoneNumber = '+1 650-555-0100';
  static const String canonicalPhoneNumber = '+16505550100';
  static const String verificationCode = '000000';
  static const String authToken = 'app-review-demo-auth-token-v1';
  static const int tokenExpiresAt = 2000000000;

  static bool isDemoPhone(String phoneNumber) {
    return _digitsOnly(phoneNumber) == '16505550100';
  }

  static bool isSupportedLoginPhone(String phoneNumber) {
    final trimmed = phoneNumber.trim();
    return isDemoPhone(trimmed) || RegExp(r'^1[3-9]\d{9}$').hasMatch(trimmed);
  }

  static String normalizeForLogin(String phoneNumber) {
    final trimmed = phoneNumber.trim();
    if (isDemoPhone(trimmed)) return canonicalPhoneNumber;
    return trimmed;
  }

  static String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }
}
