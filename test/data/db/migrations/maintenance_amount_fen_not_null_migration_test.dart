import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/maintenance_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// Track A / A2d：maintenance_records.amount_fen 提升为 NOT NULL。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp(
      'maintenance_amount_fen_nn_',
    );
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('fresh schema enforces amount_fen NOT NULL', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      ),
    );
    try {
      expect(await _isNotNull(db, 'maintenance_records', 'amount_fen'), isTrue);
      expect(await _isNotNull(db, 'maintenance_records', 'amount'), isTrue);

      await expectLater(
        db.insert(
          'maintenance_records',
          _maintenanceRow(amount: 12.34)..remove('amount_fen'),
        ),
        throwsA(isA<DatabaseException>()),
      );
    } finally {
      await db.close();
    }
  });

  test(
    'legacy v40 nullable amount_fen is rebuilt, backfilled, and keeps rows',
    () async {
      final legacy = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 40,
          onCreate: (db, _) async {
            await _createV40MaintenanceRecords(db);
            await db.insert(
              'maintenance_records',
              _maintenanceRow(id: 1, amount: 50.0),
            );
            await db.insert(
              'maintenance_records',
              _maintenanceRow(id: 2, amount: 1234.56),
            );
            await db.insert(
              'maintenance_records',
              _maintenanceRow(id: 3, amount: 100.0, amountFen: 1),
            );
          },
        ),
      );
      expect(
        await _isNotNull(legacy, 'maintenance_records', 'amount_fen'),
        isFalse,
      );
      await legacy.close();

      final upgraded = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onUpgrade: DbMigrations.apply,
          onOpen: DbMigrations.ensureMaintenanceAmountFenNotNull,
        ),
      );
      try {
        expect(
          await _isNotNull(upgraded, 'maintenance_records', 'amount_fen'),
          isTrue,
        );

        final rows = await upgraded.query('maintenance_records', orderBy: 'id');
        expect(rows, hasLength(3));
        expect(rows[0]['amount_fen'], 5000);
        expect(rows[1]['amount_fen'], 123456);
        expect(rows[2]['amount_fen'], 1, reason: '既有非 NULL fen 不应被重建覆盖');
        expect(rows[0]['note'], '定期保养');

        expect(MaintenanceRecord.fromMap(rows.first).amountFen, 5000);
      } finally {
        await upgraded.close();
      }
    },
  );

  test('AUTOINCREMENT high-water mark survives the rebuild', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 40,
        onCreate: (db, _) async {
          await _createV40MaintenanceRecords(db);
          await db.insert(
            'maintenance_records',
            _maintenanceRow(id: 1000, amount: 1.0),
          );
          await db.delete('maintenance_records', where: 'id = 1000');
          await db.insert(
            'maintenance_records',
            _maintenanceRow(id: 1, amount: 2.0),
          );
        },
      ),
    );

    await DbMigrations.ensureMaintenanceAmountFenNotNull(db);

    try {
      final seqRows = await db.rawQuery(
        "SELECT name, seq FROM sqlite_sequence "
        "WHERE name LIKE 'maintenance_records%';",
      );
      expect(seqRows, hasLength(1));
      expect(seqRows.single['name'], 'maintenance_records');
      expect((seqRows.single['seq'] as int), greaterThanOrEqualTo(1000));

      final newId = await db.insert(
        'maintenance_records',
        _maintenanceRow(amount: 3.0, amountFen: 300),
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
        version: 40,
        onCreate: (db, _) async {
          await _createV40MaintenanceRecords(db);
          await db.insert(
            'maintenance_records',
            _maintenanceRow(id: 1, amount: 88.88),
          );
        },
      ),
    );
    try {
      await DbMigrations.ensureMaintenanceAmountFenNotNull(db);
      final afterFirst = await db.query('maintenance_records');

      await DbMigrations.ensureMaintenanceAmountFenNotNull(db);
      final afterSecond = await db.query('maintenance_records');

      expect(afterSecond, afterFirst);
      expect(await _isNotNull(db, 'maintenance_records', 'amount_fen'), isTrue);
    } finally {
      await db.close();
    }
  });
}

Future<void> _createV40MaintenanceRecords(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE maintenance_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id INTEGER,
      ymd INTEGER NOT NULL,
      item TEXT NOT NULL,
      amount REAL NOT NULL,
      amount_fen INTEGER,
      note TEXT
    );
  ''');
}

Map<String, Object?> _maintenanceRow({
  int? id,
  required double amount,
  int? amountFen,
}) {
  return {
    'id': id,
    'device_id': 7,
    'ymd': 20260601,
    'item': '换机油',
    'amount': amount,
    'amount_fen': amountFen,
    'note': '定期保养',
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
