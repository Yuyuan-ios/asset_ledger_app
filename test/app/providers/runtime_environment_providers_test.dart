import 'package:asset_ledger/app/cloud_backup_config.dart';
import 'package:asset_ledger/app/providers/app_update_providers.dart';
import 'package:asset_ledger/app/providers/device_fleet_providers.dart';
import 'package:asset_ledger/app/providers/sync_providers.dart';
import 'package:asset_ledger/app/sync_transport_config.dart';
import 'package:asset_ledger/app/version_policy_config.dart';
import 'package:asset_ledger/core/config/app_environment.dart';
import 'package:asset_ledger/infrastructure/cloud/api_client.dart';
import 'package:asset_ledger/features/app_update/domain/version_policy_cache.dart';
import 'package:asset_ledger/features/app_update/domain/version_policy_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(RuntimeGate.resetForTest);

  test(
    'sandbox access uses mock sync and does not build real cloud client',
    () {
      RuntimeGate.setAccessModeForTest(RuntimeAccessMode.sandbox);
      var factoryCalls = 0;

      final providers = SyncProviders.build(
        cloudApiClientFactory:
            ({
              required String baseUrl,
              required Future<String?> Function() accessTokenProvider,
              Future<String?> Function()? appVersionProvider,
              String? platform,
              UpgradeRequiredCallback? onUpgradeRequired,
            }) {
              factoryCalls++;
              throw StateError('real client must not be built');
            },
        deviceIdProvider: () => 'sandbox-device',
      );

      expect(providers.runtime.isAvailable, isTrue);
      expect(providers.runtime.baseUrl, 'mock://sandbox-sync');
      expect(factoryCalls, 0);
    },
  );

  test(
    'demo access keeps sync offline and does not build real cloud client',
    () {
      RuntimeGate.setAccessModeForTest(RuntimeAccessMode.demo);
      var factoryCalls = 0;

      final providers = SyncProviders.build(
        cloudApiClientFactory:
            ({
              required String baseUrl,
              required Future<String?> Function() accessTokenProvider,
              Future<String?> Function()? appVersionProvider,
              String? platform,
              UpgradeRequiredCallback? onUpgradeRequired,
            }) {
              factoryCalls++;
              throw StateError('real client must not be built');
            },
        deviceIdProvider: () => 'demo-device',
      );

      expect(providers.runtime.isUnavailable, isTrue);
      expect(providers.runtime.disabledMessage, contains('演示模式'));
      expect(factoryCalls, 0);
    },
  );

  test('sandbox and demo access do not wire real cloud backup clients', () {
    for (final mode in [RuntimeAccessMode.sandbox, RuntimeAccessMode.demo]) {
      RuntimeGate.setAccessModeForTest(mode);
      var factoryCalls = 0;

      final providers = DeviceFleetProviders.build(
        endpointConfig: const CloudBackupEndpointConfig.available(
          baseUrl: 'https://backup.example.com',
          usesBusinessApiFallback: false,
        ),
        cloudApiClientFactory:
            ({
              required String baseUrl,
              required Future<String?> Function() accessTokenProvider,
              Future<String?> Function()? appVersionProvider,
              String? platform,
              UpgradeRequiredCallback? onUpgradeRequired,
            }) {
              factoryCalls++;
              throw StateError('real client must not be built');
            },
      );

      expect(providers.cloudBackupController.isAvailable, isFalse);
      expect(factoryCalls, 0);
    }
  });

  test('sandbox access disables app-update network source construction', () {
    RuntimeGate.setAccessModeForTest(RuntimeAccessMode.sandbox);
    var sourceCalls = 0;

    final providers = AppUpdateProviders.build(
      endpointConfig: VersionPolicyEndpointConfig.available(
        uri: Uri.parse('https://updates.example.com/version-policy.json'),
      ),
      sourceFactory: ({required Uri uri}) {
        sourceCalls++;
        throw StateError('version source must not be built');
      },
    );

    expect(providers.coordinator, isNotNull);
    expect(sourceCalls, 0);
  });

  test('review account sandbox access does not build network clients', () {
    RuntimeGate.resolveAccessForAccount(
      accountIdentifier: 'review@example.com',
      isAuthenticated: true,
      reviewAccessPolicy: const ReviewAccessPolicy(
        enabled: true,
        emails: {'review@example.com'},
      ),
    );
    expect(RuntimeGate.isSandboxAccess, isTrue);

    var syncFactoryCalls = 0;
    var backupFactoryCalls = 0;
    var sourceFactoryCalls = 0;

    SyncProviders.build(
      cloudApiClientFactory:
          ({
            required String baseUrl,
            required Future<String?> Function() accessTokenProvider,
            Future<String?> Function()? appVersionProvider,
            String? platform,
            UpgradeRequiredCallback? onUpgradeRequired,
          }) {
            syncFactoryCalls++;
            throw StateError('real sync client must not be built');
          },
    );
    DeviceFleetProviders.build(
      endpointConfig: const CloudBackupEndpointConfig.available(
        baseUrl: 'https://backup.example.com',
        usesBusinessApiFallback: false,
      ),
      cloudApiClientFactory:
          ({
            required String baseUrl,
            required Future<String?> Function() accessTokenProvider,
            Future<String?> Function()? appVersionProvider,
            String? platform,
            UpgradeRequiredCallback? onUpgradeRequired,
          }) {
            backupFactoryCalls++;
            throw StateError('real backup client must not be built');
          },
    );
    AppUpdateProviders.build(
      endpointConfig: VersionPolicyEndpointConfig.available(
        uri: Uri.parse('https://updates.example.com/version-policy.json'),
      ),
      sourceFactory: ({required Uri uri}) {
        sourceFactoryCalls++;
        throw StateError('version source must not be built');
      },
    );

    expect(syncFactoryCalls, 0);
    expect(backupFactoryCalls, 0);
    expect(sourceFactoryCalls, 0);
  });

  test('production normal access keeps real client construction available', () {
    RuntimeGate.setAccessModeForTest(RuntimeAccessMode.normal);
    var syncFactoryCalls = 0;
    var backupFactoryCalls = 0;
    var sourceFactoryCalls = 0;

    SyncProviders.build(
      endpointConfig: const SyncTransportEndpointConfig.available(
        baseUrl: 'https://sync.example.com',
      ),
      cloudApiClientFactory:
          ({
            required String baseUrl,
            required Future<String?> Function() accessTokenProvider,
            Future<String?> Function()? appVersionProvider,
            String? platform,
            UpgradeRequiredCallback? onUpgradeRequired,
          }) {
            syncFactoryCalls++;
            return _FakeCloudApiClient();
          },
    );
    DeviceFleetProviders.build(
      endpointConfig: const CloudBackupEndpointConfig.available(
        baseUrl: 'https://backup.example.com',
        usesBusinessApiFallback: false,
      ),
      cloudApiClientFactory:
          ({
            required String baseUrl,
            required Future<String?> Function() accessTokenProvider,
            Future<String?> Function()? appVersionProvider,
            String? platform,
            UpgradeRequiredCallback? onUpgradeRequired,
          }) {
            backupFactoryCalls++;
            return _FakeCloudApiClient();
          },
    );
    AppUpdateProviders.build(
      endpointConfig: VersionPolicyEndpointConfig.available(
        uri: Uri.parse('https://updates.example.com/version-policy.json'),
      ),
      sourceFactory: ({required Uri uri}) {
        sourceFactoryCalls++;
        return _FakeVersionPolicySource();
      },
      cacheFactory: () => _FakeVersionPolicyCache(),
    );

    expect(syncFactoryCalls, 1);
    expect(backupFactoryCalls, 1);
    expect(sourceFactoryCalls, 1);
  });
}

class _FakeCloudApiClient implements CloudApiClient {
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    return const ApiResponse(statusCode: 200, bodyJson: '{}');
  }
}

class _FakeVersionPolicySource implements VersionPolicySource {
  @override
  Future<String> fetchPolicyJson() async => '{}';
}

class _FakeVersionPolicyCache implements VersionPolicyCache {
  @override
  Future<void> clear() async {}

  @override
  Future<VersionPolicyCacheEntry?> read() async => null;

  @override
  Future<void> write(VersionPolicyCacheEntry entry) async {}
}
