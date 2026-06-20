import 'package:asset_ledger/app/cloud_backup_config.dart';
import 'package:asset_ledger/app/providers/device_fleet_providers.dart';
import 'package:asset_ledger/features/app_update/domain/version_gate_decision.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_cloud_api_client.dart';

void main() {
  test('available cloud backup wires version metadata and upgrade sink', () {
    late String capturedBaseUrl;
    late Future<String?> Function() capturedAccessTokenProvider;
    Future<String?> Function()? capturedAppVersionProvider;
    String? capturedPlatform;
    void Function(VersionGateDecision decision)? capturedUpgradeSink;
    final signaled = <VersionGateDecision>[];

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
            void Function(VersionGateDecision decision)? onUpgradeRequired,
          }) {
            capturedBaseUrl = baseUrl;
            capturedAccessTokenProvider = accessTokenProvider;
            capturedAppVersionProvider = appVersionProvider;
            capturedPlatform = platform;
            capturedUpgradeSink = onUpgradeRequired;
            return FakeCloudApiClient();
          },
      onUpgradeRequired: signaled.add,
    );

    expect(providers.cloudBackupController.isAvailable, isTrue);
    expect(capturedBaseUrl, 'https://backup.example.com');
    expect(capturedAccessTokenProvider, isNotNull);
    expect(capturedAppVersionProvider, isNotNull);
    expect(capturedPlatform, anyOf('android', 'ios'));

    final decision = _forcedDecision();
    capturedUpgradeSink!(decision);
    expect(signaled, [decision]);
  });
}

VersionGateDecision _forcedDecision() {
  return const VersionGateDecision.forced(
    updateUrl: 'https://example.com/download',
    title: '发现新版本',
    content: '请更新后继续使用。',
  );
}
