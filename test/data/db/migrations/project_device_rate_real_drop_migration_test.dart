import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// Track A / A4-4：project_device_rates.rate REAL 删除，rate_fen 成为存储权威。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('project_rate_real_drop_');
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('fresh schema has no rate REAL and keeps rate_fen FK/index', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onConfigure: _enableForeignKeys,
        onCreate: (db, _) => DbSchema.create(db),
        onOpen: (db) => DbMigrations.ensureProjectDeviceRateRealDropped(db),
      ),
    );
    try {
      expect(await _columnExists(db, 'project_device_rates', 'rate'), isFalse);
      expect(await _isNotNull(db, 'project_device_rates', 'rate_fen'), isTrue);
      expect(await _hasProjectForeignKey(db), isTrue);
      expect(
        await _indexExists(db, 'idx_project_device_rates_project'),
        isTrue,
      );

      await _insertProject(db, id: 'project:fresh');
      await db.insert('project_device_rates', {
        'project_id': 'project:fresh',
        'project_key': '甲方||新库',
        'device_id': 1,
        'is_breaking': 0,
        'rate_fen': 38000,
      });
      final row = (await db.query('project_device_rates')).single;
      expect(row.containsKey('rate'), isFalse);
      expect(ProjectDeviceRate.fromMap(row).rate, 380);
    } finally {
      await db.close();
    }
  });

  test('legacy rows backfill from REAL and preserve existing fen', () async {
    final legacy = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 44,
        onConfigure: _enableForeignKeys,
        onCreate: (db, _) async {
          await _createV44ProjectDeviceRates(db);
          await _insertProject(db, id: 'project:a', site: '一号工地');
          await _insertProject(db, id: 'project:b', site: '二号工地');
          await db.insert(
            'project_device_rates',
            _rateRow(projectId: 'project:a', rate: 399.99),
          );
          await db.insert(
            'project_device_rates',
            _rateRow(
              projectId: 'project:b',
              rate: 0.01,
              rateFen: 76543,
              isBreaking: true,
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
        onOpen: DbMigrations.ensureProjectDeviceRateRealDropped,
      ),
    );
    try {
      expect(
        await _columnExists(upgraded, 'project_device_rates', 'rate'),
        isFalse,
      );
      expect(await _hasProjectForeignKey(upgraded), isTrue);
      expect(
        await _indexExists(upgraded, 'idx_project_device_rates_project'),
        isTrue,
      );

      final rows = await upgraded.query(
        'project_device_rates',
        orderBy: 'project_id',
      );
      expect(rows, hasLength(2));
      expect(rows[0].containsKey('rate'), isFalse);
      expect(rows[0]['rate_fen'], 39999);
      expect(rows[1]['rate_fen'], 76543);
      expect(ProjectDeviceRate.fromMap(rows.first).rateFen, 39999);
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
          version: 44,
          onConfigure: _enableForeignKeys,
          onCreate: (db, _) async {
            await _createV44ProjectDeviceRates(db);
            await _insertProject(db, id: 'project:fk');
            await db.insert(
              'project_device_rates',
              _rateRow(projectId: 'project:fk', rate: 380),
            );
          },
        ),
      );
      try {
        await DbMigrations.ensureProjectDeviceRateRealDropped(db);

        await expectLater(
          db.insert('project_device_rates', {
            'project_id': 'project:missing',
            'project_key': '甲方||缺失项目',
            'device_id': 2,
            'is_breaking': 0,
            'rate_fen': 1,
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
        version: 44,
        onConfigure: _enableForeignKeys,
        onCreate: (db, _) async {
          await _createV44ProjectDeviceRates(db);
          await _insertProject(db, id: 'project:idem');
          await db.insert(
            'project_device_rates',
            _rateRow(projectId: 'project:idem', rate: 88.88),
          );
        },
      ),
    );
    try {
      await DbMigrations.ensureProjectDeviceRateRealDropped(db);
      final afterFirst = await db.query('project_device_rates');

      await DbMigrations.ensureProjectDeviceRateRealDropped(db);
      final afterSecond = await db.query('project_device_rates');

      expect(afterSecond, afterFirst);
      expect(await _columnExists(db, 'project_device_rates', 'rate'), isFalse);
    } finally {
      await db.close();
    }
  });
}

Future<void> _enableForeignKeys(Database db) async {
  await db.execute('PRAGMA foreign_keys = ON;');
}

Future<void> _createV44ProjectDeviceRates(DatabaseExecutor db) async {
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
    CREATE TABLE project_device_rates (
      project_id TEXT NOT NULL,
      project_key TEXT NOT NULL,
      device_id INTEGER NOT NULL,
      is_breaking INTEGER NOT NULL DEFAULT 0,
      rate REAL NOT NULL,
      rate_fen INTEGER NOT NULL,
      PRIMARY KEY (project_id, device_id, is_breaking),
      FOREIGN KEY (project_id)
        REFERENCES projects(id) ON DELETE RESTRICT
    );
  ''');
  await db.execute('''
    CREATE INDEX idx_project_device_rates_project
    ON project_device_rates(project_id);
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

Map<String, Object?> _rateRow({
  required String projectId,
  required double rate,
  int? rateFen,
  bool isBreaking = false,
}) {
  return {
    'project_id': projectId,
    'project_key': '甲方||项目工地',
    'device_id': isBreaking ? 2 : 1,
    'is_breaking': isBreaking ? 1 : 0,
    'rate': rate,
    'rate_fen': rateFen ?? (rate * 100).round(),
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
    'PRAGMA foreign_key_list(project_device_rates);',
  );
  return rows.any((row) {
    return row['table'] == 'projects' &&
        row['from'] == 'project_id' &&
        row['on_delete'] == 'RESTRICT';
  });
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
