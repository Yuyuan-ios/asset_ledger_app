import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// Track A / A2c：fuel_logs.cost_fen 提升为 NOT NULL。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('fuel_cost_fen_nn_');
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('fresh schema enforces cost_fen NOT NULL only', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      ),
    );
    try {
      expect(await _isNotNull(db, 'fuel_logs', 'cost_fen'), isTrue);
      expect(await _isNotNull(db, 'fuel_logs', 'cost'), isTrue);
      expect(
        await _isNotNull(db, 'maintenance_records', 'amount_fen'),
        isFalse,
      );

      await expectLater(
        db.insert('fuel_logs', _fuelRow(cost: 12.34)..remove('cost_fen')),
        throwsA(isA<DatabaseException>()),
      );
    } finally {
      await db.close();
    }
  });

  test(
    'legacy v39 nullable cost_fen is rebuilt, backfilled, and keeps rows',
    () async {
      final legacy = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 39,
          onCreate: (db, _) async {
            await _createV39FuelLogs(db);
            await db.insert('fuel_logs', _fuelRow(id: 1, cost: 200.0));
            await db.insert('fuel_logs', _fuelRow(id: 2, cost: 0.1));
            await db.insert('fuel_logs', _fuelRow(id: 3, cost: 19.99));
            await db.insert(
              'fuel_logs',
              _fuelRow(id: 4, cost: 100.0, costFen: 1),
            );
          },
        ),
      );
      expect(await _isNotNull(legacy, 'fuel_logs', 'cost_fen'), isFalse);
      await legacy.close();

      final upgraded = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onUpgrade: DbMigrations.apply,
          onOpen: DbMigrations.ensureFuelCostFenNotNull,
        ),
      );
      try {
        expect(await _isNotNull(upgraded, 'fuel_logs', 'cost_fen'), isTrue);

        final rows = await upgraded.query('fuel_logs', orderBy: 'id');
        expect(rows, hasLength(4));
        expect(rows[0]['cost_fen'], 20000);
        expect(rows[1]['cost_fen'], 10);
        expect(rows[2]['cost_fen'], 1999);
        expect(rows[3]['cost_fen'], 1, reason: '既有非 NULL fen 不应被重建覆盖');

        expect(FuelLog.fromMap(rows.first).costFen, 20000);
      } finally {
        await upgraded.close();
      }
    },
  );

  test('AUTOINCREMENT high-water mark survives the rebuild', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 39,
        onCreate: (db, _) async {
          await _createV39FuelLogs(db);
          await db.insert('fuel_logs', _fuelRow(id: 1000, cost: 1.0));
          await db.delete('fuel_logs', where: 'id = 1000');
          await db.insert('fuel_logs', _fuelRow(id: 1, cost: 2.0));
        },
      ),
    );

    await DbMigrations.ensureFuelCostFenNotNull(db);

    try {
      final seqRows = await db.rawQuery(
        "SELECT name, seq FROM sqlite_sequence WHERE name LIKE 'fuel_logs%';",
      );
      expect(seqRows, hasLength(1));
      expect(seqRows.single['name'], 'fuel_logs');
      expect((seqRows.single['seq'] as int), greaterThanOrEqualTo(1000));

      final newId = await db.insert(
        'fuel_logs',
        _fuelRow(cost: 3.0, costFen: 300),
      );
      expect(newId, greaterThan(1000));
    } finally {
      await db.close();
    }
  });

  test('ensure is idempotent after rebuild', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 39,
        onCreate: (db, _) async {
          await _createV39FuelLogs(db);
          await db.insert('fuel_logs', _fuelRow(id: 1, cost: 88.88));
        },
      ),
    );
    try {
      await DbMigrations.ensureFuelCostFenNotNull(db);
      final afterFirst = await db.query('fuel_logs');

      await DbMigrations.ensureFuelCostFenNotNull(db);
      final afterSecond = await db.query('fuel_logs');

      expect(afterSecond, afterFirst);
      expect(await _isNotNull(db, 'fuel_logs', 'cost_fen'), isTrue);
    } finally {
      await db.close();
    }
  });
}

Future<void> _createV39FuelLogs(DatabaseExecutor db) async {
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

Map<String, Object?> _fuelRow({int? id, required double cost, int? costFen}) {
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
