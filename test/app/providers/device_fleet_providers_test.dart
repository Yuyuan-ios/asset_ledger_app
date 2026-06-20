import 'package:asset_ledger/app/cloud_backup_config.dart';
import 'package:asset_ledger/app/providers/device_fleet_providers.dart';
import 'package:asset_ledger/infrastructure/cloud/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_cloud_api_client.dart';

typedef _CapturedUpgrade = ({String? updateUrl, String? title, String? content});

void main() {
  test('available cloud backup wires version metadata and upgrade sink', () {
    late String capturedBaseUrl;
    late Future<String?> Function() capturedAccessTokenProvider;
    Future<String?> Function()? capturedAppVersionProvider;
    String? capturedPlatform;
    UpgradeRequiredCallback? capturedUpgradeSink;
    final signaled = <_CapturedUpgrade>[];

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
            capturedBaseUrl = baseUrl;
            capturedAccessTokenProvider = accessTokenProvider;
            capturedAppVersionProvider = appVersionProvider;
            capturedPlatform = platform;
            capturedUpgradeSink = onUpgradeRequired;
            return FakeCloudApiClient();
          },
      onUpgradeRequired: ({updateUrl, title, content}) => signaled.add(
        (updateUrl: updateUrl, title: title, content: content),
      ),
    );

    expect(providers.cloudBackupController.isAvailable, isTrue);
    expect(capturedBaseUrl, 'https://backup.example.com');
    expect(capturedAccessTokenProvider, isNotNull);
    expect(capturedAppVersionProvider, isNotNull);
    expect(capturedPlatform, anyOf('android', 'ios'));

    capturedUpgradeSink!(
      updateUrl: 'https://example.com/download',
      title: '发现新版本',
      content: '请更新后继续使用。',
    );
    expect(signaled, [
      (
        updateUrl: 'https://example.com/download',
        title: '发现新版本',
        content: '请更新后继续使用。',
      ),
    ]);
  });
}
