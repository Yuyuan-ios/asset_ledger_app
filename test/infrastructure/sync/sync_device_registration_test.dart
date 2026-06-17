import 'dart:convert';

import 'package:asset_ledger/app/identity/app_identity_service.dart';
import 'package:asset_ledger/app/identity/owner_id_store.dart';
import 'package:asset_ledger/infrastructure/sync/sync_device_registration.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_cloud_api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncDeviceRegistrar', () {
    test(
      'registers current app identity once and omits account fields',
      () async {
        await AppIdentityService.resetForTest(
          store: InMemoryOwnerIdStore(),
          generator: () => 'device-1',
        );
        final client = FakeCloudApiClient();
        final store = InMemorySyncDeviceRegistrationStore();
        final registrar = SyncDeviceRegistrar(
          apiClient: client,
          registrationStore: store,
          deviceIdProvider: () => AppIdentityService.instance.currentDeviceId,
          nameProvider: () => 'Yu iPhone',
        );

        final first = await registrar.registerIfNeeded(syncAvailable: true);
        final second = await registrar.registerIfNeeded(syncAvailable: true);

        expect(first.status, SyncDeviceRegistrationStatus.registered);
        expect(second.status, SyncDeviceRegistrationStatus.alreadyRegistered);
        expect(client.receivedRequests, hasLength(1));
        final request = client.receivedRequests.single;
        expect(request.method, 'POST');
        expect(request.path, '/sync/devices');
        final body = jsonDecode(request.bodyJson!) as Map<String, Object?>;
        expect(body['device_id'], 'device-1');
        expect(body['name'], 'Yu iPhone');
        expect(body.containsKey('account'), isFalse);
        expect(body.containsKey('account_id'), isFalse);
      },
    );

    test(
      'unavailable sync skips registration without touching network',
      () async {
        final client = FakeCloudApiClient();
        final registrar = SyncDeviceRegistrar(
          apiClient: client,
          registrationStore: InMemorySyncDeviceRegistrationStore(),
          deviceIdProvider: () => 'device-1',
        );

        final result = await registrar.registerIfNeeded(syncAvailable: false);

        expect(result.status, SyncDeviceRegistrationStatus.unavailable);
        expect(client.receivedRequests, isEmpty);
      },
    );

    test('failure is tolerated and leaves registration retryable', () async {
      final client = FakeCloudApiClient()
        ..enqueueResponse(
          fakeCloudFailure(
            statusCode: 503,
            code: 'unavailable',
            message: 'sync backend down',
          ),
        );
      final store = InMemorySyncDeviceRegistrationStore();
      final registrar = SyncDeviceRegistrar(
        apiClient: client,
        registrationStore: store,
        deviceIdProvider: () => 'device-1',
      );

      final failed = await registrar.registerIfNeeded(syncAvailable: true);
      final retried = await registrar.registerIfNeeded(syncAvailable: true);

      expect(failed.status, SyncDeviceRegistrationStatus.failed);
      expect(failed.error, contains('sync backend down'));
      expect(retried.status, SyncDeviceRegistrationStatus.registered);
      expect(client.receivedRequests, hasLength(2));
    });

    test('missing device id fails without throwing or sending', () async {
      final client = FakeCloudApiClient();
      final registrar = SyncDeviceRegistrar(
        apiClient: client,
        registrationStore: InMemorySyncDeviceRegistrationStore(),
        deviceIdProvider: () => '  ',
      );

      final result = await registrar.registerIfNeeded(syncAvailable: true);

      expect(result.status, SyncDeviceRegistrationStatus.failed);
      expect(result.error, 'missing_device_id');
      expect(client.receivedRequests, isEmpty);
    });

    test('empty display name falls back to default device name', () async {
      final client = FakeCloudApiClient();
      final registrar = SyncDeviceRegistrar(
        apiClient: client,
        registrationStore: InMemorySyncDeviceRegistrationStore(),
        deviceIdProvider: () => 'device-1',
        nameProvider: () => ' ',
      );

      await registrar.registerIfNeeded(syncAvailable: true);

      final body =
          jsonDecode(client.receivedRequests.single.bodyJson!)
              as Map<String, Object?>;
      expect(body['name'], SyncDeviceRegistrar.defaultDeviceName);
    });
  });
}
