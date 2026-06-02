import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/db/db_schema_compat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// 真实 sqflite 链路测试：operation_audit_logs 表 + token_id + 4 个索引必须在两条路径
/// 都就位。
/// - 新库（onCreate）：通过 [DbSchema.create]。
/// - 旧库升级（onUpgrade + onOpen）：v23 → v24，再走一次幂等 onOpen。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp(
      'asset_ledger_migration_024_',
    );
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test(
    'fresh create at current schema version provisions the audit table',
    () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      );
      try {
        expect(await _tableExists(db, 'operation_audit_logs'), isTrue);
        expect(
          await _indexNames(db, 'operation_audit_logs'),
          containsAll(<String>[
            'idx_operation_audit_logs_operation_id',
            'idx_operation_audit_logs_token_id',
            'idx_operation_audit_logs_created_at',
            'idx_operation_audit_logs_operation_type',
          ]),
        );

        // 基本 insert / read 走 SQL 通路验证 schema 可用。
        await db.insert('operation_audit_logs', {
          'id': 'a',
          'operation_id': 'op-1',
          'token_id': 'token-1',
          'operation_type': 'save_timing_record',
          'actor_type': 'owner',
          'source': 'app',
          'created_at': '2026-06-01T12:00:00.000Z',
          'entity_refs_json': '[]',
          'confirmed': 1,
          'result': 'success',
        });
        final rows = await db.query('operation_audit_logs');
        expect(rows, hasLength(1));
        expect(rows.single['id'], 'a');
        expect(rows.single['token_id'], 'token-1');
        expect(
          await _columnExists(db, 'operation_audit_logs', 'token_id'),
          isTrue,
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'v23 → v24 upgrade adds token_id and token index without touching old tables',
    () async {
      // ---- 1) 准备一个 v23 旧库：audit 表存在，但没有 token_id。
      final v23 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 23,
          onCreate: (db, _) async {
            // 一个最小业务表用来证明升级不会动它。
            await db.execute('''
            CREATE TABLE legacy_business_table (
              id TEXT PRIMARY KEY,
              note TEXT
            );
          ''');
            await db.insert('legacy_business_table', {
              'id': 'kept',
              'note': '不应被动',
            });
            await db.execute('''
            CREATE TABLE operation_audit_logs (
              id TEXT PRIMARY KEY,
              operation_id TEXT NOT NULL,
              operation_type TEXT NOT NULL,
              actor_id TEXT,
              actor_type TEXT NOT NULL,
              source TEXT NOT NULL,
              created_at TEXT NOT NULL,
              entity_refs_json TEXT NOT NULL,
              preview_snapshot_json TEXT,
              before_snapshot_json TEXT,
              after_snapshot_json TEXT,
              confirmed INTEGER NOT NULL DEFAULT 0 CHECK (confirmed IN (0, 1)),
              result TEXT NOT NULL,
              error_message TEXT
            );
          ''');
            await db.insert('operation_audit_logs', {
              'id': 'old-audit',
              'operation_id': 'op-old',
              'operation_type': 'save_timing_record',
              'actor_type': 'owner',
              'source': 'app',
              'created_at': '2026-06-01T12:00:00.000Z',
              'entity_refs_json': '[]',
              'confirmed': 1,
              'result': 'success',
            });
          },
        ),
      );
      await v23.close();

      // ---- 2) 升级到 v24：onUpgrade → DbMigrations.apply，onOpen → audit ensure。
      final v24 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 24,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onUpgrade: (db, oldV, newV) async {
            await DbMigrations.apply(db, oldV, newV);
          },
          onOpen: (db) async {
            // 模拟生产 onOpen：只调用本次相关 ensure（DbSchemaCompat.ensure 还会
            // 调用其它历史 ensure，需要旧业务表 fixture，超出本测试范围）。
            await DbMigrations.ensureOperationAuditLogSchema(db);
          },
        ),
      );

      try {
        // 新列 + 索引就位，旧审计数据保留。
        expect(await _tableExists(v24, 'operation_audit_logs'), isTrue);
        expect(
          await _columnExists(v24, 'operation_audit_logs', 'token_id'),
          isTrue,
        );
        expect(
          await _indexNames(v24, 'operation_audit_logs'),
          containsAll(<String>[
            'idx_operation_audit_logs_operation_id',
            'idx_operation_audit_logs_token_id',
            'idx_operation_audit_logs_created_at',
            'idx_operation_audit_logs_operation_type',
          ]),
        );

        final auditRows = await v24.query('operation_audit_logs');
        expect(auditRows.single['id'], 'old-audit');
        expect(auditRows.single['token_id'], isNull);

        // 旧业务表与数据保留。
        final legacyRows = await v24.query('legacy_business_table');
        expect(legacyRows.map((r) => r['id']).toList(), ['kept']);
      } finally {
        await v24.close();
      }
    },
  );

  test(
    'DbSchemaCompat.ensure provisions the audit table on already-current DB',
    () async {
      // 直接以当前版本打开（不触发 onUpgrade），手动调用 DbSchemaCompat.ensure 之前
      // 表也已存在（因为 onCreate 已经创建过）；但 ensure 必须幂等。
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      );
      try {
        await DbSchemaCompat.ensure(db);
        // 表仍在，且能再次 ensure 不抛错。
        expect(await _tableExists(db, 'operation_audit_logs'), isTrue);
        expect(
          await _columnExists(db, 'operation_audit_logs', 'token_id'),
          isTrue,
        );
        await DbSchemaCompat.ensure(db);
        expect(await _tableExists(db, 'operation_audit_logs'), isTrue);
        expect(
          await _columnExists(db, 'operation_audit_logs', 'token_id'),
          isTrue,
        );
      } finally {
        await db.close();
      }
    },
  );
}

Future<bool> _tableExists(DatabaseExecutor db, String tableName) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
    [tableName],
  );
  return rows.isNotEmpty;
}

Future<List<String>> _indexNames(DatabaseExecutor db, String tableName) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name=?;",
    [tableName],
  );
  return rows.map((r) => r['name'] as String).toList();
}

Future<bool> _columnExists(
  DatabaseExecutor db,
  String tableName,
  String columnName,
) async {
  final rows = await db.rawQuery('PRAGMA table_info($tableName);');
  return rows.any((row) => row['name'] == columnName);
}
