import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Generates stable app account tokens for App Store subscription verification.
typedef AppAccountTokenGenerator = String Function();

/// Stores the stable identity attached to App Store purchases and entitlement sync.
abstract class SubscriptionIdentityStore {
  /// Returns the stored App Store appAccountToken, creating one if needed.
  Future<String> readOrCreateAppAccountToken();

  /// Returns the stored App Store appAccountToken without creating one.
  Future<String?> readAppAccountToken();

  /// Persists a verified App Store appAccountToken.
  Future<void> writeAppAccountToken(String token);

  /// Clears the stored App Store appAccountToken.
  Future<void> clear();
}

abstract class SubscriptionSecureTokenStore {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> delete();
}

class MethodChannelSubscriptionSecureTokenStore
    implements SubscriptionSecureTokenStore {
  const MethodChannelSubscriptionSecureTokenStore({
    MethodChannel channel = const MethodChannel(
      'com.yuyuan.assetledger/subscription_identity',
    ),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<String?> read() async {
    final token = await _channel.invokeMethod<String>('getAppAccountToken');
    if (token == null || token.trim().isEmpty) return null;
    return token.trim();
  }

  @override
  Future<void> write(String token) async {
    await _channel.invokeMethod<void>('setAppAccountToken', token);
  }

  @override
  Future<void> delete() async {
    await _channel.invokeMethod<void>('deleteAppAccountToken');
  }
}

/// Persistent identity store for App Store subscription requests.
///
/// iOS stores the token in Keychain through a platform channel. Older
/// SharedPreferences values are migrated once and kept only as a fallback when
/// the secure channel is unavailable.
class SharedPreferencesSubscriptionIdentityStore
    implements SubscriptionIdentityStore {
  SharedPreferencesSubscriptionIdentityStore({
    AppAccountTokenGenerator tokenGenerator = generateAppAccountToken,
    SubscriptionSecureTokenStore secureTokenStore =
        const MethodChannelSubscriptionSecureTokenStore(),
  }) : _tokenGenerator = tokenGenerator,
       _secureTokenStore = secureTokenStore;

  static const appAccountTokenKey = 'subscription.appAccountToken';

  final AppAccountTokenGenerator _tokenGenerator;
  final SubscriptionSecureTokenStore _secureTokenStore;

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
    if (await _tryWriteSecureToken(token)) {
      await prefs.remove(appAccountTokenKey);
    } else {
      await prefs.setString(appAccountTokenKey, token);
    }
    return token;
  }

  @override
  Future<String?> readAppAccountToken() async {
    final secureToken = await _tryReadSecureToken();
    if (secureToken != null) return secureToken;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(appAccountTokenKey);
    if (token == null || token.trim().isEmpty) return null;
    final normalized = token.trim();
    if (await _tryWriteSecureToken(normalized)) {
      await prefs.remove(appAccountTokenKey);
    }
    return normalized;
  }

  @override
  Future<void> writeAppAccountToken(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (await _tryWriteSecureToken(normalized)) {
      await prefs.remove(appAccountTokenKey);
    } else {
      await prefs.setString(appAccountTokenKey, normalized);
    }
  }

  @override
  Future<void> clear() async {
    await _tryDeleteSecureToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(appAccountTokenKey);
  }

  Future<String?> _tryReadSecureToken() async {
    try {
      return await _secureTokenStore.read();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<bool> _tryWriteSecureToken(String token) async {
    try {
      await _secureTokenStore.write(token);
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> _tryDeleteSecureToken() async {
    try {
      await _secureTokenStore.delete();
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
