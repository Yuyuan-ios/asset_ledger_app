import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:asset_ledger/features/app_update/domain/version_check_service.dart';
import 'package:asset_ledger/features/app_update/domain/version_gate_decision.dart';
import 'package:asset_ledger/features/app_update/domain/version_policy.dart';
import 'package:asset_ledger/features/app_update/domain/version_policy_cache.dart';
import 'package:asset_ledger/features/app_update/domain/version_policy_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VersionCheckService decision levels', () {
    test('returns forced when current is below minSupportedVersion', () async {
      final service = _service(currentVersion: '0.9.9');

      final decision = await service.check(isColdStart: true);

      expect(decision.level, VersionGateLevel.forced);
      expect(decision.blocksUsage, isTrue);
      expect(decision.updateUrl, 'mimarket://details?id=com.example');
      expect(decision.title, isNull);
      expect(decision.content, isNull);
    });

    test('passes through policy title and content when present', () async {
      final service = _service(
        currentVersion: '0.9.9',
        policyJson: _policyJson(title: '发现新版本', content: '请更新后继续使用。'),
      );

      final decision = await service.check(isColdStart: true);

      expect(decision.level, VersionGateLevel.forced);
      expect(decision.title, '发现新版本');
      expect(decision.content, '请更新后继续使用。');
    });

    test('returns optional at current == min and below latest', () async {
      final service = _service(currentVersion: '1.0.0');

      final decision = await service.check(isColdStart: true);

      expect(decision.level, VersionGateLevel.optional);
      expect(decision.blocksUsage, isFalse);
    });

    test('returns optional between minSupportedVersion and latest', () async {
      final service = _service(currentVersion: '1.2.0');

      final decision = await service.check(isColdStart: true);

      expect(decision.level, VersionGateLevel.optional);
    });

    test('returns none at current == latest', () async {
      final service = _service(currentVersion: '1.4.0');

      final decision = await service.check(isColdStart: true);

      expect(decision.level, VersionGateLevel.none);
      expect(decision.updateUrl, isNull);
    });

    test('returns none above latest', () async {
      final service = _service(currentVersion: '1.4.1');

      final decision = await service.check(isColdStart: true);

      expect(decision.level, VersionGateLevel.none);
    });
  });

  group('VersionCheckService cache and throttle', () {
    test('cold start fetches once and writes cache', () async {
      final source = FakeVersionPolicySource(() => _policyJson());
      final cache = MemoryVersionPolicyCache();
      final service = _service(
        source: source,
        cache: cache,
        currentVersion: '1.2.0',
      );

      final first = await service.check(isColdStart: true);
      final second = await service.check(isColdStart: true);

      expect(first.level, VersionGateLevel.optional);
      expect(second.level, VersionGateLevel.optional);
      expect(source.fetchCount, 1);
      expect(cache.writeCount, 1);
      expect(cache.entry, isNotNull);
    });

    test('non-cold cache hit uses cache and does not fetch', () async {
      final source = FakeVersionPolicySource(
        () => throw const SocketException('should not fetch'),
      );
      final cache = MemoryVersionPolicyCache(
        VersionPolicyCacheEntry(
          policyJson: _policyJson(),
          fetchedAt: _fixedNow.subtract(const Duration(hours: 1)),
        ),
      );
      final service = _service(
        source: source,
        cache: cache,
        currentVersion: '1.2.0',
      );

      final decision = await service.check(isColdStart: false);

      expect(decision.level, VersionGateLevel.optional);
      expect(source.fetchCount, 0);
      expect(cache.readCount, 1);
    });

    test(
      'expired cache on non-cold trigger returns none and does not fetch',
      () async {
        final source = FakeVersionPolicySource(() => _policyJson());
        final cache = MemoryVersionPolicyCache(
          VersionPolicyCacheEntry(
            policyJson: _policyJson(),
            fetchedAt: _fixedNow.subtract(const Duration(hours: 9)),
          ),
        );
        final service = _service(
          source: source,
          cache: cache,
          currentVersion: '1.2.0',
        );

        final decision = await service.check(isColdStart: false);

        expect(decision.level, VersionGateLevel.none);
        expect(source.fetchCount, 0);
      },
    );

    test(
      'cache miss on non-cold trigger returns none and does not fetch',
      () async {
        final source = FakeVersionPolicySource(() => _policyJson());
        final service = _service(source: source, currentVersion: '1.2.0');

        final decision = await service.check(isColdStart: false);

        expect(decision.level, VersionGateLevel.none);
        expect(source.fetchCount, 0);
      },
    );

    test(
      'cold start fetches fresh policy when cached entry is expired',
      () async {
        final source = FakeVersionPolicySource(() => _policyJson());
        final cache = MemoryVersionPolicyCache(
          VersionPolicyCacheEntry(
            policyJson: _policyJson(latestVersion: '1.0.0'),
            fetchedAt: _fixedNow.subtract(const Duration(hours: 9)),
          ),
        );
        final service = _service(
          source: source,
          cache: cache,
          currentVersion: '1.2.0',
        );

        final decision = await service.check(isColdStart: true);

        expect(decision.level, VersionGateLevel.optional);
        expect(source.fetchCount, 1);
        expect(cache.writeCount, 1);
      },
    );
  });

  group('VersionCheckService fail-open', () {
    test('source timeout returns none without throwing', () async {
      final source = FakeVersionPolicySource(
        () => throw TimeoutException('policy timeout'),
      );
      final cache = MemoryVersionPolicyCache();
      final service = _service(
        source: source,
        cache: cache,
        currentVersion: '0.9.9',
      );

      final decision = await service.check(isColdStart: true);

      expect(decision.level, VersionGateLevel.none);
      expect(cache.writeCount, 0);
    });

    test('source network error returns none without throwing', () async {
      final source = FakeVersionPolicySource(
        () => throw const SocketException('offline'),
      );
      final service = _service(source: source, currentVersion: '0.9.9');

      final decision = await service.check(isColdStart: true);

      expect(decision.level, VersionGateLevel.none);
    });

    test('bad JSON returns none and is not cached', () async {
      final source = FakeVersionPolicySource(() => 'not json');
      final cache = MemoryVersionPolicyCache();
      final service = _service(
        source: source,
        cache: cache,
        currentVersion: '0.9.9',
      );

      final decision = await service.check(isColdStart: true);

      expect(decision.level, VersionGateLevel.none);
      expect(cache.writeCount, 0);
    });

    test('missing critical policy fields returns none', () async {
      final source = FakeVersionPolicySource(
        () => jsonEncode({
          VersionPolicy.platformAndroid: {
            'minSupportedVersion': '1.0.0',
            'updateUrl': 'https://example.com/download',
          },
        }),
      );
      final service = _service(source: source, currentVersion: '0.9.9');

      final decision = await service.check(isColdStart: true);

      expect(decision.level, VersionGateLevel.none);
    });

    test('invalid current version returns none', () async {
      final service = _service(currentVersion: '1.4');

      final decision = await service.check(isColdStart: true);

      expect(decision.level, VersionGateLevel.none);
    });

    test('invalid policy version returns none', () async {
      final service = _service(
        currentVersion: '1.0.0',
        policyJson: _policyJson(latestVersion: 'latest'),
      );

      final decision = await service.check(isColdStart: true);

      expect(decision.level, VersionGateLevel.none);
    });
  });
}

