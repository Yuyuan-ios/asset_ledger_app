import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// v36：timing_records.unit 提升为 TEXT NOT NULL（重建表，S2 schema 权威）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('timing_unit_notnull_');
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('fresh schema enforces unit NOT NULL, quantity stays nullable',
      () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      ),
    );
    try {
      expect(await _isNotNull(db, 'timing_records', 'unit'), isTrue);
      expect(
        await _isNotNull(db, 'timing_records', 'quantity_scaled'),
        isFalse,
      );
      expect(await _isNotNull(db, 'timing_records', 'income_fen'), isTrue);
    } finally {
      await db.close();
    }
  });

  test(
    'drifted v35 schema is rebuilt by onOpen ensure without losing rows, '
    'children, or stored units',
    () async {
      final seeded = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 35,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (db, _) async {
            await _createV35Substrate(db);
            // 残留 NULL unit 的 legacy 行（hours / rent 各一）。
            await db.insert('timing_records', {
              'id': 1,
              'project_id': 'project:a',
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
              'unit': null,
              'quantity_scaled': null,
              'exclude_from_fuel_eff': 0,
              'is_breaking': 0,
            });
            await db.insert('timing_records', {
              'id': 2,
              'project_id': 'project:a',
              'device_id': 7,
              'start_date': 20260602,
              'contact': '甲方',
              'site': '一号工地',
              'type': 'rent',
              'start_meter': 0.0,
              'end_meter': 0.0,
              'hours': 0.0,
              'income': 800.0,
              'income_fen': 80000,
              'unit': null,
              'quantity_scaled': null,
              'exclude_from_fuel_eff': 0,
              'is_breaking': 0,
            });
            // 已落非 HOUR 存储值的行：重建不得改写。
            await db.insert('timing_records', {
              'id': 3,
              'project_id': 'project:a',
              'device_id': 7,
              'start_date': 20260603,
              'contact': '甲方',
              'site': '一号工地',
              'type': 'hours',
              'start_meter': 0.0,
              'end_meter': 0.0,
              'hours': 1.5,
              'income': 0.0,
              'income_fen': 0,
              'unit': 'SHIFT',
              'quantity_scaled': 1500,
              'exclude_from_fuel_eff': 0,
              'is_breaking': 0,
            });
            await db.insert('timing_calculation_history', {
              'id': 'calc-1',
              'timing_record_id': 1,
              'created_at': '2026-06-01T00:00:00Z',
              'expression': '3+4.5',
              'result': 7.5,
              'ticket_count': 2,
            });
          },
        ),
      );
      await seeded.close();

      final upgraded = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onUpgrade: (db, oldVersion, newVersion) {
            return DbMigrations.apply(db, oldVersion, newVersion);
          },
          onOpen: (db) {
            return DbMigrations.ensureTimingUnitNotNull(db);
          },
        ),
      );
      try {
        expect(await _isNotNull(upgraded, 'timing_records', 'unit'), isTrue);

        final rows = await upgraded.query('timing_records', orderBy: 'id');
        expect(rows, hasLength(3));
        expect(rows[0]['unit'], 'HOUR');
        expect(rows[0]['quantity_scaled'], 7500);
        expect(rows[1]['unit'], 'RENT');
        expect(rows[1]['quantity_scaled'], isNull, reason: 'rent 行 NULL 合法');
        expect(rows[2]['unit'], 'SHIFT', reason: '存储值不被回填改写');
        expect(rows[2]['quantity_scaled'], 1500);

        // 子表行存活（非叶子表重建的核心风险）。
        final children = await upgraded.query('timing_calculation_history');
        expect(children, hasLength(1));

        expect(
          await _hasProjectForeignKey(upgraded, 'timing_records'),
          isTrue,
        );
      } finally {
        await upgraded.close();
      }
    },
  );

  test('ensure is idempotent after a real rebuild', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 35,
        onCreate: (db, _) async {
          await _createV35Substrate(db);
        },
      ),
    );
    try {
      await DbMigrations.ensureTimingUnitNotNull(db);
      await DbMigrations.ensureTimingUnitNotNull(db);
      expect(await _isNotNull(db, 'timing_records', 'unit'), isTrue);

      // NOT NULL 由 schema 强制：缺 unit 的裸插入被拒绝。
      await expectLater(
        db.insert('timing_records', {
          'project_id': 'project:a',
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
          'exclude_from_fuel_eff': 0,
          'is_breaking': 0,
        }),
        throwsA(isA<DatabaseException>()),
      );
    } finally {
      await db.close();
    }
  });
}

/// v35 基底：unit nullable 的 timing_records + projects + 子表。
Future<void> _createV35Substrate(DatabaseExecutor db) async {
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
  await db.insert('projects', {
    'id': 'project:a',
    'contact': '甲方',
    'site': '一号工地',
    'status': 'active',
    'created_at': '2026-06-01T00:00:00Z',
    'updated_at': '2026-06-01T00:00:00Z',
  });
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
      income_fen INTEGER NOT NULL,
      unit TEXT,
      quantity_scaled INTEGER,
      exclude_from_fuel_eff INTEGER NOT NULL DEFAULT 0,
      is_breaking INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (project_id)
        REFERENCES projects(id) ON DELETE RESTRICT
    );
  ''');
  await db.execute('''
    CREATE TABLE timing_calculation_history (
      id TEXT PRIMARY KEY,
      timing_record_id INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      expression TEXT NOT NULL,
      result REAL NOT NULL,
      ticket_count INTEGER NOT NULL,
      FOREIGN KEY (timing_record_id)
        REFERENCES timing_records(id) ON DELETE CASCADE
    );
  ''');
}

Future<bool> _isNotNull(Database db, String table, String column) async {
  final rows = await db.rawQuery('PRAGMA table_info($table);');
  for (final row in rows) {
    if (row['name'] == column) return ((row['notnull'] as int?) ?? 0) == 1;
  }
  return false;
}

Future<bool> _hasProjectForeignKey(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA foreign_key_list($table);');
  return rows.any(
    (row) => row['table'] == 'projects' && row['from'] == 'project_id',
  );
}
