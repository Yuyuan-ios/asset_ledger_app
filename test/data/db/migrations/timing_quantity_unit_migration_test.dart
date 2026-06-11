import 'dart:io';

import 'package:asset_ledger/core/measure/measure_unit.dart';
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
      'asset_ledger_migration_033_',
    );
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('fresh schema provisions nullable unit and quantity_scaled', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      ),
    );
    try {
      final unitColumn = await _column(db, 'timing_records', 'unit');
      expect(unitColumn, isNotNull);
      expect(_isNullable(unitColumn!), isTrue);
      final quantityColumn = await _column(
        db,
        'timing_records',
        'quantity_scaled',
      );
      expect(quantityColumn, isNotNull);
      expect(_isNullable(quantityColumn!), isTrue);
    } finally {
      await db.close();
    }
  });

  test(
    'v32 to v33 upgrade backfills unit by type and quantity by hours',
    () async {
      final v32 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 32,
          onCreate: (db, _) async {
            await _createV32TimingSchema(db);
            await db.insert('timing_records', {
              'id': 1,
              'project_id': 'project:hours',
              'device_id': 7,
              'start_date': 20260601,
              'contact': '甲方',
              'site': '一号工地',
              'type': 'hours',
              'start_meter': 100.0,
              'end_meter': 107.5,
              'hours': 7.5,
              'income': 0.0,
              'income_fen': 0,
              'exclude_from_fuel_eff': 0,
              'is_breaking': 0,
            });
            await db.insert('timing_records', {
              'id': 2,
              'project_id': 'project:rent',
              'device_id': 7,
              'start_date': 20260601,
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
      await v32.close();

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
        final rows = await upgraded.query('timing_records', orderBy: 'id');
        expect(rows, hasLength(2));

        final hoursRow = rows.first;
        expect(hoursRow['unit'], 'HOUR');
        expect(hoursRow['quantity_scaled'], 7500);
        final hoursRecord = TimingRecord.fromMap(hoursRow);
        expect(hoursRecord.unit, MeasureUnit.hour);
        expect(hoursRecord.quantityScaled, 7500);

        final rentRow = rows.last;
        expect(rentRow['unit'], 'RENT');
        expect(rentRow['quantity_scaled'], isNull);
        final rentRecord = TimingRecord.fromMap(rentRow);
        expect(rentRecord.unit, MeasureUnit.rent);
        expect(rentRecord.quantityScaled, isNull);
      } finally {
        await upgraded.close();
      }
    },
  );

  test('quantity unit ensure is idempotent and never clobbers stored values',
      () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => _createV32TimingSchema(db),
      ),
    );
    try {
      expect(await _columnExists(db, 'timing_records', 'unit'), isFalse);

      await DbMigrations.ensureTimingQuantityUnit(db);
      await DbMigrations.ensureTimingQuantityUnit(db);

      expect(await _columnExists(db, 'timing_records', 'unit'), isTrue);
      expect(
        await _columnExists(db, 'timing_records', 'quantity_scaled'),
        isTrue,
      );

      // 已落非 NULL 值的行再次 ensure 不被覆盖。
      await db.insert('timing_records', {
        'id': 5,
        'project_id': 'project:stored',
        'device_id': 1,
        'start_date': 20260601,
        'contact': 'A',
        'site': 'B',
        'type': 'hours',
        'start_meter': 0.0,
        'end_meter': 1.0,
        'hours': 1.0,
        'income': 0.0,
        'income_fen': 0,
        'unit': 'SHIFT',
        'quantity_scaled': 2000,
        'exclude_from_fuel_eff': 0,
        'is_breaking': 0,
      });
      await DbMigrations.ensureTimingQuantityUnit(db);
      final stored = (await db.query(
        'timing_records',
        where: 'id = 5',
      )).single;
      expect(stored['unit'], 'SHIFT');
      expect(stored['quantity_scaled'], 2000);
    } finally {
      await db.close();
    }
  });
}

Future<void> _createV32TimingSchema(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE timing_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      project_id TEXT NOT NULL,
      device_id INTEGER NOT NULL,
      start_date INTEGER NOT NULL,
      allocation_cutoff_date INTEGER,
      display_end_date INTEGER,
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
