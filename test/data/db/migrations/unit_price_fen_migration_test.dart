import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// v35：devices / project_device_rates 单价整数分镜像列（审计 P1-1 上半）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp(
      'asset_ledger_migration_035_',
    );
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('fresh schema provisions nullable unit price fen columns', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      ),
    );
    try {
      for (final spec in const [
        ['devices', 'default_unit_price_fen'],
        ['devices', 'breaking_unit_price_fen'],
        ['project_device_rates', 'rate_fen'],
      ]) {
        final column = await _column(db, spec[0], spec[1]);
        expect(column, isNotNull, reason: '${spec[0]}.${spec[1]} 缺列');
        expect(_isNullable(column!), isTrue);
      }
    } finally {
      await db.close();
    }
  });

  test('v34 to v35 upgrade backfills fen mirrors from REAL prices', () async {
    final v34 = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 34,
        onCreate: (db, _) async {
          await _createV34Substrate(db);
          await db.insert('devices', {
            'id': 1,
            'name': 'SANY 1#',
            'brand': 'sany',
            'default_unit_price': 380.5,
            'breaking_unit_price': 480.0,
            'base_meter_hours': 0.0,
            'is_active': 1,
            'equipment_type': 'excavator',
          });
          await db.insert('devices', {
            'id': 2,
            'name': 'SANY 2#',
            'brand': 'sany',
            'default_unit_price': 300.0,
            'breaking_unit_price': null,
            'base_meter_hours': 0.0,
            'is_active': 1,
            'equipment_type': 'excavator',
          });
          await db.insert('projects', {
            'id': 'project:a',
            'contact': '甲方',
            'site': '一号工地',
            'status': 'active',
            'created_at': '2026-06-01T00:00:00Z',
            'updated_at': '2026-06-01T00:00:00Z',
          });
          await db.insert('project_device_rates', {
            'project_id': 'project:a',
            'project_key': '甲方||一号工地',
            'device_id': 1,
            'is_breaking': 0,
            'rate': 399.99,
          });
        },
      ),
    );
    await v34.close();

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
      final devices = await upgraded.query('devices', orderBy: 'id');
      expect(devices.first['default_unit_price_fen'], 38050);
      expect(devices.first['breaking_unit_price_fen'], 48000);
      final device1 = Device.fromMap(devices.first);
      expect(device1.defaultUnitPriceFen, 38050);
      expect(device1.breakingUnitPriceFen, 48000);

      // 未配置破碎单价的行：fen 同样保持 NULL（语义：回落 default）。
      expect(devices.last['default_unit_price_fen'], 30000);
      expect(devices.last['breaking_unit_price_fen'], isNull);
      expect(Device.fromMap(devices.last).breakingUnitPriceFen, isNull);

      final rate = (await upgraded.query('project_device_rates')).single;
      expect(rate['rate_fen'], 39999);
      expect(ProjectDeviceRate.fromMap(rate).rateFen, 39999);
    } finally {
      await upgraded.close();
    }
  });

  test('ensure is idempotent and never clobbers stored fen values', () async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => _createV34Substrate(db),
      ),
    );
    try {
      await DbMigrations.ensureUnitPriceFenColumns(db);
      await DbMigrations.ensureUnitPriceFenColumns(db);

      // 已落非 NULL 值的行再次 ensure 不被覆盖。
      await db.insert('devices', {
        'id': 9,
        'name': 'X',
        'brand': 'sany',
        'default_unit_price': 100.0,
        'default_unit_price_fen': 12345,
        'base_meter_hours': 0.0,
        'is_active': 1,
        'equipment_type': 'excavator',
      });
      await DbMigrations.ensureUnitPriceFenColumns(db);
      final stored = (await db.query(
        'devices',
        where: 'id = 9',
      )).single;
      expect(stored['default_unit_price_fen'], 12345);
    } finally {
      await db.close();
    }
  });
}

/// v34 基底：v35 之前形态的 devices / projects / project_device_rates。
Future<void> _createV34Substrate(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE devices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      brand TEXT NOT NULL,
      model TEXT,
      default_unit_price REAL NOT NULL,
      breaking_unit_price REAL,
      base_meter_hours REAL NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      custom_avatar_path TEXT,
      equipment_type TEXT NOT NULL DEFAULT 'excavator'
    );
  ''');
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
  await db.execute('''
    CREATE TABLE project_device_rates (
      project_id TEXT NOT NULL,
      project_key TEXT NOT NULL,
      device_id INTEGER NOT NULL,
      is_breaking INTEGER NOT NULL DEFAULT 0,
      rate REAL NOT NULL,
      PRIMARY KEY (project_id, device_id, is_breaking),
      FOREIGN KEY (project_id)
        REFERENCES projects(id) ON DELETE RESTRICT
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

bool _isNullable(Map<String, Object?> columnInfo) {
  return ((columnInfo['notnull'] as int?) ?? 0) == 0;
}
