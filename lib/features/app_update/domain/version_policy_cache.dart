class VersionPolicyCacheEntry {
  const VersionPolicyCacheEntry({
    required this.policyJson,
    required this.fetchedAt,
  });

  final String policyJson;
  final DateTime fetchedAt;
}

abstract class VersionPolicyCache {
  Future<VersionPolicyCacheEntry?> read();

  Future<void> write(VersionPolicyCacheEntry entry);

  Future<void> clear();
}
