import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/db/db_schema_compat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// 真实 sqflite 链路测试：operation_tokens 表 + 3 个索引必须在两条路径都就位。
/// - 新库（onCreate）：通过 [DbSchema.create]。
/// - 旧库升级（onUpgrade + onOpen）：v22 → v23，再走一次幂等 onOpen。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  const indexNames = <String>[
    'idx_operation_tokens_operation_id',
    'idx_operation_tokens_status_expires_at',
    'idx_operation_tokens_actor_session',
  ];

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp(
      'asset_ledger_migration_023_',
    );
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('fresh create at current schema version provisions operation_tokens', () async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: AppDatabase.schemaVersion,
      onCreate: (db, _) => DbSchema.create(db),
    );
    try {
      expect(await _tableExists(db, 'operation_tokens'), isTrue);
      expect(await _indexNames(db, 'operation_tokens'), containsAll(indexNames));

      // SQL 通路验证 schema 可用：插入一条最小合法行。
      await db.insert('operation_tokens', _sampleRow());
      final rows = await db.query('operation_tokens');
      expect(rows, hasLength(1));
      expect(rows.single['id'], 'tok-1');
      expect(rows.single['status'], 'issued');
    } finally {
      await db.close();
    }
  });

  test('v22 → v23 upgrade adds operation_tokens without touching old tables', () async {
    // v22 旧库 fixture：最小业务表 + operation_audit_logs（证明不被动）。
    final v22 = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 22,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE legacy_business_table (
              id TEXT PRIMARY KEY,
              note TEXT
            );
          ''');
          await db.insert('legacy_business_table', {'id': 'kept', 'note': '不应被动'});
        },
      ),
    );
    await v22.close();

    final v23 = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 23,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onUpgrade: (db, oldV, newV) async {
          await DbMigrations.apply(db, oldV, newV);
        },
        onOpen: (db) async {
          // 模拟生产 onOpen 的本次相关 ensure（不调用整套 DbSchemaCompat.ensure，
          // 那会要求其它历史业务表 fixture，超出本测试范围）。
          await DbMigrations.ensureOperationTokensSchema(db);
        },
      ),
    );

    try {
      expect(await _tableExists(v23, 'operation_tokens'), isTrue);
      expect(await _indexNames(v23, 'operation_tokens'), containsAll(indexNames));

      // 旧业务表与数据保留。
      final legacyRows = await v23.query('legacy_business_table');
      expect(legacyRows.map((r) => r['id']).toList(), ['kept']);
    } finally {
      await v23.close();
    }
  });

  test('DbSchemaCompat.ensure provisions operation_tokens on already-current DB and is idempotent', () async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: AppDatabase.schemaVersion,
      onCreate: (db, _) => DbSchema.create(db),
    );
    try {
      await DbSchemaCompat.ensure(db);
      expect(await _tableExists(db, 'operation_tokens'), isTrue);
      // 再次 ensure 不抛错（幂等）。
      await DbSchemaCompat.ensure(db);
      expect(await _tableExists(db, 'operation_tokens'), isTrue);
      expect(await _indexNames(db, 'operation_tokens'), containsAll(indexNames));
    } finally {
      await db.close();
    }
  });

  test('operation_audit_logs remains a separate table after v23', () async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: AppDatabase.schemaVersion,
      onCreate: (db, _) => DbSchema.create(db),
    );
    try {
      expect(await _tableExists(db, 'operation_audit_logs'), isTrue);
      expect(await _tableExists(db, 'operation_tokens'), isTrue);
    } finally {
      await db.close();
    }
  });
}

Map<String, Object?> _sampleRow() {
  return {
    'id': 'tok-1',
    'operation_id': 'op-1',
    'operation_type': 'save_timing_record',
    'actor_type': 'owner',
    'created_at': '2026-06-01T12:00:00.000Z',
    'expires_at': '2026-06-01T12:30:00.000Z',
    'status': 'issued',
    'input_hash': 'h-input',
    'full_analysis_hash': 'h-full',
    'actor_scope_hash': 'h-scope',
    'freshness_required': 1,
    'requires_reanalysis_before_execute': 1,
    'one_time_use': 1,
    'token_json': '{}',
  };
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
