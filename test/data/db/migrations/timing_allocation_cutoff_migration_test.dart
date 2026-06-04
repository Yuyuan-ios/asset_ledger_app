import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
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
      'asset_ledger_migration_025_',
    );
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test(
    'fresh create at current schema version provisions allocation cutoff column',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onCreate: (db, _) => DbSchema.create(db),
        ),
      );
      try {
        expect(
          await _columnExists(db, 'timing_records', 'allocation_cutoff_date'),
          isTrue,
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'v24 to current upgrade adds allocation cutoff column and keeps old rows null',
    () async {
      final v24 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 24,
          onCreate: (db, _) async {
            await _createV24TimingSchema(db);
            await db.insert('timing_records', {
              'id': 1,
              'project_id': 'project:legacy',
              'device_id': 7,
              'start_date': 20260601,
              'contact': '甲方',
              'site': '一号工地',
              'type': 'hours',
              'start_meter': 100.0,
              'end_meter': 108.0,
              'hours': 8.0,
              'income': 800.0,
              'exclude_from_fuel_eff': 0,
              'is_breaking': 0,
            });
          },
        ),
      );
      await v24.close();

      final upgraded = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onUpgrade: (db, oldVersion, newVersion) {
            return DbMigrations.apply(db, oldVersion, newVersion);
          },
          onOpen: (db) {
            return DbMigrations.ensureTimingAllocationCutoffDate(db);
          },
        ),
      );
      try {
        expect(
          await _columnExists(
            upgraded,
            'timing_records',
            'allocation_cutoff_date',
          ),
          isTrue,
        );

        final row = (await upgraded.query('timing_records')).single;
        expect(row['allocation_cutoff_date'], isNull);
        expect(TimingRecord.fromMap(row).allocationCutoffDate, isNull);
      } finally {
        await upgraded.close();
      }
    },
  );

  test(
    'allocation cutoff ensure is idempotent for drifted timing schema',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onCreate: (db, _) => _createV24TimingSchema(db),
        ),
      );
      try {
        expect(
          await _columnExists(db, 'timing_records', 'allocation_cutoff_date'),
          isFalse,
        );

        await DbMigrations.ensureTimingAllocationCutoffDate(db);
        await DbMigrations.ensureTimingAllocationCutoffDate(db);

        expect(
          await _columnExists(db, 'timing_records', 'allocation_cutoff_date'),
          isTrue,
        );
      } finally {
        await db.close();
      }
    },
  );
}

Future<void> _createV24TimingSchema(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE timing_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      project_id TEXT NOT NULL,
      device_id INTEGER NOT NULL,
      start_date INTEGER NOT NULL,
      contact TEXT NOT NULL,
      site TEXT NOT NULL,
      type TEXT NOT NULL,
      start_meter REAL NOT NULL,
      end_meter REAL NOT NULL,
      hours REAL NOT NULL,
      income REAL NOT NULL,
      exclude_from_fuel_eff INTEGER NOT NULL DEFAULT 0,
      is_breaking INTEGER NOT NULL DEFAULT 0
    );
  ''');
}

Future<bool> _columnExists(
  DatabaseExecutor db,
  String tableName,
  String columnName,
) async {
  final rows = await db.rawQuery('PRAGMA table_info($tableName);');
  return rows.any((row) => row['name'] == columnName);
}
