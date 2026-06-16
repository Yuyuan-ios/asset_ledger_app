import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/services/backup/cloud_backup_service.dart';
import 'package:asset_ledger/infrastructure/cloud/cloud_backup_cipher.dart';
import 'package:asset_ledger/infrastructure/cloud/cloud_backup_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

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
      'income': 0.0,
      'income_fen': 0,
      'unit': 'HOUR',
      'quantity_scaled': 7500,
      'exclude_from_fuel_eff': 0,
      'is_breaking': 0,
    });
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
