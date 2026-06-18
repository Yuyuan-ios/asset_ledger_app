import 'semver.dart';
import 'version_gate_decision.dart';
import 'version_policy.dart';
import 'version_policy_cache.dart';
import 'version_policy_source.dart';

typedef CurrentVersionProvider = Future<String> Function();
typedef NowProvider = DateTime Function();

class VersionCheckService {
  VersionCheckService({
    required VersionPolicySource source,
    required VersionPolicyCache cache,
    required CurrentVersionProvider currentVersionProvider,
    required String platform,
    required String channel,
    Duration cacheTtl = defaultCacheTtl,
    NowProvider? now,
  }) : _source = source,
       _cache = cache,
       _currentVersionProvider = currentVersionProvider,
       _platform = platform,
       _channel = channel,
       _cacheTtl = cacheTtl,
       _now = now ?? DateTime.now {
    if (!cacheTtl.isPositive) {
      throw ArgumentError.value(
        cacheTtl,
        'cacheTtl',
        'Version policy cache TTL must be positive.',
      );
    }
  }

  static const Duration defaultCacheTtl = Duration(hours: 8);

  final VersionPolicySource _source;
  final VersionPolicyCache _cache;
  final CurrentVersionProvider _currentVersionProvider;
  final String _platform;
  final String _channel;
  final Duration _cacheTtl;
  final NowProvider _now;

  bool _didAttemptColdStartFetch = false;

  Future<VersionGateDecision> check({required bool isColdStart}) async {
    try {
      if (isColdStart && !_didAttemptColdStartFetch) {
        _didAttemptColdStartFetch = true;
        return await _fetchPolicyAndDecide();
      }

      final cached = await _cache.read();
      if (cached == null || !_isFresh(cached.fetchedAt)) {
        return const VersionGateDecision.none();
      }

      return await _decisionFromJson(cached.policyJson);
    } catch (_) {
      return const VersionGateDecision.none();
    }
  }

  Future<VersionGateDecision> _fetchPolicyAndDecide() async {
    final policyJson = await _source.fetchPolicyJson();
    final policy = VersionPolicy.fromJsonString(
      policyJson,
      platform: _platform,
    );
    if (policy == null) return const VersionGateDecision.none();

    try {
      await _cache.write(
        VersionPolicyCacheEntry(policyJson: policyJson, fetchedAt: _now()),
      );
    } catch (_) {
      // Cache failures must not block a successful live policy decision.
    }

    return await _decisionForPolicy(policy);
  }

  Future<VersionGateDecision> _decisionFromJson(String policyJson) async {
    final policy = VersionPolicy.fromJsonString(
      policyJson,
      platform: _platform,
    );
    if (policy == null) return const VersionGateDecision.none();
    return _decisionForPolicy(policy);
  }

  Future<VersionGateDecision> _decisionForPolicy(VersionPolicy policy) async {
    final current = SemverVersion.tryParse(await _currentVersionProvider());
    final minSupported = SemverVersion.tryParse(policy.minSupportedVersion);
    final latest = SemverVersion.tryParse(policy.latestVersion);
    if (current == null || minSupported == null || latest == null) {
      return const VersionGateDecision.none();
    }

    final details = policy.updateDetailsFor(
      platform: _platform,
      channel: _channel,
    );
    if (current.compareTo(minSupported) < 0) {
      return VersionGateDecision.forced(
        updateUrl: details.updateUrl,
        title: details.title,
        content: details.content,
      );
    }

    if (current.compareTo(latest) < 0) {
      return VersionGateDecision.optional(
        updateUrl: details.updateUrl,
        title: details.title,
        content: details.content,
      );
    }

    return const VersionGateDecision.none();
  }

  bool _isFresh(DateTime fetchedAt) {
    final expiresAt = fetchedAt.add(_cacheTtl);
    final current = _now();
    return current.isBefore(expiresAt) || current.isAtSameMomentAs(expiresAt);
  }
}

extension on Duration {
  bool get isPositive => this > Duration.zero;
}