final DateTime _fixedNow = DateTime.utc(2026, 6, 18, 8);

VersionCheckService _service({
  String currentVersion = '1.2.0',
  String? policyJson,
  FakeVersionPolicySource? source,
  MemoryVersionPolicyCache? cache,
}) {
  return VersionCheckService(
    source:
        source ?? FakeVersionPolicySource(() => policyJson ?? _policyJson()),
    cache: cache ?? MemoryVersionPolicyCache(),
    currentVersionProvider: () async => currentVersion,
    platform: VersionPolicy.platformAndroid,
    channel: VersionPolicy.channelXiaomi,
    now: () => _fixedNow,
  );
}

String _policyJson({
  String latestVersion = '1.4.0',
  String minSupportedVersion = '1.0.0',
  String? title,
  String? content,
}) {
  final androidPolicy = <String, Object>{
    'latestVersion': latestVersion,
    'minSupportedVersion': minSupportedVersion,
    'updateUrl': 'https://example.com/download',
    'channelUrls': {
      VersionPolicy.channelXiaomi: 'mimarket://details?id=com.example',
      VersionPolicy.channelOfficial: 'https://example.com/download',
    },
  };
  if (title != null) {
    androidPolicy['title'] = title;
  }
  if (content != null) {
    androidPolicy['content'] = content;
  }

  return jsonEncode({
    VersionPolicy.platformIos: {
      'latestVersion': latestVersion,
      'minSupportedVersion': minSupportedVersion,
      'updateUrl': 'itms-apps://apps.apple.com/app/idXXXXXXXX',
    },
    VersionPolicy.platformAndroid: androidPolicy,
  });
}

class FakeVersionPolicySource implements VersionPolicySource {
  FakeVersionPolicySource(this._fetch);

  final FutureOr<String> Function() _fetch;
  int fetchCount = 0;

  @override
  Future<String> fetchPolicyJson() async {
    fetchCount += 1;
    return _fetch();
  }
}

class MemoryVersionPolicyCache implements VersionPolicyCache {
  MemoryVersionPolicyCache([this.entry]);

  VersionPolicyCacheEntry? entry;
  int readCount = 0;
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<VersionPolicyCacheEntry?> read() async {
    readCount += 1;
    return entry;
  }

  @override
  Future<void> write(VersionPolicyCacheEntry entry) async {
    writeCount += 1;
    this.entry = entry;
  }

  @override
  Future<void> clear() async {
    clearCount += 1;
    entry = null;
  }
}
