import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// v34：timing_records.income_fen 提升为 INTEGER NOT NULL（重建表）。
///
/// 覆盖：
/// - A fresh schema：income_fen NOT NULL；unit / quantity_scaled 仍 nullable；
///   income REAL 仍 NOT NULL。
/// - B v33 漂移（income_fen nullable + 残留 NULL）经 onOpen ensure 重建：
///   NOT NULL、COALESCE 兜底、行数/原值无丢失、unit/quantity 同车回填、
///   **timing_calculation_history 子表行存活**（非叶子表重建的核心风险）、
///   FK RESTRICT 与 idx_timing_records_project 仍在。
/// - C 坑A：AUTOINCREMENT 历史高水位不倒退、无 timing_records_v34 残留序列行。
/// - D 幂等：第二次 ensure no-op，数据与高水位不被破坏。
/// - E FK RESTRICT：重建后孤儿 project_id 插入失败。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('timing_fen_notnull_');
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('A: fresh schema enforces income_fen NOT NULL, keeps mirrors nullable',
      () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      ),
    );
    try {
      expect(await _isNotNull(db, 'timing_records', 'income_fen'), isTrue);
      expect(await _isNotNull(db, 'timing_records', 'income'), isTrue);
      expect(await _isNotNull(db, 'timing_records', 'unit'), isFalse);
      expect(
        await _isNotNull(db, 'timing_records', 'quantity_scaled'),
        isFalse,
      );
    } finally {
      await db.close();
    }
  });

  test(
    'B: drifted v33 schema is rebuilt by onOpen ensure without losing rows '
    'or calculation history children',
    () async {
      final seeded = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 33,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (db, _) async {
            await _createV33Substrate(db);
            // 残留 NULL income_fen 的 legacy 行 + 已落 fen 的行。
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
              'income': 2850.0,
              'income_fen': null,
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
              'unit': 'RENT',
              'quantity_scaled': null,
              'exclude_from_fuel_eff': 1,
              'is_breaking': 0,
            });
            // 子表行：重建期间若 FK 级联生效会被清空——必须存活。
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
            return DbMigrations.ensureTimingIncomeFenNotNull(db);
          },
        ),
      );
      try {
        expect(
          await _isNotNull(upgraded, 'timing_records', 'income_fen'),
          isTrue,
        );

        final rows = await upgraded.query('timing_records', orderBy: 'id');
        expect(rows, hasLength(2));

        final legacy = rows.first;
        // COALESCE 兜底：round(2850.0 * 100)。
        expect(legacy['income_fen'], 285000);
        // 重建顺带回填 v33 镜像。
        expect(legacy['unit'], 'HOUR');
        expect(legacy['quantity_scaled'], 7500);
        expect(legacy['income'], 2850.0);
        expect(legacy['hours'], 7.5);

        final stored = rows.last;
        expect(stored['income_fen'], 80000);
        expect(stored['unit'], 'RENT');
        expect(stored['quantity_scaled'], isNull);
        expect(stored['exclude_from_fuel_eff'], 1);

        // 子表行存活，FK 链接仍可用。
        final children = await upgraded.query('timing_calculation_history');
        expect(children, hasLength(1));
        expect(children.single['timing_record_id'], 1);

        // 索引与 FK 仍在。
        expect(
          await _indexExists(upgraded, 'idx_timing_records_project'),
          isTrue,
        );
        expect(
          await _hasProjectForeignKey(upgraded, 'timing_records'),
          isTrue,
        );
      } finally {
        await upgraded.close();
      }
    },
  );

  test('C: AUTOINCREMENT high-water mark survives the rebuild (pit A)',
      () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 33,
        onCreate: (db, _) async {
          await _createV33Substrate(db);
          // 插入高 id 再删除,制造 old_seq(1000) > MAX(id)(1) 的历史高水位。
          await db.insert('timing_records', _hoursRow(id: 1000));
          await db.delete('timing_records', where: 'id = 1000');
          await db.insert('timing_records', _hoursRow(id: 1));
        },
      ),
    );

    await DbMigrations.ensureTimingIncomeFenNotNull(db);

    try {
      final seqRows = await db.rawQuery(
        "SELECT name, seq FROM sqlite_sequence WHERE name LIKE 'timing_records%';",
      );
      expect(seqRows, hasLength(1));
      expect(seqRows.single['name'], 'timing_records');
      expect((seqRows.single['seq'] as int), greaterThanOrEqualTo(1000));

      // 新行拿到的 id 必须越过历史高水位,不复用已删除区间。
      final newId = await db.insert('timing_records', _hoursRow());
      expect(newId, greaterThan(1000));
    } finally {
      await db.close();
    }
  });

  test('D: ensure is idempotent after a real rebuild', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 33,
        onCreate: (db, _) async {
          await _createV33Substrate(db);
          await db.insert('timing_records', _hoursRow(id: 1));
        },
      ),
    );
    try {
      await DbMigrations.ensureTimingIncomeFenNotNull(db);
      final afterFirst = await db.query('timing_records');

      await DbMigrations.ensureTimingIncomeFenNotNull(db);
      final afterSecond = await db.query('timing_records');

      expect(afterSecond, afterFirst);
      expect(await _isNotNull(db, 'timing_records', 'income_fen'), isTrue);
    } finally {
      await db.close();
    }
  });

  test('E: FK RESTRICT still rejects orphan project ids after rebuild',
      () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 33,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, _) async {
          await _createV33Substrate(db);
        },
      ),
    );
    try {
      await DbMigrations.ensureTimingIncomeFenNotNull(db);

      await expectLater(
        db.insert('timing_records', _hoursRow(projectId: 'project:orphan')),
        throwsA(isA<DatabaseException>()),
      );
    } finally {
      await db.close();
    }
  });
}

/// v33 基底：projects + timing_records(income_fen nullable) + 子表。
Future<void> _createV33Substrate(DatabaseExecutor db) async {
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

Map<String, Object?> _hoursRow({int? id, String projectId = 'project:a'}) {
  return {
    'id': ?id,
    'project_id': projectId,
    'device_id': 7,
    'start_date': 20260601,
    'contact': '甲方',
    'site': '一号工地',
    'type': 'hours',
    'start_meter': 0.0,
    'end_meter': 1.0,
    'hours': 1.0,
    'income': 0.0,
    'income_fen': 0,
    'exclude_from_fuel_eff': 0,
    'is_breaking': 0,
  };
}

Future<bool> _isNotNull(Database db, String table, String column) async {
  final rows = await db.rawQuery('PRAGMA table_info($table);');
  for (final row in rows) {
    if (row['name'] == column) return ((row['notnull'] as int?) ?? 0) == 1;
  }
  return false;
}

Future<bool> _indexExists(Database db, String name) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?;",
    [name],
  );
  return rows.isNotEmpty;
}

Future<bool> _hasProjectForeignKey(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA foreign_key_list($table);');
  return rows.any(
    (row) => row['table'] == 'projects' && row['from'] == 'project_id',
  );
}
