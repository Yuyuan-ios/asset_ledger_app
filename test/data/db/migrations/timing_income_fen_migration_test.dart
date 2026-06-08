import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// R5.26-B3：timing_records.income_fen additive 迁移 + 回填不变式。
///
/// 覆盖：
/// - 旧库缺 income_fen 列 → 经迁移链 + onOpen ensure 后列存在(INTEGER nullable)、
///   旧行保留、income_fen == round(income*100)、income REAL 仍在、浮点敏感值正确。
/// - 当前版本库 income_fen 列在但值为 NULL → ensure 自愈。
/// - 回填只填 NULL、不覆盖既有非 NULL income_fen，且幂等。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('timing_income_fen_');
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test(
    'fresh create at current schema version provisions income_fen column',
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
          await _columnExists(db, 'timing_records', 'income_fen'),
          isTrue,
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'legacy db without income_fen backfills non-null mirror after upgrade + '
    'onOpen ensure, keeping income REAL and all rows',
    () async {
      // 1) 旧库：timing_records 无 income_fen（保留 allocation_cutoff_date 以贴近
      //    v25-v28 形态），插入多行含浮点敏感金额。
      final legacy = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 28,
          onCreate: (db, _) async {
            await _createTimingSchemaWithoutIncomeFen(db);
            await db.insert('timing_records', _timingRow(id: 1, income: 200.0));
            await db.insert('timing_records', _timingRow(id: 2, income: 0.1));
            await db.insert('timing_records', _timingRow(id: 3, income: 19.99));
            await db.insert(
              'timing_records',
              _timingRow(id: 4, income: 1200.0, type: 'rent'),
            );
          },
        ),
      );
      expect(
        await _columnExists(legacy, 'timing_records', 'income_fen'),
        isFalse,
      );
      await legacy.close();

      // 2) 用迁移链 + onOpen ensure（生产 DbSchemaCompat.ensure 调的同一函数）开库。
      final db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onUpgrade: DbMigrations.apply,
          onOpen: (db) => DbMigrations.ensureTimingIncomeFen(db),
        ),
      );
      try {
        expect(
          await _columnExists(db, 'timing_records', 'income_fen'),
          isTrue,
        );
        // 无 NULL 残留 + 行数无丢失。
        expect(await _nullIncomeFenCount(db), 0);
        expect(await _rowCount(db, 'timing_records'), 4);

        // 逐行 income_fen == round(income*100)，income REAL 仍为原值。
        final rows = await db.query('timing_records', orderBy: 'id ASC');
        for (final row in rows) {
          final income = (row['income'] as num).toDouble();
          expect(
            (row['income_fen'] as num?)?.toInt(),
            (income * 100).round(),
            reason: 'row ${row['id']} income_fen 应 == round(income*100)',
          );
        }
        // 浮点敏感值精确回填。
        expect((await _rowById(db, 2))['income_fen'], 10); // 0.1
        expect((await _rowById(db, 3))['income_fen'], 1999); // 19.99
        expect((await _rowById(db, 4))['income_fen'], 120000); // 1200.0
        // fromMap 能正确还原。
        expect(TimingRecord.fromMap(await _rowById(db, 1)).incomeFen, 20000);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'current-version db with NULL income_fen is healed by ensureTimingIncomeFen',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onCreate: (db, _) async {
            // 当前 schema（含 income_fen 列），但插入 income_fen 显式 NULL。
            await _createTimingSchemaWithIncomeFen(db);
            await db.insert(
              'timing_records',
              _timingRow(id: 1, income: 88.8, incomeFen: null),
            );
          },
        ),
      );
      try {
        expect(await _nullIncomeFenCount(db), 1);
        await DbMigrations.ensureTimingIncomeFen(db);
        expect(await _nullIncomeFenCount(db), 0);
        expect((await _rowById(db, 1))['income_fen'], 8880);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'income_fen backfill fills only NULL and never clobbers, and is idempotent',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onCreate: (db, _) async {
            await _createTimingSchemaWithIncomeFen(db);
            // NULL 行待回填。
            await db.insert(
              'timing_records',
              _timingRow(id: 1, income: 50.0, incomeFen: null),
            );
            // 故意不一致的非 NULL 行：必须保留。
            await db.insert(
              'timing_records',
              _timingRow(id: 2, income: 100.0, incomeFen: 1),
            );
          },
        ),
      );
      try {
        await DbMigrations.ensureTimingIncomeFen(db);
        await DbMigrations.ensureTimingIncomeFen(db);

        expect(await _nullIncomeFenCount(db), 0);
        expect((await _rowById(db, 1))['income_fen'], 5000);
        expect(
          (await _rowById(db, 2))['income_fen'],
          1,
          reason: '既有非 NULL income_fen 不应被回填覆盖',
        );
      } finally {
        await db.close();
      }
    },
  );
}

// ===========================================================================
// Helpers
// ===========================================================================

/// v25-v28 形态：含 allocation_cutoff_date，但无 income_fen。无 FK 以便独立插入。
Future<void> _createTimingSchemaWithoutIncomeFen(DatabaseExecutor db) async {
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
      exclude_from_fuel_eff INTEGER NOT NULL DEFAULT 0,
      is_breaking INTEGER NOT NULL DEFAULT 0
    );
  ''');
}

/// 当前 schema 形态（含 income_fen）。无 FK 以便独立插入。
Future<void> _createTimingSchemaWithIncomeFen(DatabaseExecutor db) async {
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

Map<String, Object?> _timingRow({
  required int id,
  required double income,
  String type = 'hours',
  Object? incomeFen = _absent,
}) {
  final row = <String, Object?>{
    'id': id,
    'project_id': 'project:legacy',
    'device_id': 7,
    'start_date': 20260601,
    'contact': '甲方',
    'site': '一号工地',
    'type': type,
    'start_meter': 100.0,
    'end_meter': 108.0,
    'hours': 8.0,
    'income': income,
    'exclude_from_fuel_eff': 0,
    'is_breaking': 0,
  };
  if (!identical(incomeFen, _absent)) {
    row['income_fen'] = incomeFen;
  }
  return row;
}

const Object _absent = Object();

Future<bool> _columnExists(
  DatabaseExecutor db,
  String table,
  String column,
) async {
  final rows = await db.rawQuery('PRAGMA table_info($table);');
  return rows.any((row) => row['name'] == column);
}

Future<int> _nullIncomeFenCount(DatabaseExecutor db) async {
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS c FROM timing_records WHERE income_fen IS NULL',
  );
  return (rows.single['c'] as num?)?.toInt() ?? 0;
}

Future<int> _rowCount(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
  return (rows.single['c'] as num?)?.toInt() ?? 0;
}

Future<Map<String, Object?>> _rowById(DatabaseExecutor db, int id) async {
  return (await db.query(
    'timing_records',
    where: 'id = ?',
    whereArgs: [id],
  )).single;
}
