import 'package:asset_ledger/app/phone_login_store.dart';
import 'package:asset_ledger/app/providers/sync_providers.dart';
import 'package:asset_ledger/app/sync_runtime.dart';
import 'package:asset_ledger/app/sync_transport_config.dart';
import 'package:asset_ledger/infrastructure/sync/sync_device_registration.dart';
import 'package:asset_ledger/infrastructure/sync/sync_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/fake_cloud_api_client.dart';

void main() {
  testWidgets('unavailable sync config does not create a real client', (
    tester,
  ) async {
    var factoryCalls = 0;

    final providers = SyncProviders.build(
      endpointConfig: const SyncTransportEndpointConfig.unavailable(
        'sync unavailable',
      ),
      cloudApiClientFactory:
          ({
            required String baseUrl,
            required Future<String?> Function() accessTokenProvider,
          }) {
            factoryCalls += 1;
            return FakeCloudApiClient();
          },
      deviceIdProvider: () => 'device-1',
    );

    expect(factoryCalls, 0);
    expect(providers.runtime.isUnavailable, isTrue);
    expect(providers.runtime.syncManager, isNull);
    expect(providers.runtime.deviceRegistrar, isNull);

    late SyncRuntime runtime;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MultiProvider(
          providers: providers.providers,
          child: Builder(
            builder: (context) {
              runtime = context.read<SyncRuntime>();
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(identical(runtime, providers.runtime), isTrue);
    expect(runtime.isUnavailable, isTrue);
  });

  test('available sync config wires client manager and registrar', () async {
    late String capturedBaseUrl;
    late Future<String?> Function() capturedTokenProvider;
    final client = FakeCloudApiClient();

    final providers = SyncProviders.build(
      endpointConfig: const SyncTransportEndpointConfig.available(
        baseUrl: 'https://sync.example.com',
      ),
      phoneLoginStore: const _StaticPhoneLoginStore(
        PhoneLoginSession(
          loggedIn: true,
          privacyAccepted: true,
          phoneNumber: '13800000000',
          authToken: 'token-1',
        ),
      ),
      cloudApiClientFactory:
          ({
            required String baseUrl,
            required Future<String?> Function() accessTokenProvider,
          }) {
            capturedBaseUrl = baseUrl;
            capturedTokenProvider = accessTokenProvider;
            return client;
          },
      registrationStore: InMemorySyncDeviceRegistrationStore(),
      deviceIdProvider: () => 'device-1',
    );

    expect(providers.runtime.isAvailable, isTrue);
    expect(providers.runtime.baseUrl, 'https://sync.example.com');
    expect(providers.runtime.syncManager, isA<SyncManager>());
    expect(providers.runtime.deviceRegistrar, isA<SyncDeviceRegistrar>());
    expect(capturedBaseUrl, 'https://sync.example.com');
    expect(await capturedTokenProvider(), 'token-1');

    final registration = await providers.runtime.registerDeviceIfNeeded();
    expect(registration.status, SyncDeviceRegistrationStatus.registered);
    expect(client.receivedRequests.single.method, 'POST');
    expect(client.receivedRequests.single.path, '/sync/devices');
    expect(client.receivedRequests.single.bodyJson, isNot(contains('account')));
  });
}

class _StaticPhoneLoginStore implements PhoneLoginStore {
  const _StaticPhoneLoginStore(this.session);

  final PhoneLoginSession session;

  @override
  Future<PhoneLoginSession> read() async => session;

  @override
  Future<void> save(PhoneLoginSession session) async {}
}
