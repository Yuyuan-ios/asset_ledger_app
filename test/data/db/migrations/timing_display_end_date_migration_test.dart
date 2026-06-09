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
      'asset_ledger_migration_032_',
    );
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('fresh schema provisions nullable display_end_date column', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      ),
    );
    try {
      final column = await _column(db, 'timing_records', 'display_end_date');
      expect(column, isNotNull);
      expect(_isNullable(column!), isTrue);
    } finally {
      await db.close();
    }
  });

  test(
    'v31 to v32 upgrade adds display_end_date and keeps old rows null',
    () async {
      final v31 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 31,
          onCreate: (db, _) async {
            await _createV31TimingSchema(db);
            await db.insert('timing_records', {
              'id': 1,
              'project_id': 'project:legacy',
              'device_id': 7,
              'start_date': 20260601,
              'allocation_cutoff_date': null,
              'contact': '甲方',
              'site': '一号工地',
              'type': 'rent',
              'start_meter': 100.0,
              'end_meter': 100.0,
              'hours': 0.0,
              'income': 800.0,
              'income_fen': 80000,
              'exclude_from_fuel_eff': 0,
              'is_breaking': 0,
            });
          },
        ),
      );
      await v31.close();

      final upgraded = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onUpgrade: (db, oldVersion, newVersion) {
            return DbMigrations.apply(db, oldVersion, newVersion);
          },
          onOpen: (db) {
            return DbMigrations.ensureTimingDisplayEndDate(db);
          },
        ),
      );
      try {
        expect(
          await _columnExists(upgraded, 'timing_records', 'display_end_date'),
          isTrue,
        );
        final row = (await upgraded.query('timing_records')).single;
        expect(row['display_end_date'], isNull);
        expect(TimingRecord.fromMap(row).displayEndDate, isNull);
      } finally {
        await upgraded.close();
      }
    },
  );

  test('display end ensure is idempotent for drifted timing schema', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => _createV31TimingSchema(db),
      ),
    );
    try {
      expect(
        await _columnExists(db, 'timing_records', 'display_end_date'),
        isFalse,
      );

      await DbMigrations.ensureTimingDisplayEndDate(db);
      await DbMigrations.ensureTimingDisplayEndDate(db);

      expect(
        await _columnExists(db, 'timing_records', 'display_end_date'),
        isTrue,
      );
    } finally {
      await db.close();
    }
  });
}

Future<void> _createV31TimingSchema(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE timing_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      project_id TEXT NOT NULL,
      device_id INTEGER NOT NULL,
      start_date INTEGER NOT NULL,
      allocation_cutoff_date INTEGER,
      contact TEXT NOT NULL,
      site TEXT NOT NULL,
      type TEXT NOT NULL,
      start_meter REAL NOT NULL,
      end_meter REAL NOT NULL,
      hours REAL NOT NULL,
      income REAL NOT NULL,
      income_fen INTEGER,
      exclude_from_fuel_eff INTEGER NOT NULL DEFAULT 0,
      is_breaking INTEGER NOT NULL DEFAULT 0
    );
  ''');
}

Future<Map<String, Object?>?> _column(
  DatabaseExecutor db,
  String tableName,
  String columnName,
) async {
  final rows = await db.rawQuery('PRAGMA table_info($tableName);');
  for (final row in rows) {
    if (row['name'] == columnName) return row;
  }
  return null;
}

Future<bool> _columnExists(
  DatabaseExecutor db,
  String tableName,
  String columnName,
) async {
  return await _column(db, tableName, columnName) != null;
}

bool _isNullable(Map<String, Object?> columnInfo) {
  return ((columnInfo['notnull'] as int?) ?? 0) == 0;
}
