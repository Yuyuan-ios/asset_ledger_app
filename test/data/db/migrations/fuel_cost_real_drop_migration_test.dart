import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// Track A / A4-1：fuel_logs.cost REAL 删除，cost_fen 成为唯一存储权威。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('fuel_cost_real_drop_');
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('fresh schema has cost_fen only', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      ),
    );
    try {
      expect(await _columnExists(db, 'fuel_logs', 'cost'), isFalse);
      expect(await _isNotNull(db, 'fuel_logs', 'cost_fen'), isTrue);

      await db.insert('fuel_logs', _a4FuelRow(costFen: 12345));
      final row = (await db.query('fuel_logs')).single;
      expect(FuelLog.fromMap(row).cost, 123.45);
    } finally {
      await db.close();
    }
  });

  test(
    'legacy rows are rebuilt without cost and preserve/backfill fen',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 41,
          onCreate: (db, _) async {
            await _createLegacyFuelLogs(db);
            await db.insert('fuel_logs', _legacyFuelRow(id: 1, cost: 200.0));
            await db.insert('fuel_logs', _legacyFuelRow(id: 2, cost: 0.1));
            await db.insert('fuel_logs', _legacyFuelRow(id: 3, cost: 19.99));
            await db.insert(
              'fuel_logs',
              _legacyFuelRow(id: 4, cost: 100.0, costFen: 1),
            );
          },
        ),
      );
      try {
        expect(await _columnExists(db, 'fuel_logs', 'cost'), isTrue);

        await DbMigrations.ensureFuelCostRealDropped(db);

        expect(await _columnExists(db, 'fuel_logs', 'cost'), isFalse);
        expect(await _isNotNull(db, 'fuel_logs', 'cost_fen'), isTrue);
        final rows = await db.query('fuel_logs', orderBy: 'id');
        expect(rows, hasLength(4));
        expect(rows[0]['cost_fen'], 20000);
        expect(rows[1]['cost_fen'], 10);
        expect(rows[2]['cost_fen'], 1999);
        expect(rows[3]['cost_fen'], 1);
        expect(FuelLog.fromMap(rows[2]).cost, 19.99);
      } finally {
        await db.close();
      }
    },
  );

  test('AUTOINCREMENT high-water mark survives the rebuild', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 41,
        onCreate: (db, _) async {
          await _createLegacyFuelLogs(db);
          await db.insert('fuel_logs', _legacyFuelRow(id: 1000, cost: 1.0));
          await db.delete('fuel_logs', where: 'id = 1000');
          await db.insert('fuel_logs', _legacyFuelRow(id: 1, cost: 2.0));
        },
      ),
    );
    try {
      await DbMigrations.ensureFuelCostRealDropped(db);

      final seqRows = await db.rawQuery(
        "SELECT name, seq FROM sqlite_sequence WHERE name LIKE 'fuel_logs%';",
      );
      expect(seqRows, hasLength(1));
      expect(seqRows.single['name'], 'fuel_logs');
      expect((seqRows.single['seq'] as int), greaterThanOrEqualTo(1000));

      final newId = await db.insert('fuel_logs', _a4FuelRow(costFen: 300));
      expect(newId, greaterThan(1000));
    } finally {
      await db.close();
    }
  });

  test('ensure is idempotent after rebuild', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 41,
        onCreate: (db, _) async {
          await _createLegacyFuelLogs(db);
          await db.insert('fuel_logs', _legacyFuelRow(id: 1, cost: 88.88));
        },
      ),
    );
    try {
      await DbMigrations.ensureFuelCostRealDropped(db);
      final afterFirst = await db.query('fuel_logs');

      await DbMigrations.ensureFuelCostRealDropped(db);
      final afterSecond = await db.query('fuel_logs');

      expect(afterSecond, afterFirst);
      expect(await _columnExists(db, 'fuel_logs', 'cost'), isFalse);
    } finally {
      await db.close();
    }
  });
}

Future<void> _createLegacyFuelLogs(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE fuel_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id INTEGER NOT NULL,
      date INTEGER NOT NULL,
      supplier TEXT NOT NULL,
      liters REAL NOT NULL,
      cost REAL NOT NULL,
      cost_fen INTEGER
    );
  ''');
}

Map<String, Object?> _legacyFuelRow({
  int? id,
  required double cost,
  int? costFen,
}) {
  return {
    'id': id,
    'device_id': 7,
    'date': 20260601,
    'supplier': '王五',
    'liters': 30.0,
    'cost': cost,
    'cost_fen': costFen,
  };
}

Map<String, Object?> _a4FuelRow({int? id, required int costFen}) {
  return {
    'id': id,
    'device_id': 7,
    'date': 20260601,
    'supplier': '王五',
    'liters': 30.0,
    'cost_fen': costFen,
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
