import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// Track A / A4-5：project_write_offs.amount REAL 删除，amount_fen 成为存储权威。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('write_off_real_drop_');
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('fresh schema has no amount REAL and keeps fen FK/indexes', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onConfigure: _enableForeignKeys,
        onCreate: (db, _) => DbSchema.create(db),
        onOpen: (db) => DbMigrations.ensureProjectWriteOffAmountRealDropped(db),
      ),
    );
    try {
      expect(await _columnExists(db, 'project_write_offs', 'amount'), isFalse);
      expect(await _isNotNull(db, 'project_write_offs', 'amount_fen'), isTrue);
      expect(await _hasAmountFenCheck(db), isTrue);
      expect(await _hasProjectForeignKey(db), isTrue);
      expect(
        await _indexExists(db, 'idx_project_write_offs_project_id'),
        isTrue,
      );
      expect(
        await _indexExists(db, 'idx_project_write_offs_write_off_date'),
        isTrue,
      );

      await _insertProject(db, id: 'project:fresh');
      await db.insert('project_write_offs', {
        'id': 'wo:fresh',
        'project_id': 'project:fresh',
        'amount_fen': 12345,
        'reason': ProjectWriteOffReason.rounding.dbValue,
        'write_off_date': '2026-06-01',
        'created_at': '2026-06-01T00:00:00.000Z',
        'updated_at': '2026-06-01T00:00:00.000Z',
      });
      final row = (await db.query('project_write_offs')).single;
      expect(row.containsKey('amount'), isFalse);
      expect(ProjectWriteOff.fromMap(row).amount, 123.45);
    } finally {
      await db.close();
    }
  });

  test('legacy rows backfill from REAL and preserve existing fen', () async {
    final legacy = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 45,
        onConfigure: _enableForeignKeys,
        onCreate: (db, _) async {
          await _createV45ProjectWriteOffs(db);
          await _insertProject(db, id: 'project:a', site: '一号工地');
          await _insertProject(db, id: 'project:b', site: '二号工地');
          await db.insert(
            'project_write_offs',
            _writeOffRow(id: 'wo-a', projectId: 'project:a', amount: 399.99),
          );
          await db.insert(
            'project_write_offs',
            _writeOffRow(
              id: 'wo-b',
              projectId: 'project:b',
              amount: 0.01,
              amountFen: 76543,
            ),
          );
        },
      ),
    );
    await legacy.close();

    final upgraded = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onConfigure: _enableForeignKeys,
        onUpgrade: DbMigrations.apply,
        onOpen: DbMigrations.ensureProjectWriteOffAmountRealDropped,
      ),
    );
    try {
      expect(
        await _columnExists(upgraded, 'project_write_offs', 'amount'),
        isFalse,
      );
      expect(await _hasAmountFenCheck(upgraded), isTrue);
      expect(await _hasProjectForeignKey(upgraded), isTrue);

      final rows = await upgraded.query('project_write_offs', orderBy: 'id');
      expect(rows, hasLength(2));
      expect(rows[0].containsKey('amount'), isFalse);
      expect(rows[0]['amount_fen'], 39999);
      expect(rows[1]['amount_fen'], 76543);
      expect(ProjectWriteOff.fromMap(rows.first).amountFen, 39999);
    } finally {
      await upgraded.close();
    }
  });

  test(
    'foreign key restricts orphan rows and project deletion after rebuild',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 45,
          onConfigure: _enableForeignKeys,
          onCreate: (db, _) async {
            await _createV45ProjectWriteOffs(db);
            await _insertProject(db, id: 'project:fk');
            await db.insert(
              'project_write_offs',
              _writeOffRow(id: 'wo-fk', projectId: 'project:fk', amount: 380),
            );
          },
        ),
      );
      try {
        await DbMigrations.ensureProjectWriteOffAmountRealDropped(db);

        await expectLater(
          db.insert('project_write_offs', {
            'id': 'wo-orphan',
            'project_id': 'project:missing',
            'amount_fen': 1,
            'reason': ProjectWriteOffReason.rounding.dbValue,
            'write_off_date': '2026-06-01',
            'created_at': '2026-06-01T00:00:00.000Z',
            'updated_at': '2026-06-01T00:00:00.000Z',
          }),
          throwsA(isA<DatabaseException>()),
        );
        await expectLater(
          db.delete('projects', where: 'id = ?', whereArgs: ['project:fk']),
          throwsA(isA<DatabaseException>()),
        );
        expect(await db.rawQuery('PRAGMA foreign_key_check;'), isEmpty);
      } finally {
        await db.close();
      }
    },
  );

  test('ensure is idempotent after REAL has been dropped', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 45,
        onConfigure: _enableForeignKeys,
        onCreate: (db, _) async {
          await _createV45ProjectWriteOffs(db);
          await _insertProject(db, id: 'project:idem');
          await db.insert(
            'project_write_offs',
            _writeOffRow(
              id: 'wo-idem',
              projectId: 'project:idem',
              amount: 88.88,
            ),
          );
        },
      ),
    );
    try {
      await DbMigrations.ensureProjectWriteOffAmountRealDropped(db);
      final afterFirst = await db.query('project_write_offs');

      await DbMigrations.ensureProjectWriteOffAmountRealDropped(db);
      final afterSecond = await db.query('project_write_offs');

      expect(afterSecond, afterFirst);
      expect(await _columnExists(db, 'project_write_offs', 'amount'), isFalse);
    } finally {
      await db.close();
    }
  });
}

