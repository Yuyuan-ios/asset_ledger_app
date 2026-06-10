import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Generates stable app account tokens for App Store subscription verification.
typedef AppAccountTokenGenerator = String Function();

/// Stores the stable identity attached to App Store purchases and entitlement sync.
abstract class SubscriptionIdentityStore {
  /// Returns the stored App Store appAccountToken, creating one if needed.
  Future<String> readOrCreateAppAccountToken();

  /// Returns the stored App Store appAccountToken without creating one.
  Future<String?> readAppAccountToken();

  /// Clears the stored App Store appAccountToken.
  Future<void> clear();
}

/// SharedPreferences-backed identity store for App Store subscription requests.
class SharedPreferencesSubscriptionIdentityStore
    implements SubscriptionIdentityStore {
  SharedPreferencesSubscriptionIdentityStore({
    AppAccountTokenGenerator tokenGenerator = generateAppAccountToken,
  }) : _tokenGenerator = tokenGenerator;

  static const _appAccountTokenKey = 'subscription.appAccountToken';

  final AppAccountTokenGenerator _tokenGenerator;

  /// Generates a UUID v4 token accepted by StoreKit as `appAccountToken`.
  static String generateAppAccountToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hexByte(int value) => value.toRadixString(16).padLeft(2, '0');
    final hex = bytes.map(hexByte).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  @override
  Future<String> readOrCreateAppAccountToken() async {
    final existing = await readAppAccountToken();
    if (existing != null) return existing;

    final token = _tokenGenerator();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appAccountTokenKey, token);
    return token;
  }

  @override
  Future<String?> readAppAccountToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_appAccountTokenKey);
    if (token == null || token.trim().isEmpty) return null;
    return token;
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_appAccountTokenKey);
  }
}
