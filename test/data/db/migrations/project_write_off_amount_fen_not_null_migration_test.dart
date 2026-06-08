import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/db/db_schema_compat.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// R5.26-B2：project_write_offs.amount_fen 提升为 INTEGER NOT NULL（重建表）。
///
/// 覆盖：
/// - 多版本升级（v16/v17 缺列、v18 nullable+残留 NULL）→ v30：amount_fen NOT NULL、
///   无 NULL、行数无丢失、amount REAL 原值保留、COALESCE 兜底、CHECK(amount>0) 与
///   projects FK RESTRICT 仍生效、两索引仍在。
/// - 当前版本漂移（nullable + NULL 行）经 ensure 自愈为 NOT NULL。
/// - fresh schema 即 NOT NULL；ensure 幂等（已 NOT NULL 重复调用为 no-op）。
/// 全程 sqflite_common_ffi，覆盖 onCreate / onUpgrade / onOpen。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('writeoff_fen_notnull_');
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('fresh schema at current version: project_write_offs.amount_fen NOT NULL',
      () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      ),
    );
    try {
      expect(await _isNotNull(db, 'project_write_offs', 'amount_fen'), isTrue);
      // amount REAL 兼容列仍在且仍 NOT NULL。
      expect(await _isNotNull(db, 'project_write_offs', 'amount'), isTrue);
    } finally {
      await db.close();
    }
  });

  test(
    'legacy v17 (no amount_fen column) -> v30: NOT NULL, backfilled, data + '
    'constraints + indexes preserved',
    () async {
      final legacy = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 17,
          onConfigure: _enableForeignKeys,
          onCreate: (db, _) async {
            await DbSchema.create(db);
            await _recreateWriteOffsLegacy(db, withAmountFenColumn: false);
            await _insertProject(db, id: 'project:a');
            await _insertWriteOffRaw(db, id: 'w1', amount: 6.78);
            await _insertWriteOffRaw(db, id: 'w2', amount: 0.1);
            await _insertWriteOffRaw(db, id: 'w3', amount: 19.99);
          },
        ),
      );
      expect(
        await _columnExists(legacy, 'project_write_offs', 'amount_fen'),
        isFalse,
      );
      await legacy.close();

      final db = await _openCurrentDb(dbPath);
      try {
        // 列已重建为 NOT NULL。
        expect(await _isNotNull(db, 'project_write_offs', 'amount_fen'), isTrue);
        // 无 NULL + 行数无丢失。
        expect(await _nullFenCount(db), 0);
        expect(await _rowCount(db, 'project_write_offs'), 3);
        // 逐行 amount_fen == round(amount*100)，amount REAL 原值保留。
        for (final row in await db.query('project_write_offs')) {
          final amount = (row['amount'] as num).toDouble();
          expect((row['amount_fen'] as num?)?.toInt(), (amount * 100).round());
        }
        // 两索引仍在。
        expect(await _indexExists(db, 'idx_project_write_offs_project_id'), isTrue);
        expect(
          await _indexExists(db, 'idx_project_write_offs_write_off_date'),
          isTrue,
        );
        // CHECK(amount>0) 仍生效。
        await expectLater(
          db.insert('project_write_offs', _writeOffRow(id: 'bad', amount: 0)),
          throwsA(isA<DatabaseException>()),
        );
        // FK RESTRICT 仍生效：孤儿 project_id 插入失败。
        await expectLater(
          db.insert(
            'project_write_offs',
            _writeOffRow(id: 'orphan', amount: 5, projectId: 'no-such'),
          ),
          throwsA(isA<DatabaseException>()),
        );
        // FK RESTRICT 仍生效：删除被引用的 project 失败。
        await expectLater(
          db.delete('projects', where: 'id = ?', whereArgs: ['project:a']),
          throwsA(isA<DatabaseException>()),
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'legacy v18 (nullable amount_fen with residual NULL) -> v30: COALESCE '
    'backfills NULL, keeps existing fen',
    () async {
      final legacy = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 18,
          onConfigure: _enableForeignKeys,
          onCreate: (db, _) async {
            await DbSchema.create(db);
            await _recreateWriteOffsLegacy(db, withAmountFenColumn: true);
            await _insertProject(db, id: 'project:a');
            // 一行带一致 fen、一行 fen=NULL（残留漂移）。
            await _insertWriteOffRaw(db, id: 'w1', amount: 60.0, amountFen: 6000);
            await _insertWriteOffRaw(db, id: 'w2', amount: 12.34, amountFen: null);
          },
        ),
      );
      await legacy.close();

      final db = await _openCurrentDb(dbPath);
      try {
        expect(await _isNotNull(db, 'project_write_offs', 'amount_fen'), isTrue);
        expect(await _nullFenCount(db), 0);
        expect(
          (await db.query('project_write_offs', where: 'id = ?', whereArgs: ['w1']))
              .single['amount_fen'],
          6000,
        );
        // NULL 行被 COALESCE 兜底为 round(12.34*100)=1234。
        expect(
          (await db.query('project_write_offs', where: 'id = ?', whereArgs: ['w2']))
              .single['amount_fen'],
          1234,
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'current-version drift (nullable amount_fen + NULL row) healed by ensure',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onConfigure: _enableForeignKeys,
          onCreate: (db, _) async {
            await DbSchema.create(db);
            // 模拟漂移：把 write_offs 退回 nullable amount_fen 形态并插入 NULL 行。
            await _recreateWriteOffsLegacy(db, withAmountFenColumn: true);
            await _insertProject(db, id: 'project:a');
            await _insertWriteOffRaw(db, id: 'w1', amount: 88.0, amountFen: null);
          },
        ),
      );
      try {
        expect(await _isNotNull(db, 'project_write_offs', 'amount_fen'), isFalse);
        expect(await _nullFenCount(db), 1);

        await DbMigrations.ensureProjectWriteOffAmountFenNotNull(db);

        expect(await _isNotNull(db, 'project_write_offs', 'amount_fen'), isTrue);
        expect(await _nullFenCount(db), 0);
        expect(
          (await db.query('project_write_offs')).single['amount_fen'],
          8800,
        );
      } finally {
        await db.close();
      }
    },
  );

  test('ensure is idempotent on an already NOT NULL table', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onConfigure: _enableForeignKeys,
        onCreate: (db, _) async {
          await DbSchema.create(db);
          await _insertProject(db, id: 'project:a');
          await db.insert(
            'project_write_offs',
            _writeOffRow(id: 'w1', amount: 50.0, amountFen: 5000),
          );
        },
      ),
    );
    try {
      // 已是 NOT NULL：重复调用为 no-op，不报错、数据不变。
      await DbMigrations.ensureProjectWriteOffAmountFenNotNull(db);
      await DbMigrations.ensureProjectWriteOffAmountFenNotNull(db);
      expect(await _isNotNull(db, 'project_write_offs', 'amount_fen'), isTrue);
      expect(await _rowCount(db, 'project_write_offs'), 1);
      expect(
        (await db.query('project_write_offs')).single['amount_fen'],
        5000,
      );
    } finally {
      await db.close();
    }
  });
}