Future<void> _enableForeignKeys(Database db) async {
  await db.execute('PRAGMA foreign_keys = ON;');
}

Future<void> _createV45ProjectWriteOffs(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE projects (
      id TEXT PRIMARY KEY,
      contact TEXT NOT NULL,
      site TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'active',
      settled_at TEXT,
      settled_snapshot TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      legacy_project_key TEXT
    );
  ''');
  await db.execute('''
    CREATE TABLE project_write_offs (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      amount REAL NOT NULL CHECK (amount > 0),
      amount_fen INTEGER NOT NULL,
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

Future<void> _insertProject(
  DatabaseExecutor db, {
  required String id,
  String site = '项目工地',
}) {
  return db.insert(
    'projects',
    Project(
      id: id,
      contact: '甲方',
      site: site,
      createdAt: '2026-06-01T00:00:00.000Z',
      updatedAt: '2026-06-01T00:00:00.000Z',
      legacyProjectKey: '甲方||$site',
    ).toMap(),
  );
}

Map<String, Object?> _writeOffRow({
  required String id,
  required String projectId,
  required double amount,
  int? amountFen,
}) {
  return {
    'id': id,
    'project_id': projectId,
    'amount': amount,
    'amount_fen': amountFen ?? (amount * 100).round(),
    'reason': ProjectWriteOffReason.rounding.dbValue,
    'note': '尾款不再追收',
    'write_off_date': '2026-06-01',
    'created_at': '2026-06-01T00:00:00.000Z',
    'updated_at': '2026-06-01T00:00:00.000Z',
  };
}

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

Future<bool> _hasProjectForeignKey(DatabaseExecutor db) async {
  final rows = await db.rawQuery(
    'PRAGMA foreign_key_list(project_write_offs);',
  );
  return rows.any((row) {
    return row['table'] == 'projects' &&
        row['from'] == 'project_id' &&
        row['on_delete'] == 'RESTRICT';
  });
}

Future<bool> _hasAmountFenCheck(DatabaseExecutor db) async {
  final rows = await db.query(
    'sqlite_master',
    columns: ['sql'],
    where: 'type = ? AND name = ?',
    whereArgs: ['table', 'project_write_offs'],
    limit: 1,
  );
  final sql = rows.single['sql'] as String;
  return sql.contains('CHECK (amount_fen > 0)');
}

Future<bool> _indexExists(DatabaseExecutor db, String index) async {
  final rows = await db.query(
    'sqlite_master',
    columns: ['name'],
    where: 'type = ? AND name = ?',
    whereArgs: ['index', index],
    limit: 1,
  );
  return rows.isNotEmpty;
}
