import 'dart:convert';
import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/services/backup/cloud_backup_service.dart';
import 'package:asset_ledger/infrastructure/cloud/api_client.dart';
import 'package:asset_ledger/infrastructure/cloud/cloud_backup_cipher.dart';
import 'package:asset_ledger/infrastructure/cloud/cloud_backup_gateway.dart';
import 'package:asset_ledger/infrastructure/sync/remote_change.dart';
import 'package:asset_ledger/infrastructure/sync/sync_conflict_repository.dart';
import 'package:asset_ledger/infrastructure/sync/sync_live_readiness_gate.dart';
import 'package:asset_ledger/infrastructure/sync/sync_manager.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_state_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../support/fake_cloud_api_client.dart';
import '../../../test_setup.dart';

/// 云端备份端到端：导出 → 包络上传 → 清库 → 下载校验 → 事务化恢复。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory documentsDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp('cloud_backup_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return documentsDir.path;
          }
          return null;
        });
    await AppDatabase.resetForTest();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await AppDatabase.resetForTest();
    if (await documentsDir.exists()) {
      await documentsDir.delete(recursive: true);
    }
  });

  Future<Database> openDb() async {
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
    return AppDatabase.database;
  }

  Future<void> seedBusinessData(Database db) async {
    await db.insert('projects', {
      'id': 'project:cloud',
      'contact': '甲方',
      'site': '云端工地',
      'status': 'active',
      'created_at': '2026-06-01T00:00:00.000Z',
      'updated_at': '2026-06-01T00:00:00.000Z',
    });
    await db.insert('devices', {
      'id': 1,
      'name': 'SANY 1#',
      'brand': 'sany',
      'default_unit_price_fen': 38000,
      'base_meter_hours': 0.0,
      'is_active': 1,
      'equipment_type': 'excavator',
    });
    await db.insert('timing_records', {
      'id': 1,
      'project_id': 'project:cloud',
      'device_id': 1,
      'start_date': 20260601,
      'contact': '甲方',
      'site': '云端工地',
      'type': 'hours',
      'start_meter': 0.0,
      'end_meter': 7.5,
      'hours': 7.5,
      'income_fen': 0,
      'unit': 'HOUR',
      'quantity_scaled': 7500,
      'exclude_from_fuel_eff': 0,
      'is_breaking': 0,
    });
  }

  SyncManager managerWith(FakeCloudApiClient client) {
    return SyncManager(
      outboxRepository: const LocalSyncOutboxRepository(),
      apiClient: client,
      syncStateRepository: const LocalSyncStateRepository(),
      metaRepository: const LocalEntitySyncMetaRepository(),
      liveReadinessGate: const StaticSyncLiveReadinessGate.readyForTest(),
      now: () => DateTime.utc(2026, 6, 17, 12),
    );
  }

  test('upload then restore round-trips business data', () async {
    final db = await openDb();
    await seedBusinessData(db);

    final gateway = _InMemoryCloudBackupGateway();
    final service = CloudBackupService(gateway: gateway);

    final upload = await service.uploadCurrent();
    expect(upload.success, isTrue, reason: upload.errorMessage ?? '');
    expect(upload.backupId, isNotNull);
    expect(upload.payloadBytes, greaterThan(0));

    final stored = gateway.envelopes[upload.backupId]!;
    expect(stored.formatVersion, CloudBackupEnvelope.supportedFormatVersion);
    expect(stored.dbSchemaVersion, AppDatabase.schemaVersion);
    expect(
      CloudBackupService.payloadSha256(stored.payloadJson),
      stored.payloadSha256,
    );

    // 清库后从云端恢复。
    await db.delete('timing_records');
    await db.delete('devices');
    await db.delete('projects');
    expect(await db.query('timing_records'), isEmpty);

    final result = await service.restoreFromCloud(upload.backupId!);
    expect(result.success, isTrue, reason: result.message);

    final rows = await db.query('timing_records');
    expect(rows, hasLength(1));
    expect(rows.single['unit'], 'HOUR');
    expect(rows.single['quantity_scaled'], 7500);
    final metadata = await service.listRemote();
    expect(metadata.single.backupId, upload.backupId);
  });

  test('upload stamps current pull cursor watermark into envelope', () async {
    final db = await openDb();
    await seedBusinessData(db);
    await const LocalSyncStateRepository().writePullCursor(42);

    final gateway = _InMemoryCloudBackupGateway();
    final service = CloudBackupService(gateway: gateway);

    final upload = await service.uploadCurrent();
    expect(upload.success, isTrue, reason: upload.errorMessage ?? '');

    final stored = gateway.envelopes[upload.backupId]!;
    expect(stored.syncCursorWatermark, 42);
    expect(stored.toJson()['sync_cursor_watermark'], 42);
    expect(
      CloudBackupService.payloadSha256(stored.payloadJson),
      stored.payloadSha256,
      reason: 'watermark is header metadata, not part of the payload hash',
    );
  });

  test(
    'upload stamps zero watermark when pull cursor has never been used',
    () async {
      final db = await openDb();
      await seedBusinessData(db);

      final gateway = _InMemoryCloudBackupGateway();
      final service = CloudBackupService(gateway: gateway);

      final upload = await service.uploadCurrent();
      expect(upload.success, isTrue, reason: upload.errorMessage ?? '');

      expect(gateway.envelopes[upload.backupId]!.syncCursorWatermark, 0);
    },
  );

  test(
    'upload clamps watermark to just before the earliest pending conflict',
    () async {
      final db = await openDb();
      await seedBusinessData(db);
      // 游标已越过 seq=15 的未决冲突(冲突分支也推进游标)。
      await const LocalSyncStateRepository().writePullCursor(20);
      await const LocalSyncConflictRepository().insertIfAbsent(
        SyncConflict.fromRemoteChange(
          change: const RemoteChange(
            serverSeq: 15,
            entityType: 'timing_record',
            entityId: '1',
            baseVersion: 1,
            newVersion: 2,
            payloadJson: '{}',
            payloadHash: 'hash',
            deleted: false,
          ),
          reason: 'payload_hash_mismatch',
          detectedAt: DateTime.utc(2026, 6, 17),
        ),
      );

      final gateway = _InMemoryCloudBackupGateway();
      final upload = await CloudBackupService(gateway: gateway).uploadCurrent();
      expect(upload.success, isTrue, reason: upload.errorMessage ?? '');

      // watermark 收敛到 14,恢复方会从 14 之后重拉并重建 seq=15 的冲突。
      expect(gateway.envelopes[upload.backupId]!.syncCursorWatermark, 14);
    },
  );

  test(
    'restore adopts watermark before pullPending applies only newer changes',
    () async {
      final db = await openDb();
      await seedBusinessData(db);
      await const LocalSyncStateRepository().writePullCursor(10);

      final gateway = _InMemoryCloudBackupGateway();
      final upload = await CloudBackupService(gateway: gateway).uploadCurrent();
      expect(upload.success, isTrue, reason: upload.errorMessage ?? '');

      await AppDatabase.resetForTest();
      final restoredDb = await openDb();

      final restore = await CloudBackupService(
        gateway: gateway,
      ).restoreFromCloud(upload.backupId!);
      expect(restore.success, isTrue, reason: restore.message);
      expect(await const LocalSyncStateRepository().readPullCursor(), 10);
      expect(await restoredDb.query('entity_sync_meta'), isEmpty);

      final client = FakeCloudApiClient()
        ..enqueueResponse(
          _pullResponse([
            _remoteTimingChange(
              serverSeq: 9,
              entityId: 1,
              baseVersion: 0,
              newVersion: 1,
              incomeFen: 99999,
            ),
            _remoteTimingChange(
              serverSeq: 11,
              entityId: 1,
              baseVersion: 1,
              newVersion: 2,
              incomeFen: 12345,
            ),
          ], nextCursor: 11),
        );

      final pull = await managerWith(client).pullPending(limit: 10);

      expect(
        client.receivedRequests.single.path,
        '/sync/changes?since=10&limit=10',
      );
      expect(pull.skippedDuplicate, 1);
      expect(pull.applied, 1);
      expect(await const LocalSyncStateRepository().readPullCursor(), 11);
      final rows = await restoredDb.query('timing_records');
      expect(rows, hasLength(1));
      expect(rows.single['income_fen'], 12345);
    },
  );

  test(
    'legacy envelope without watermark keeps cursor zero before full replay',
    () async {
      final db = await openDb();
      await seedBusinessData(db);
      await const LocalSyncStateRepository().writePullCursor(7);

      final gateway = _InMemoryCloudBackupGateway();
      final upload = await CloudBackupService(gateway: gateway).uploadCurrent();
      expect(upload.success, isTrue, reason: upload.errorMessage ?? '');
      final stored = gateway.envelopes[upload.backupId]!;
      gateway.envelopes['legacy'] = _legacyEnvelopeWithoutWatermark(stored);

      await AppDatabase.resetForTest();
      final restoredDb = await openDb();

      final restore = await CloudBackupService(
        gateway: gateway,
      ).restoreFromCloud('legacy');
      expect(restore.success, isTrue, reason: restore.message);
      expect(await const LocalSyncStateRepository().readPullCursor(), 0);

      final client = FakeCloudApiClient()
        ..enqueueResponse(
          _pullResponse([
            _remoteTimingChange(
              serverSeq: 1,
              entityId: 1,
              baseVersion: 0,
              newVersion: 1,
              incomeFen: 54321,
            ),
          ], nextCursor: 1),
        );

      final pull = await managerWith(client).pullPending(limit: 10);

      expect(
        client.receivedRequests.single.path,
        '/sync/changes?since=0&limit=10',
      );
      expect(pull.applied, 1);
      expect(await const LocalSyncStateRepository().readPullCursor(), 1);
      final rows = await restoredDb.query('timing_records');
      expect(rows, hasLength(1));
      expect(rows.single['income_fen'], 54321);
    },
  );

  test('tampered payload is rejected and database stays untouched', () async {
    final db = await openDb();
    await seedBusinessData(db);

    final gateway = _InMemoryCloudBackupGateway();
    final service = CloudBackupService(gateway: gateway);
    final upload = await service.uploadCurrent();
    expect(upload.success, isTrue);

    // 篡改云端 payload(模拟传输/存储损坏),sha 不再匹配。
    final stored = gateway.envelopes[upload.backupId]!;
    gateway.envelopes[upload.backupId!] = CloudBackupEnvelope(
      formatVersion: stored.formatVersion,
      createdAtIso: stored.createdAtIso,
      dbSchemaVersion: stored.dbSchemaVersion,
      payloadSha256: stored.payloadSha256,
      payloadBytes: stored.payloadBytes,
      payloadJson: '${stored.payloadJson} ',
    );

    final before = await db.query('timing_records');
    final result = await service.restoreFromCloud(upload.backupId!);
    expect(result.success, isFalse);
    expect(result.errorCode, 'payload_hash_mismatch');
    expect(await db.query('timing_records'), before, reason: '失败不得动权威表');
  });

  test(
    'backup from a newer schema version is rejected before restore',
    () async {
      final db = await openDb();
      await seedBusinessData(db);

      final gateway = _InMemoryCloudBackupGateway();
      final uploader = CloudBackupService(
        gateway: gateway,
        currentDbSchemaVersion: AppDatabase.schemaVersion + 1,
      );
      final upload = await uploader.uploadCurrent();
      expect(upload.success, isTrue);

      final restorer = CloudBackupService(gateway: gateway);
      final result = await restorer.restoreFromCloud(upload.backupId!);
      expect(result.success, isFalse);
      expect(result.errorCode, 'newer_schema_version');
    },
  );

  test('gateway failures surface as coded results, not exceptions', () async {
    final db = await openDb();
    await seedBusinessData(db);

    final service = CloudBackupService(gateway: _AlwaysFailGateway());
    final upload = await service.uploadCurrent();
    expect(upload.success, isFalse);
    expect(upload.errorCode, 'http_503');

    final restore = await service.restoreFromCloud('missing');
    expect(restore.success, isFalse);
    expect(restore.errorCode, 'http_503');
  });

  group('client-side encryption', () {
    test(
      'encrypted upload stores ciphertext and round-trips on restore',
      () async {
        final db = await openDb();
        await seedBusinessData(db);

        final gateway = _InMemoryCloudBackupGateway();
        final service = CloudBackupService(
          gateway: gateway,
          keyProvider: const _FixedKeyProvider('account-secret-A'),
        );

        final upload = await service.uploadCurrent();
        expect(upload.success, isTrue, reason: upload.errorMessage ?? '');

        final stored = gateway.envelopes[upload.backupId]!;
        // OSS 只见密文:传输体不含明文业务字段,且标了加密编码 + 元数据。
        expect(stored.isEncrypted, isTrue);
        expect(stored.payloadEncoding, CloudBackupEnvelope.encodingAesGcm);
        expect(stored.encryption, isNotNull);
        expect(stored.payloadJson, isNot(contains('云端工地')));
        expect(stored.payloadJson, isNot(contains('project:cloud')));

        await db.delete('timing_records');
        await db.delete('devices');
        await db.delete('projects');

        final result = await service.restoreFromCloud(upload.backupId!);
        expect(result.success, isTrue, reason: result.message);
        final rows = await db.query('timing_records');
        expect(rows, hasLength(1));
        expect(rows.single['quantity_scaled'], 7500);
      },
    );

    test(
      'restore with a different account is rejected as wrong_account',
      () async {
        final db = await openDb();
        await seedBusinessData(db);

        final gateway = _InMemoryCloudBackupGateway();
        final uploader = CloudBackupService(
          gateway: gateway,
          keyProvider: const _FixedKeyProvider('account-secret-A'),
        );
        final upload = await uploader.uploadCurrent();
        expect(upload.success, isTrue);

        final other = CloudBackupService(
          gateway: gateway,
          keyProvider: const _FixedKeyProvider('account-secret-B'),
        );
        final result = await other.restoreFromCloud(upload.backupId!);
        expect(result.success, isFalse);
        expect(result.errorCode, 'wrong_account');
      },
    );

    test('encrypted backup cannot be restored without a key', () async {
      final db = await openDb();
      await seedBusinessData(db);

      final gateway = _InMemoryCloudBackupGateway();
      final uploader = CloudBackupService(
        gateway: gateway,
        keyProvider: const _FixedKeyProvider('account-secret-A'),
      );
      final upload = await uploader.uploadCurrent();

      final noKey = CloudBackupService(gateway: gateway);
      final result = await noKey.restoreFromCloud(upload.backupId!);
      expect(result.success, isFalse);
      expect(result.errorCode, 'encryption_key_unavailable');
    });

    test(
      'requireEncryption rejects plaintext upload when key unavailable',
      () async {
        final db = await openDb();
        await seedBusinessData(db);

        final gateway = _InMemoryCloudBackupGateway();
        final service = CloudBackupService(
          gateway: gateway,
          keyProvider: const _FixedKeyProvider(null),
          requireEncryption: true,
        );
        final upload = await service.uploadCurrent();
        expect(upload.success, isFalse);
        expect(upload.errorCode, 'encryption_key_unavailable');
        expect(gateway.envelopes, isEmpty, reason: '不得上传明文');
      },
    );

    test(
      'legacy plaintext backups still restore when a key is configured',
      () async {
        final db = await openDb();
        await seedBusinessData(db);

        // 先用无加密服务上传明文包(模拟历史备份)。
        final gateway = _InMemoryCloudBackupGateway();
        final legacy = CloudBackupService(gateway: gateway);
        final upload = await legacy.uploadCurrent();
        expect(gateway.envelopes[upload.backupId]!.isEncrypted, isFalse);

        await db.delete('timing_records');

        // 之后用带密钥的服务恢复:明文包向后兼容。
        final withKey = CloudBackupService(
          gateway: gateway,
          keyProvider: const _FixedKeyProvider('account-secret-A'),
        );
        final result = await withKey.restoreFromCloud(upload.backupId!);
        expect(result.success, isTrue, reason: result.message);
        expect(await db.query('timing_records'), hasLength(1));
      },
    );
  });
}

