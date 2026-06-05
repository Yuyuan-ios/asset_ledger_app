import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/infrastructure/cloud/api_client.dart';
import 'package:asset_ledger/infrastructure/sync/sync_manager.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_state_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

/// R5.24 Task B: production composition must not silently fall back to a no-op
/// cloud client.
///
/// There is no real CloudApiClient and no production composition wiring
/// `SyncManager` yet. These tests lock in the two invariants that keep the gap
/// safe until R6 wires a real client:
///   1. `lib/` production code never constructs `NoOpCloudApiClient` — it is a
///      dry-run/test double only. The only way push can run is by explicitly
///      injecting a client.
///   2. A dry-run composition must opt in explicitly via
///      `NoOpCloudApiClient(enableDryRun: true)`, and even then `SyncManager`
///      reaches the injected client rather than returning a fake success
///      without a client.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  test('lib/ production code does not instantiate NoOpCloudApiClient', () {
    // The class declaration + its own constructor live here; this file is the
    // definition, not a construction site, so it is excluded from the scan.
    final declaringFile = p
        .join('lib', 'infrastructure', 'cloud', 'api_client.dart')
        .replaceAll('\\', '/');

    final libDir = Directory(p.join(_repoRoot, 'lib'));
    final offenders = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = p.relative(entity.path, from: _repoRoot).replaceAll(
        '\\',
        '/',
      );
      if (relative == declaringFile) continue;
      final source = entity.readAsStringSync();
      // Construction site outside the declaring file = silent no-op injection.
      if (source.contains('NoOpCloudApiClient(')) {
        offenders.add(relative);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'NoOpCloudApiClient is a dry-run/test double. Production code under '
          'lib/ must inject a real CloudApiClient, never construct the no-op '
          'client. Offending files:\n${offenders.join('\n')}',
    );
  });

  test('SyncManager has no default CloudApiClient (apiClient is required)', () {
    // Compile-time fact made explicit: omitting apiClient does not compile, so
    // there is no silent no-op default. We assert the source declares it
    // `required` to lock the contract against future relaxation.
    final source = File(
      p.join(_repoRoot, 'lib', 'infrastructure', 'sync', 'sync_manager.dart'),
    ).readAsStringSync();
    expect(
      source,
      contains('required CloudApiClient apiClient'),
      reason:
          'SyncManager.apiClient must stay required so it can never silently '
          'default to a no-op client.',
    );
  });

  test(
    'pushPending only "succeeds" by actually reaching the injected client '
    '(no silent success without a client)',
    () async {
      await _withInMemoryDb(() async {
        // Explicit dry-run opt-in is the only sanctioned no-op path. We wrap it
        // in a counting spy to prove the push genuinely delegates to the
        // injected client rather than short-circuiting to a fake success.
        final dryRunClient = NoOpCloudApiClient(enableDryRun: true);
        final spy = _CountingCloudApiClient(dryRunClient);
        const outbox = LocalSyncOutboxRepository();
        await outbox.enqueue(
          entityType: 'timing_record',
          entityId: 'dry-run-1',
          operation: 'create',
          payload: const {'amount_fen': 1},
        );

        final manager = SyncManager(
          outboxRepository: outbox,
          apiClient: spy,
          syncStateRepository: const LocalSyncStateRepository(),
        );

        final result = await manager.pushPending();
        // The single pending row was sent through the injected client exactly
        // once. pushPending never reports progress without invoking the client.
        expect(
          spy.sendCallCount,
          1,
          reason: 'pushPending must delegate each pending row to the client',
        );
        expect(
          result.pushed,
          spy.sendCallCount,
          reason:
              'every counted push corresponds to a real client send; there is '
              'no path that reports success without reaching the client',
        );
      });
    },
  );
}

class _CountingCloudApiClient implements CloudApiClient {
  _CountingCloudApiClient(this._delegate);

  final CloudApiClient _delegate;
  int sendCallCount = 0;

  @override
  Future<ApiResponse> send(ApiRequest request) {
    sendCallCount += 1;
    return _delegate.send(request);
  }
}

Future<void> _withInMemoryDb(Future<void> Function() body) async {
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
  try {
    await body();
  } finally {
    await AppDatabase.resetForTest();
  }
}

String get _repoRoot {
  final fromCwd = Directory.current.path;
  if (File(p.join(fromCwd, 'pubspec.yaml')).existsSync() &&
      Directory(p.join(fromCwd, 'lib')).existsSync()) {
    return fromCwd;
  }
  final scriptDir = File(Platform.script.toFilePath()).parent;
  return p.normalize(p.join(scriptDir.path, '..', '..', '..'));
}
