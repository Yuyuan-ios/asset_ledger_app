import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/maintenance_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// Track A / A4-2：maintenance_records.amount REAL 删除，amount_fen 成为唯一存储权威。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp(
      'maintenance_amount_real_drop_',
    );
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('fresh schema has amount_fen only', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      ),
    );
    try {
      expect(await _columnExists(db, 'maintenance_records', 'amount'), isFalse);
      expect(await _isNotNull(db, 'maintenance_records', 'amount_fen'), isTrue);

      await db.insert(
        'maintenance_records',
        _a4MaintenanceRow(amountFen: 12345),
      );
      final row = (await db.query('maintenance_records')).single;
      expect(MaintenanceRecord.fromMap(row).amount, 123.45);
    } finally {
      await db.close();
    }
  });

  test(
    'legacy rows are rebuilt without amount and preserve/backfill fen',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 42,
          onCreate: (db, _) async {
            await _createLegacyMaintenanceRecords(db);
            await db.insert(
              'maintenance_records',
              _legacyMaintenanceRow(id: 1, amount: 50.0),
            );
            await db.insert(
              'maintenance_records',
              _legacyMaintenanceRow(id: 2, amount: 2345.67),
            );
            await db.insert(
              'maintenance_records',
              _legacyMaintenanceRow(id: 3, amount: 0.1),
            );
            await db.insert(
              'maintenance_records',
              _legacyMaintenanceRow(id: 4, amount: 100.0, amountFen: 1),
            );
          },
        ),
      );
      try {
        expect(
          await _columnExists(db, 'maintenance_records', 'amount'),
          isTrue,
        );

        await DbMigrations.ensureMaintenanceAmountRealDropped(db);

        expect(
          await _columnExists(db, 'maintenance_records', 'amount'),
          isFalse,
        );
        expect(
          await _isNotNull(db, 'maintenance_records', 'amount_fen'),
          isTrue,
        );
        final rows = await db.query('maintenance_records', orderBy: 'id');
        expect(rows, hasLength(4));
        expect(rows[0]['amount_fen'], 5000);
        expect(rows[1]['amount_fen'], 234567);
        expect(rows[2]['amount_fen'], 10);
        expect(rows[3]['amount_fen'], 1);
        expect(rows[0]['note'], '定期保养');
        expect(MaintenanceRecord.fromMap(rows[1]).amount, 2345.67);
      } finally {
        await db.close();
      }
    },
  );

  test('AUTOINCREMENT high-water mark survives the rebuild', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 42,
        onCreate: (db, _) async {
          await _createLegacyMaintenanceRecords(db);
          await db.insert(
            'maintenance_records',
            _legacyMaintenanceRow(id: 1000, amount: 1.0),
          );
          await db.delete('maintenance_records', where: 'id = 1000');
          await db.insert(
            'maintenance_records',
            _legacyMaintenanceRow(id: 1, amount: 2.0),
          );
        },
      ),
    );
    try {
      await DbMigrations.ensureMaintenanceAmountRealDropped(db);

      final seqRows = await db.rawQuery(
        "SELECT name, seq FROM sqlite_sequence "
        "WHERE name LIKE 'maintenance_records%';",
      );
      expect(seqRows, hasLength(1));
      expect(seqRows.single['name'], 'maintenance_records');
      expect((seqRows.single['seq'] as int), greaterThanOrEqualTo(1000));

      final newId = await db.insert(
        'maintenance_records',
        _a4MaintenanceRow(amountFen: 300),
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
        version: 42,
        onCreate: (db, _) async {
          await _createLegacyMaintenanceRecords(db);
          await db.insert(
            'maintenance_records',
            _legacyMaintenanceRow(id: 1, amount: 88.88),
          );
        },
      ),
    );
    try {
      await DbMigrations.ensureMaintenanceAmountRealDropped(db);
      final afterFirst = await db.query('maintenance_records');

      await DbMigrations.ensureMaintenanceAmountRealDropped(db);
      final afterSecond = await db.query('maintenance_records');

      expect(afterSecond, afterFirst);
      expect(await _columnExists(db, 'maintenance_records', 'amount'), isFalse);
    } finally {
      await db.close();
    }
  });
}

Future<void> _createLegacyMaintenanceRecords(DatabaseExecutor db) async {
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

Map<String, Object?> _legacyMaintenanceRow({
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

Map<String, Object?> _a4MaintenanceRow({int? id, required int amountFen}) {
  return {
    'id': id,
    'device_id': 7,
    'ymd': 20260601,
    'item': '换机油',
    'amount_fen': amountFen,
    'note': '定期保养',
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