CloudBackupEnvelope _legacyEnvelopeWithoutWatermark(
  CloudBackupEnvelope source,
) {
  return CloudBackupEnvelope(
    formatVersion: source.formatVersion,
    createdAtIso: source.createdAtIso,
    dbSchemaVersion: source.dbSchemaVersion,
    payloadSha256: source.payloadSha256,
    payloadBytes: source.payloadBytes,
    payloadJson: source.payloadJson,
    payloadEncoding: source.payloadEncoding,
    encryption: source.encryption,
  );
}

Map<String, Object?> _remoteTimingChange({
  required int serverSeq,
  required int entityId,
  required int baseVersion,
  required int newVersion,
  required int incomeFen,
}) {
  final payloadJson = jsonEncode({
    'payload_schema_version': 1,
    'entity_type': 'timing_record',
    'entity_id': entityId.toString(),
    'operation': 'update',
    'record': {
      'id': entityId,
      'project_id': 'project:cloud',
      'device_id': 1,
      'start_date': 20260601,
      'allocation_cutoff_date': null,
      'display_end_date': null,
      'contact': '甲方',
      'site': '云端工地',
      'type': 'hours',
      'start_meter': 0.0,
      'end_meter': 7.5,
      'hours': 7.5,
      'income_fen': incomeFen,
      'unit': 'HOUR',
      'quantity_scaled': 7500,
      'exclude_from_fuel_eff': 0,
      'is_breaking': 0,
    },
  });
  return {
    'server_seq': serverSeq,
    'entity_type': 'timing_record',
    'entity_id': entityId.toString(),
    'base_version': baseVersion,
    'new_version': newVersion,
    'payload_json': payloadJson,
    'payload_hash': sha256.convert(utf8.encode(payloadJson)).toString(),
    'deleted': false,
  };
}

