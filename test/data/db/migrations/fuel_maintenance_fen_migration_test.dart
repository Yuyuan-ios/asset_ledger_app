import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/data/models/maintenance_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// Track A / A1：fuel_logs.cost_fen + maintenance_records.amount_fen additive
/// 迁移（v37）+ 回填不变式。
///
/// 覆盖：
/// - 当前版本 fresh create → 两列存在（INTEGER nullable）。
/// - 旧 v36 库缺 fen 列 → 经迁移链升级后列存在、旧行保留、
///   fen == round(x*100)、REAL 仍在、浮点敏感值精确。
/// - 当前版本库 fen 为 NULL → onOpen ensure 自愈。
/// - 回填只填 NULL、不覆盖既有非 NULL、幂等。
/// - 模型 toMap 双写 fen / fromMap 读回。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('fuel_maint_fen_');
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('fresh create at current schema provisions fen columns', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      ),
    );
    try {
      expect(await _columnExists(db, 'fuel_logs', 'cost_fen'), isTrue);
      expect(
        await _columnExists(db, 'maintenance_records', 'amount_fen'),
        isTrue,
      );
    } finally {
      await db.close();
    }
  });

  test(
    'legacy v36 db without fen columns backfills after upgrade, keeping REAL '
    'and all rows',
    () async {
      final legacy = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 36,
          onCreate: (db, _) async {
            await _createLegacyFuelMaintenance(db);
            await db.insert('fuel_logs', _fuelRow(id: 1, cost: 200.0));
            await db.insert('fuel_logs', _fuelRow(id: 2, cost: 0.1));
            await db.insert('fuel_logs', _fuelRow(id: 3, cost: 19.99));
            await db.insert('maintenance_records', _maintRow(id: 1, amount: 50.0));
            await db.insert(
              'maintenance_records',
              _maintRow(id: 2, amount: 1234.56),
            );
          },
        ),
      );
      expect(await _columnExists(legacy, 'fuel_logs', 'cost_fen'), isFalse);
      await legacy.close();

      final db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onUpgrade: DbMigrations.apply,
          onOpen: (db) => DbMigrations.ensureFuelMaintenanceMoneyFen(db),
        ),
      );
      try {
        expect(await _columnExists(db, 'fuel_logs', 'cost_fen'), isTrue);
        expect(
          await _columnExists(db, 'maintenance_records', 'amount_fen'),
          isTrue,
        );
        expect(await _nullCount(db, 'fuel_logs', 'cost_fen'), 0);
        expect(await _nullCount(db, 'maintenance_records', 'amount_fen'), 0);
        expect(await _rowCount(db, 'fuel_logs'), 3);
        expect(await _rowCount(db, 'maintenance_records'), 2);

        // 逐行 fen == round(REAL*100)，REAL 仍为原值。
        for (final row in await db.query('fuel_logs')) {
          final cost = (row['cost'] as num).toDouble();
          expect((row['cost_fen'] as num?)?.toInt(), (cost * 100).round());
        }
        // 浮点敏感值精确。
        expect((await _row(db, 'fuel_logs', 2))['cost_fen'], 10); // 0.1
        expect((await _row(db, 'fuel_logs', 3))['cost_fen'], 1999); // 19.99
        expect(
          (await _row(db, 'maintenance_records', 2))['amount_fen'],
          123456,
        ); // 1234.56

        // 模型能正确还原 fen。
        expect(FuelLog.fromMap(await _row(db, 'fuel_logs', 1)).costFen, 20000);
        expect(
          MaintenanceRecord.fromMap(
            await _row(db, 'maintenance_records', 1),
          ).amountFen,
          5000,
        );
      } finally {
        await db.close();
      }
    },
  );

  test('null fen on current-version db is healed by ensure, idempotently', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      ),
    );
    try {
      // 显式写入 NULL fen（绕过模型双写）。
      await db.insert('fuel_logs', {
        ..._fuelRow(id: 1, cost: 88.8),
        'cost_fen': null,
      });
      // 故意不一致的非 NULL 行：必须保留。
      await db.insert('fuel_logs', {
        ..._fuelRow(id: 2, cost: 100.0),
        'cost_fen': 1,
      });
      expect(await _nullCount(db, 'fuel_logs', 'cost_fen'), 1);

      await DbMigrations.ensureFuelMaintenanceMoneyFen(db);
      await DbMigrations.ensureFuelMaintenanceMoneyFen(db);

      expect(await _nullCount(db, 'fuel_logs', 'cost_fen'), 0);
      expect((await _row(db, 'fuel_logs', 1))['cost_fen'], 8880);
      expect(
        (await _row(db, 'fuel_logs', 2))['cost_fen'],
        1,
        reason: '既有非 NULL 不应被回填覆盖',
      );
    } finally {
      await db.close();
    }
  });
}

// ===========================================================================
// Helpers
// ===========================================================================

Future<void> _createLegacyFuelMaintenance(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE fuel_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id INTEGER NOT NULL,
      date INTEGER NOT NULL,
      supplier TEXT NOT NULL,
      liters REAL NOT NULL,
      cost REAL NOT NULL
    );
  ''');
  await db.execute('''
    CREATE TABLE maintenance_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id INTEGER,
      ymd INTEGER NOT NULL,
      item TEXT NOT NULL,
      amount REAL NOT NULL,
      note TEXT
    );
  ''');
}

Map<String, Object?> _fuelRow({required int id, required double cost}) {
  return {
    'id': id,
    'device_id': 7,
    'date': 20260601,
    'supplier': '王五',
    'liters': 30.0,
    'cost': cost,
  };
}

Map<String, Object?> _maintRow({required int id, required double amount}) {
  return {
    'id': id,
    'device_id': 7,
    'ymd': 20260601,
    'item': '换机油',
    'amount': amount,
    'note': null,
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

Future<int> _nullCount(DatabaseExecutor db, String table, String column) async {
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS c FROM $table WHERE $column IS NULL',
  );
  return (rows.single['c'] as num?)?.toInt() ?? 0;
}

Future<int> _rowCount(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
  return (rows.single['c'] as num?)?.toInt() ?? 0;
}

Future<Map<String, Object?>> _row(
  DatabaseExecutor db,
  String table,
  int id,
) async {
  return (await db.query(table, where: 'id = ?', whereArgs: [id])).single;
}