// ===========================================================================
// Helpers
// ===========================================================================

Future<void> _enableForeignKeys(Database db) async {
  await db.execute('PRAGMA foreign_keys = ON');
}

Future<Database> _openCurrentDb(String path) {
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: AppDatabase.schemaVersion,
      onConfigure: _enableForeignKeys,
      onCreate: (db, _) => DbSchema.create(db),
      onUpgrade: DbMigrations.apply,
      onOpen: (db) => DbSchemaCompat.ensure(db),
    ),
  );
}

Future<void> _insertProject(DatabaseExecutor db, {required String id}) async {
  await db.insert(
    'projects',
    Project(
      id: id,
      contact: '甲方',
      site: '一号工地',
      createdAt: '2026-05-18T00:00:00.000Z',
      updatedAt: '2026-05-18T00:00:00.000Z',
    ).toMap(),
  );
}

/// 把 project_write_offs 退回旧形态（可选是否含 nullable amount_fen 列）。
Future<void> _recreateWriteOffsLegacy(
  DatabaseExecutor db, {
  required bool withAmountFenColumn,
}) async {
  await db.execute('DROP INDEX IF EXISTS idx_project_write_offs_project_id;');
  await db.execute(
    'DROP INDEX IF EXISTS idx_project_write_offs_write_off_date;',
  );
  await db.execute('DROP TABLE IF EXISTS project_write_offs;');
  final fenColumn = withAmountFenColumn ? 'amount_fen INTEGER,' : '';
  await db.execute('''
    CREATE TABLE project_write_offs (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      amount REAL NOT NULL CHECK (amount > 0),
      $fenColumn
      reason TEXT NOT NULL,
      note TEXT,
      write_off_date TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (project_id)
        REFERENCES projects(id) ON DELETE RESTRICT
    );
  ''');
  await db.execute('''
    CREATE INDEX idx_project_write_offs_project_id
    ON project_write_offs(project_id);
  ''');
  await db.execute('''
    CREATE INDEX idx_project_write_offs_write_off_date
    ON project_write_offs(write_off_date);
  ''');
}

