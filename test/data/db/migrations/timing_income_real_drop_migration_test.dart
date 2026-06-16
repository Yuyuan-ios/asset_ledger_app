import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// Track A / A4-7：timing_records.income REAL 拆除。
///
/// timing_records 非叶子表，onUpgrade 不重建；onOpen ensure 才能在事务外关闭
/// FK 后重建，避免 timing_calculation_history 被级联清空。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('timing_income_drop_');
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('fresh schema is income_fen-only for timing_records', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      ),
    );
    try {
      expect(await _columnExists(db, 'timing_records', 'income'), isFalse);
      expect(await _isNotNull(db, 'timing_records', 'income_fen'), isTrue);
      expect(await _isNotNull(db, 'timing_records', 'unit'), isTrue);
    } finally {
      await db.close();
    }
  });

  test(
    'onUpgrade alone does not rebuild the non-leaf timing_records table',
    () async {
      final seeded = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 47,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (db, _) async {
            await _createLegacyTimingSchema(db);
            await db.insert('timing_records', _legacyHoursRow(id: 1));
            await db.insert('timing_calculation_history', _historyRow());
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
        ),
      );
      try {
        expect(
          await _columnExists(upgraded, 'timing_records', 'income'),
          isTrue,
        );
        final children = await upgraded.query('timing_calculation_history');
        expect(children, hasLength(1));
      } finally {
        await upgraded.close();
      }
    },
  );

  test(
    'onOpen ensure drops income REAL, backfills fen, and keeps child history',
    () async {
      final seeded = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 47,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (db, _) async {
            await _createLegacyTimingSchema(db);
            await db.insert(
              'timing_records',
              _legacyHoursRow(id: 1, income: 19.99, incomeFen: null),
            );
            await db.insert(
              'timing_records',
              _legacyHoursRow(id: 2, income: 88.8, incomeFen: 8881),
            );
            await db.insert('timing_calculation_history', _historyRow());
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
            return DbMigrations.ensureTimingIncomeRealDropped(db);
          },
        ),
      );
      try {
        expect(
          await _columnExists(upgraded, 'timing_records', 'income'),
          isFalse,
        );
        expect(
          await _isNotNull(upgraded, 'timing_records', 'income_fen'),
          isTrue,
        );

        final rows = await upgraded.query('timing_records', orderBy: 'id');
        expect(rows, hasLength(2));
        expect(rows.first['income_fen'], 1999);
        expect(rows.last['income_fen'], 8881);
        expect(rows.first['unit'], 'HOUR');
        expect(rows.first['quantity_scaled'], 1000);

        final children = await upgraded.query('timing_calculation_history');
        expect(children, hasLength(1));
        expect(children.single['timing_record_id'], 1);

        expect(
          await _indexExists(upgraded, 'idx_timing_records_project'),
          isTrue,
        );
        expect(await _hasProjectForeignKey(upgraded, 'timing_records'), isTrue);
      } finally {
        await upgraded.close();
      }
    },
  );

  test('AUTOINCREMENT high-water mark survives the v48 rebuild', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 47,
        onCreate: (db, _) async {
          await _createLegacyTimingSchema(db);
          await db.insert('timing_records', _legacyHoursRow(id: 1000));
          await db.delete('timing_records', where: 'id = 1000');
          await db.insert('timing_records', _legacyHoursRow(id: 1));
        },
      ),
    );
    try {
      await DbMigrations.ensureTimingIncomeRealDropped(db);

      final seqRows = await db.rawQuery(
        "SELECT name, seq FROM sqlite_sequence WHERE name LIKE 'timing_records%';",
      );
      expect(seqRows, hasLength(1));
      expect(seqRows.single['name'], 'timing_records');
      expect((seqRows.single['seq'] as int), greaterThanOrEqualTo(1000));

      final newId = await db.insert('timing_records', _currentHoursRow());
      expect(newId, greaterThan(1000));
    } finally {
      await db.close();
    }
  });

  test('ensure is idempotent after income REAL has been dropped', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 47,
        onCreate: (db, _) async {
          await _createLegacyTimingSchema(db);
          await db.insert('timing_records', _legacyHoursRow(id: 1));
        },
      ),
    );
    try {
      await DbMigrations.ensureTimingIncomeRealDropped(db);
      final afterFirst = await db.query('timing_records');

      await DbMigrations.ensureTimingIncomeRealDropped(db);
      final afterSecond = await db.query('timing_records');

      expect(afterSecond, afterFirst);
      expect(await _columnExists(db, 'timing_records', 'income'), isFalse);
    } finally {
      await db.close();
    }
  });
}

Future<void> _createLegacyTimingSchema(DatabaseExecutor db) async {
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
      income_fen INTEGER,
      unit TEXT,
      quantity_scaled INTEGER,
      exclude_from_fuel_eff INTEGER NOT NULL DEFAULT 0,
      is_breaking INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (project_id)
        REFERENCES projects(id) ON DELETE RESTRICT
    );
  ''');
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_timing_records_project
    ON timing_records(project_id);
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

Map<String, Object?> _legacyHoursRow({
  int? id,
  double income = 0,
  int? incomeFen = 0,
}) {
  return {
    'id': ?id,
    'project_id': 'project:a',
    'device_id': 7,
    'start_date': 20260601,
    'contact': '甲方',
    'site': '一号工地',
    'type': 'hours',
    'start_meter': 0.0,
    'end_meter': 1.0,
    'hours': 1.0,
    'income': income,
    'income_fen': incomeFen,
    'unit': null,
    'quantity_scaled': null,
    'exclude_from_fuel_eff': 0,
    'is_breaking': 0,
  };
}

Map<String, Object?> _currentHoursRow() {
  return {
    'project_id': 'project:a',
    'device_id': 7,
    'start_date': 20260602,
    'contact': '甲方',
    'site': '一号工地',
    'type': 'hours',
    'start_meter': 1.0,
    'end_meter': 2.0,
    'hours': 1.0,
    'income_fen': 0,
    'unit': 'HOUR',
    'quantity_scaled': 1000,
    'exclude_from_fuel_eff': 0,
    'is_breaking': 0,
  };
}

Map<String, Object?> _historyRow() {
  return {
    'id': 'calc-1',
    'timing_record_id': 1,
    'created_at': '2026-06-01T00:00:00Z',
    'expression': '1',
    'result': 1.0,
    'ticket_count': 1,
  };
}

Future<bool> _columnExists(DatabaseExecutor db, String table, String column) {
  return db
      .rawQuery('PRAGMA table_info($table);')
      .then((rows) => rows.any((row) => row['name'] == column));
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

Future<bool> _indexExists(DatabaseExecutor db, String name) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?;",
    [name],
  );
  return rows.isNotEmpty;
}

Future<bool> _hasProjectForeignKey(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery('PRAGMA foreign_key_list($table);');
  return rows.any(
    (row) => row['table'] == 'projects' && row['from'] == 'project_id',
  );
}
