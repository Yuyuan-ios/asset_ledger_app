import 'dart:convert';

import 'package:asset_ledger/app/phone_login_store.dart';
import 'package:asset_ledger/app/providers/sync_providers.dart';
import 'package:asset_ledger/app/sync_production_caller.dart';
import 'package:asset_ledger/app/sync_runtime.dart';
import 'package:asset_ledger/app/sync_transport_config.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/infrastructure/cloud/api_client.dart';
import 'package:asset_ledger/infrastructure/sync/sync_device_registration.dart';
import 'package:asset_ledger/infrastructure/sync/sync_live_readiness_gate.dart';
import 'package:asset_ledger/infrastructure/sync/sync_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../support/fake_cloud_api_client.dart';
import '../../test_setup.dart';

typedef _CapturedUpgrade = ({String? updateUrl, String? title, String? content});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.resetForTest();
    AppDatabase.debugInitDbOverride = () {
      return openDatabase(
        inMemoryDatabasePath,
        version: AppDatabase.schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, _) => DbSchema.create(db),
      );
    };
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

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
            Future<String?> Function()? appVersionProvider,
            String? platform,
            UpgradeRequiredCallback? onUpgradeRequired,
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
    expect(providers.caller, isA<SyncProductionCaller>());
    final result = await providers.caller.runOnce();
    expect(result.status, SyncProductionCallStatus.unavailable);
    expect(result.status, isNot(SyncProductionCallStatus.blocked));
    expect(result.reason, 'sync unavailable');

    late SyncRuntime runtime;
    late SyncProductionCaller caller;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MultiProvider(
          providers: providers.providers,
          child: Builder(
            builder: (context) {
              runtime = context.read<SyncRuntime>();
              caller = context.read<SyncProductionCaller>();
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(identical(runtime, providers.runtime), isTrue);
    expect(identical(caller, providers.caller), isTrue);
    expect(runtime.isUnavailable, isTrue);
  });

  test('available sync config wires client manager and registrar', () async {
    late String capturedBaseUrl;
    late Future<String?> Function() capturedTokenProvider;
    Future<String?> Function()? capturedAppVersionProvider;
    String? capturedPlatform;
    UpgradeRequiredCallback? capturedUpgradeSink;
    final signaled = <_CapturedUpgrade>[];
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
            Future<String?> Function()? appVersionProvider,
            String? platform,
            UpgradeRequiredCallback? onUpgradeRequired,
          }) {
            capturedBaseUrl = baseUrl;
            capturedTokenProvider = accessTokenProvider;
            capturedAppVersionProvider = appVersionProvider;
            capturedPlatform = platform;
            capturedUpgradeSink = onUpgradeRequired;
            return client;
          },
      registrationStore: InMemorySyncDeviceRegistrationStore(),
      liveReadinessGate: const StaticSyncLiveReadinessGate.readyForTest(),
      deviceIdProvider: () => 'device-1',
      onUpgradeRequired: ({updateUrl, title, content}) => signaled.add(
        (updateUrl: updateUrl, title: title, content: content),
      ),
    );

    expect(providers.runtime.isAvailable, isTrue);
    expect(providers.runtime.baseUrl, 'https://sync.example.com');
    expect(providers.runtime.syncManager, isA<SyncManager>());
    expect(providers.runtime.deviceRegistrar, isA<SyncDeviceRegistrar>());
    expect(providers.caller, isA<SyncProductionCaller>());
    expect(capturedBaseUrl, 'https://sync.example.com');
    expect(await capturedTokenProvider(), 'token-1');
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

    final registration = await providers.runtime.registerDeviceIfNeeded();
    expect(registration.status, SyncDeviceRegistrationStatus.registered);
    expect(client.receivedRequests.single.method, 'POST');
    expect(client.receivedRequests.single.path, '/sync/devices');
    expect(client.receivedRequests.single.bodyJson, isNot(contains('account')));
  });

  test(
    'available sync config derives a ready live gate from transport config',
    () async {
      final client = FakeCloudApiClient()
        ..enqueueResponse(const ApiResponse(statusCode: 200))
        ..enqueueResponse(
          ApiResponse(
            statusCode: 200,
            bodyJson: jsonEncode({'changes': const [], 'next_cursor': 0}),
          ),
        );

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
              Future<String?> Function()? appVersionProvider,
              String? platform,
              UpgradeRequiredCallback? onUpgradeRequired,
            }) {
              return client;
            },
        registrationStore: InMemorySyncDeviceRegistrationStore(),
        deviceIdProvider: () => 'device-1',
      );

      final result = await providers.caller.runOnce();

      expect(result.status, SyncProductionCallStatus.completed);
      expect(result.status, isNot(SyncProductionCallStatus.blocked));
      expect(
        result.reason ?? '',
        isNot(contains('real-cloud-transport-not-configured')),
      );
      expect(result.pullResult?.applied, 0);
      expect(result.pushResult?.pushed, 0);
      expect(client.receivedRequests.map((request) => request.path), [
        '/sync/devices',
        '/sync/changes?since=0&limit=50',
      ]);
    },
  );
}

class _StaticPhoneLoginStore implements PhoneLoginStore {
  const _StaticPhoneLoginStore(this.session);

  final PhoneLoginSession session;

  @override
  Future<PhoneLoginSession> read() async => session;

  @override
  Future<void> save(PhoneLoginSession session) async {}
}
