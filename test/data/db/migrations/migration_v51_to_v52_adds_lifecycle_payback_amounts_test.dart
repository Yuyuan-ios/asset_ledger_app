import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp(
      'asset_ledger_migration_052_',
    );
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('v51 to v52 adds nullable lifecycle payback amount columns', () async {
    final v51 = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 51,
        onCreate: (db, _) async {
          await db.execute('''
              CREATE TABLE devices (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                brand TEXT NOT NULL,
                model TEXT,
                default_unit_price_fen INTEGER NOT NULL,
                breaking_unit_price_fen INTEGER,
                base_meter_hours REAL NOT NULL,
                is_active INTEGER NOT NULL DEFAULT 1,
                custom_avatar_path TEXT,
                equipment_type TEXT NOT NULL DEFAULT 'excavator'
              );
            ''');
          await db.insert('devices', {
            'id': 1,
            'name': 'SANY 1#',
            'brand': 'SANY',
            'default_unit_price_fen': 38000,
            'base_meter_hours': 0.0,
            'is_active': 1,
            'equipment_type': 'excavator',
          });
        },
      ),
    );
    try {
      expect(
        await _hasColumn(v51, 'devices', 'lifecycle_initial_cost_fen'),
        isFalse,
      );
      expect(
        await _hasColumn(v51, 'devices', 'lifecycle_estimated_residual_fen'),
        isFalse,
      );
    } finally {
      await v51.close();
    }

    final upgraded = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onUpgrade: (db, oldVersion, newVersion) {
          return DbMigrations.apply(db, oldVersion, newVersion);
        },
      ),
    );
    try {
      expect(
        await _hasColumn(upgraded, 'devices', 'lifecycle_initial_cost_fen'),
        isTrue,
      );
      expect(
        await _hasColumn(
          upgraded,
          'devices',
          'lifecycle_estimated_residual_fen',
        ),
        isTrue,
      );

      final row = (await upgraded.query(
        'devices',
        where: 'id = ?',
        whereArgs: [1],
      )).single;
      expect(row['lifecycle_initial_cost_fen'], isNull);
      expect(row['lifecycle_estimated_residual_fen'], isNull);
      expect(row['default_unit_price_fen'], 38000);

      await upgraded.update(
        'devices',
        {
          'lifecycle_initial_cost_fen': 1500000,
          'lifecycle_estimated_residual_fen': 230000,
        },
        where: 'id = ?',
        whereArgs: [1],
      );
      final updated = (await upgraded.query(
        'devices',
        where: 'id = ?',
        whereArgs: [1],
      )).single;
      expect(updated['lifecycle_initial_cost_fen'], 1500000);
      expect(updated['lifecycle_estimated_residual_fen'], 230000);
    } finally {
      await upgraded.close();
    }
  });
}

Future<bool> _hasColumn(
  DatabaseExecutor db,
  String table,
  String column,
) async {
  final columns = await db.rawQuery('PRAGMA table_info($table);');
  return columns.any((c) => c['name'] == column);
}