Map<String, Object?> _writeOffRow({
  required String id,
  required double amount,
  String projectId = 'project:a',
  Object? amountFen = _absent,
}) {
  final row = <String, Object?>{
    'id': id,
    'project_id': projectId,
    'amount': amount,
    'reason': 'rounding',
    'note': null,
    'write_off_date': '2026-05-18',
    'created_at': '2026-05-18T00:00:00.000Z',
    'updated_at': '2026-05-18T00:00:00.000Z',
  };
  if (!identical(amountFen, _absent)) {
    row['amount_fen'] = amountFen;
  } else {
    row['amount_fen'] = (amount * 100).round();
  }
  return row;
}

/// 直接按 legacy 列集插入（amount_fen 缺列时不写该键）。
Future<void> _insertWriteOffRaw(
  DatabaseExecutor db, {
  required String id,
  required double amount,
  Object? amountFen = _absent,
}) async {
  final row = <String, Object?>{
    'id': id,
    'project_id': 'project:a',
    'amount': amount,
    'reason': 'rounding',
    'write_off_date': '2026-05-18',
    'created_at': '2026-05-18T00:00:00.000Z',
    'updated_at': '2026-05-18T00:00:00.000Z',
  };
  if (!identical(amountFen, _absent)) {
    row['amount_fen'] = amountFen;
  }
  await db.insert('project_write_offs', row);
}

const Object _absent = Object();

Future<bool> _columnExists(
  DatabaseExecutor db,
  String table,
  String column,
) async {
  final rows = await db.rawQuery('PRAGMA table_info($table);');
  return rows.any((row) => row['name'] == column);
}

Future<bool> _isNotNull(
  DatabaseExecutor db,
  String table,
  String column,
) async {
  final rows = await db.rawQuery('PRAGMA table_info($table);');
  for (final row in rows) {
    if (row['name'] == column) return ((row['notnull'] as int?) ?? 0) == 1;
  }
  return false;
}

Future<int> _nullFenCount(DatabaseExecutor db) async {
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS c FROM project_write_offs WHERE amount_fen IS NULL',
  );
  return (rows.single['c'] as num?)?.toInt() ?? 0;
}

Future<int> _rowCount(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
  return (rows.single['c'] as num?)?.toInt() ?? 0;
}

Future<bool> _indexExists(DatabaseExecutor db, String index) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?;",
    [index],
  );
  return rows.isNotEmpty;
}
