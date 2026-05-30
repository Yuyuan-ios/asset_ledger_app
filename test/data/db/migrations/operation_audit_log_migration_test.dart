import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/db/db_schema_compat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// 真实 sqflite 链路测试：operation_audit_logs 表 + 3 个索引必须在两条路径
/// 都就位。
/// - 新库（onCreate）：通过 [DbSchema.create]。
/// - 旧库升级（onUpgrade + onOpen）：v21 → v22，再走一次幂等 onOpen。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp(
      'asset_ledger_migration_022_',
    );
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('fresh create at current schema version provisions the audit table', () async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: AppDatabase.schemaVersion,
      onCreate: (db, _) => DbSchema.create(db),
    );
    try {
      expect(await _tableExists(db, 'operation_audit_logs'), isTrue);
      expect(await _indexNames(db, 'operation_audit_logs'), containsAll(<String>[
        'idx_operation_audit_logs_operation_id',
        'idx_operation_audit_logs_created_at',
        'idx_operation_audit_logs_operation_type',
      ]));

      // 基本 insert / read 走 SQL 通路验证 schema 可用。
      await db.insert('operation_audit_logs', {
        'id': 'a',
        'operation_id': 'op-1',
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
    } finally {
      await db.close();
    }
  });

  test('v21 → v22 upgrade adds the audit table (and indexes) without touching old tables',
      () async {
    // ---- 1) 准备一个 v21 旧库（最小 fixture：只需要让版本号 = 21）。
    final v21 = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 21,
        onCreate: (db, _) async {
          // 一个最小业务表用来证明升级不会动它。
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
    await v21.close();

    // ---- 2) 升级到 v22：onUpgrade → DbMigrations.apply，onOpen → DbSchemaCompat.ensure。
    final v22 = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 22,
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
      // 新表 + 索引就位。
      expect(await _tableExists(v22, 'operation_audit_logs'), isTrue);
      expect(await _indexNames(v22, 'operation_audit_logs'), containsAll(<String>[
        'idx_operation_audit_logs_operation_id',
        'idx_operation_audit_logs_created_at',
        'idx_operation_audit_logs_operation_type',
      ]));

      // 旧业务表与数据保留。
      final legacyRows = await v22.query('legacy_business_table');
      expect(legacyRows.map((r) => r['id']).toList(), ['kept']);
    } finally {
      await v22.close();
    }
  });

  test('DbSchemaCompat.ensure provisions the audit table on already-current DB',
      () async {
    // 直接以 v22 打开（不触发 onUpgrade），手动调用 DbSchemaCompat.ensure 之前
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
      await DbSchemaCompat.ensure(db);
      expect(await _tableExists(db, 'operation_audit_logs'), isTrue);
    } finally {
      await db.close();
    }
  });
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
