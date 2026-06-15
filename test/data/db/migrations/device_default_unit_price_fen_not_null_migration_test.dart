import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// Track A / A2a：devices.default_unit_price_fen 提升为 NOT NULL。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('device_default_fen_nn_');
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('fresh schema enforces default_unit_price_fen NOT NULL only', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      ),
    );
    try {
      expect(await _isNotNull(db, 'devices', 'default_unit_price_fen'), isTrue);
      expect(
        await _isNotNull(db, 'devices', 'breaking_unit_price_fen'),
        isFalse,
      );
      expect(await _isNotNull(db, 'devices', 'default_unit_price'), isTrue);
      expect(await _isNotNull(db, 'devices', 'breaking_unit_price'), isFalse);
    } finally {
      await db.close();
    }
  });

  test(
    'legacy v37 nullable default fen is rebuilt, backfilled, and keeps rows',
    () async {
      final legacy = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 37,
          onCreate: (db, _) async {
            await _createV37Devices(db);
            await db.insert('devices', _deviceRow(id: 1, price: 380.5));
            await db.insert(
              'devices',
              _deviceRow(
                id: 2,
                price: 300.0,
                defaultFen: 1,
                breakingPrice: null,
              ),
            );
            await db.insert(
              'devices',
              _deviceRow(id: 3, price: 199.99, breakingPrice: 250.1),
            );
          },
        ),
      );
      expect(
        await _isNotNull(legacy, 'devices', 'default_unit_price_fen'),
        isFalse,
      );
      await legacy.close();

      final upgraded = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onUpgrade: DbMigrations.apply,
          onOpen: DbMigrations.ensureDeviceDefaultUnitPriceFenNotNull,
        ),
      );
      try {
        expect(
          await _isNotNull(upgraded, 'devices', 'default_unit_price_fen'),
          isTrue,
        );
        expect(
          await _isNotNull(upgraded, 'devices', 'breaking_unit_price_fen'),
          isFalse,
        );

        final rows = await upgraded.query('devices', orderBy: 'id');
        expect(rows, hasLength(3));
        expect(rows[0]['default_unit_price_fen'], 38050);
        expect(rows[0]['breaking_unit_price_fen'], isNull);
        expect(
          rows[1]['default_unit_price_fen'],
          1,
          reason: '既有非 NULL fen 不应被重建覆盖',
        );
        expect(rows[1]['breaking_unit_price_fen'], isNull);
        expect(rows[2]['default_unit_price_fen'], 19999);
        expect(rows[2]['breaking_unit_price_fen'], 25010);

        final device = Device.fromMap(rows[2]);
        expect(device.defaultUnitPriceFen, 19999);
        expect(device.breakingUnitPriceFen, 25010);
      } finally {
        await upgraded.close();
      }
    },
  );

  test('AUTOINCREMENT high-water mark survives the rebuild', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 37,
        onCreate: (db, _) async {
          await _createV37Devices(db);
          await db.insert('devices', _deviceRow(id: 1000, price: 1.0));
          await db.delete('devices', where: 'id = 1000');
          await db.insert('devices', _deviceRow(id: 1, price: 2.0));
        },
      ),
    );

    await DbMigrations.ensureDeviceDefaultUnitPriceFenNotNull(db);

    try {
      final seqRows = await db.rawQuery(
        "SELECT name, seq FROM sqlite_sequence WHERE name LIKE 'devices%';",
      );
      expect(seqRows, hasLength(1));
      expect(seqRows.single['name'], 'devices');
      expect((seqRows.single['seq'] as int), greaterThanOrEqualTo(1000));

      final newId = await db.insert(
        'devices',
        _deviceRow(price: 3.0, defaultFen: 300),
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
        version: 37,
        onCreate: (db, _) async {
          await _createV37Devices(db);
          await db.insert('devices', _deviceRow(id: 1, price: 88.88));
        },
      ),
    );
    try {
      await DbMigrations.ensureDeviceDefaultUnitPriceFenNotNull(db);
      final afterFirst = await db.query('devices');

      await DbMigrations.ensureDeviceDefaultUnitPriceFenNotNull(db);
      final afterSecond = await db.query('devices');

      expect(afterSecond, afterFirst);
      expect(await _isNotNull(db, 'devices', 'default_unit_price_fen'), isTrue);
    } finally {
      await db.close();
    }
  });
}

Future<void> _createV37Devices(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE devices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      brand TEXT NOT NULL,
      model TEXT,
      default_unit_price REAL NOT NULL,
      breaking_unit_price REAL,
      default_unit_price_fen INTEGER,
      breaking_unit_price_fen INTEGER,
      base_meter_hours REAL NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      custom_avatar_path TEXT,
      equipment_type TEXT NOT NULL DEFAULT 'excavator'
    );
  ''');
}

Map<String, Object?> _deviceRow({
  int? id,
  required double price,
  int? defaultFen,
  double? breakingPrice,
}) {
  return {
    'id': id,
    'name': 'SANY ${id ?? 'new'}',
    'brand': 'sany',
    'model': null,
    'default_unit_price': price,
    'breaking_unit_price': breakingPrice,
    'default_unit_price_fen': defaultFen,
    'breaking_unit_price_fen': null,
    'base_meter_hours': 0.0,
    'is_active': 1,
    'custom_avatar_path': null,
    'equipment_type': 'excavator',
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
