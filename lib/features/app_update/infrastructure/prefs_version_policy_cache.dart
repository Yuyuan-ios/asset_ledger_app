import 'package:shared_preferences/shared_preferences.dart';

import '../domain/version_policy_cache.dart';

class SharedPreferencesVersionPolicyCache implements VersionPolicyCache {
  static const String _policyJsonKey = 'app_update.version_policy_json';
  static const String _fetchedAtKey = 'app_update.version_policy_fetched_at';

  const SharedPreferencesVersionPolicyCache();

  @override
  Future<VersionPolicyCacheEntry?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final policyJson = prefs.getString(_policyJsonKey);
    final fetchedAtRaw = prefs.getString(_fetchedAtKey);
    if (policyJson == null || fetchedAtRaw == null) return null;

    final fetchedAt = DateTime.tryParse(fetchedAtRaw);
    if (fetchedAt == null) return null;

    return VersionPolicyCacheEntry(
      policyJson: policyJson,
      fetchedAt: fetchedAt,
    );
  }

  @override
  Future<void> write(VersionPolicyCacheEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_policyJsonKey, entry.policyJson);
    await prefs.setString(_fetchedAtKey, entry.fetchedAt.toIso8601String());
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_policyJsonKey);
    await prefs.remove(_fetchedAtKey);
  }
}
