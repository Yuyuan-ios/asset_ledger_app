import 'package:shared_preferences/shared_preferences.dart';

import 'subscription_verification_repository.dart';

class SubscriptionEntitlementCacheEntry {
  const SubscriptionEntitlementCacheEntry({
    required this.outcome,
    this.productId,
    this.expiryDate,
    required this.lastSyncedAt,
  });

  final SubscriptionVerificationOutcome outcome;
  final String? productId;
  final DateTime? expiryDate;
  final DateTime lastSyncedAt;

  factory SubscriptionEntitlementCacheEntry.fromVerified(
    VerifiedEntitlement entitlement,
  ) {
    return SubscriptionEntitlementCacheEntry(
      outcome: entitlement.outcome,
      productId: entitlement.productId,
      expiryDate: entitlement.expiryDate,
      lastSyncedAt: entitlement.lastSyncedAt,
    );
  }
}

abstract class SubscriptionEntitlementCache {
  Future<SubscriptionEntitlementCacheEntry?> read();

  Future<void> write(SubscriptionEntitlementCacheEntry entry);

  Future<void> clear();
}

class SharedPreferencesSubscriptionEntitlementCache
    implements SubscriptionEntitlementCache {
  static const _statusKey = 'subscription.lastVerifiedStatus';
  static const _productIdKey = 'subscription.productId';
  static const _expiryDateKey = 'subscription.expiryDate';
  static const _lastSyncedAtKey = 'subscription.lastSyncedAt';

  const SharedPreferencesSubscriptionEntitlementCache();

  @override
  Future<SubscriptionEntitlementCacheEntry?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final outcomeName = prefs.getString(_statusKey);
    final lastSyncedAtRaw = prefs.getString(_lastSyncedAtKey);
    if (outcomeName == null || lastSyncedAtRaw == null) return null;

    final outcome = _outcomeFromName(outcomeName);
    final lastSyncedAt = DateTime.tryParse(lastSyncedAtRaw);
    if (outcome == null || lastSyncedAt == null) return null;

    final expiryDateRaw = prefs.getString(_expiryDateKey);
    return SubscriptionEntitlementCacheEntry(
      outcome: outcome,
      productId: prefs.getString(_productIdKey),
      expiryDate: expiryDateRaw == null
          ? null
          : DateTime.tryParse(expiryDateRaw),
      lastSyncedAt: lastSyncedAt,
    );
  }

  @override
  Future<void> write(SubscriptionEntitlementCacheEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statusKey, entry.outcome.name);
    await prefs.setString(
      _lastSyncedAtKey,
      entry.lastSyncedAt.toIso8601String(),
    );

    final productId = entry.productId;
    if (productId == null || productId.isEmpty) {
      await prefs.remove(_productIdKey);
    } else {
      await prefs.setString(_productIdKey, productId);
    }

    final expiryDate = entry.expiryDate;
    if (expiryDate == null) {
      await prefs.remove(_expiryDateKey);
    } else {
      await prefs.setString(_expiryDateKey, expiryDate.toIso8601String());
    }
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_statusKey);
    await prefs.remove(_productIdKey);
    await prefs.remove(_expiryDateKey);
    await prefs.remove(_lastSyncedAtKey);
  }

  SubscriptionVerificationOutcome? _outcomeFromName(String name) {
    for (final outcome in SubscriptionVerificationOutcome.values) {
      if (outcome.name == name) return outcome;
    }
    return null;
  }
}