ApiResponse _pullResponse(
  List<Map<String, Object?>> changes, {
  required int nextCursor,
}) {
  return ApiResponse(
    statusCode: 200,
    bodyJson: jsonEncode({'changes': changes, 'next_cursor': nextCursor}),
  );
}

class _FixedKeyProvider implements CloudBackupKeyProvider {
  const _FixedKeyProvider(this._secret);
  final String? _secret;
  @override
  Future<String?> accountSecret() async => _secret;
}

class _InMemoryCloudBackupGateway implements CloudBackupGateway {
  final Map<String, CloudBackupEnvelope> envelopes = {};
  var _nextId = 0;

  @override
  Future<String> upload(CloudBackupEnvelope envelope) async {
    final id = 'backup-${++_nextId}';
    envelopes[id] = envelope;
    return id;
  }

  @override
  Future<List<CloudBackupMetadata>> list() async {
    return [
      for (final entry in envelopes.entries)
        CloudBackupMetadata(
          backupId: entry.key,
          createdAtIso: entry.value.createdAtIso,
          dbSchemaVersion: entry.value.dbSchemaVersion,
          payloadBytes: entry.value.payloadBytes,
        ),
    ];
  }

  @override
  Future<CloudBackupEnvelope> download(String backupId) async {
    final envelope = envelopes[backupId];
    if (envelope == null) {
      throw const CloudBackupGatewayException('not_found', 'backup not found');
    }
    return envelope;
  }
}

class _AlwaysFailGateway implements CloudBackupGateway {
  @override
  Future<String> upload(CloudBackupEnvelope envelope) async {
    throw const CloudBackupGatewayException(
      'http_503',
      'service unavailable',
      retryable: true,
    );
  }

  @override
  Future<List<CloudBackupMetadata>> list() async {
    throw const CloudBackupGatewayException(
      'http_503',
      'service unavailable',
      retryable: true,
    );
  }

  @override
  Future<CloudBackupEnvelope> download(String backupId) async {
    throw const CloudBackupGatewayException(
      'http_503',
      'service unavailable',
      retryable: true,
    );
  }
}
