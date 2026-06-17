import 'dart:convert';

import 'package:asset_ledger/app/sync_production_caller.dart';
import 'package:asset_ledger/app/sync_runtime.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/infrastructure/cloud/api_client.dart';
import 'package:asset_ledger/infrastructure/sync/sync_device_registration.dart';
import 'package:asset_ledger/infrastructure/sync/sync_live_readiness_gate.dart';
import 'package:asset_ledger/infrastructure/sync/sync_manager.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_state_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../support/fake_cloud_api_client.dart';
import '../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
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

  test('unavailable runtime returns no-op result without network', () async {
    final caller = SyncProductionCaller(
      runtime: const SyncRuntime.unavailable('sync unavailable'),
      liveReadinessGate: const StaticSyncLiveReadinessGate.readyForTest(),
    );

    final result = await caller.runOnce();

    expect(result.status, SyncProductionCallStatus.unavailable);
    expect(result.reason, 'sync unavailable');
  });

  test('readiness block short-circuits before registration or pull', () async {
    final client = FakeCloudApiClient();
    final caller = SyncProductionCaller(
      runtime: _runtimeWith(client),
      liveReadinessGate: StaticSyncLiveReadinessGate.blockedForTest(
        hardBlockers: const ['real-cloud-transport-not-configured'],
      ),
    );

    final result = await caller.runOnce();

    expect(result.status, SyncProductionCallStatus.blocked);
    expect(result.reason, contains('real-cloud-transport-not-configured'));
    expect(client.receivedRequests, isEmpty);
  });

  test('ready caller registers device then pulls and live pushes', () async {
    final client = FakeCloudApiClient()
      ..enqueueResponse(const ApiResponse(statusCode: 200))
      ..enqueueResponse(
        ApiResponse(
          statusCode: 200,
          bodyJson: jsonEncode({'changes': const [], 'next_cursor': 0}),
        ),
      );
    final caller = SyncProductionCaller(
      runtime: _runtimeWith(client),
      liveReadinessGate: const StaticSyncLiveReadinessGate.readyForTest(),
    );

    final result = await caller.runOnce(
      trigger: SyncProductionTrigger.foregroundResume,
    );

    expect(result.status, SyncProductionCallStatus.completed);
    expect(result.pullResult?.applied, 0);
    expect(result.pushResult?.pushed, 0);
    expect(client.receivedRequests.map((request) => request.path), [
      '/sync/devices',
      '/sync/changes?since=0&limit=50',
    ]);
  });
}

SyncRuntime _runtimeWith(CloudApiClient client) {
  final manager = SyncManager(
    outboxRepository: const LocalSyncOutboxRepository(),
    apiClient: client,
    syncStateRepository: const LocalSyncStateRepository(),
    liveReadinessGate: const StaticSyncLiveReadinessGate.readyForTest(),
    localDeviceId: 'device-1',
  );
  final registrar = SyncDeviceRegistrar(
    apiClient: client,
    registrationStore: InMemorySyncDeviceRegistrationStore(),
    deviceIdProvider: () => 'device-1',
  );
  return SyncRuntime.available(
    baseUrl: 'https://sync.example.com',
    syncManager: manager,
    deviceRegistrar: registrar,
  );
}
