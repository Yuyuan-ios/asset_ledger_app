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
      'asset_ledger_migration_053_',
    );
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test(
    'v52 to v53 backfills missing project rate snapshots without overwriting',
    () async {
      final v52 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 52,
          onCreate: (db, _) async {
            await _createV52RateSnapshotTables(db);
            await _seedV52RateSnapshotData(db);
          },
        ),
      );
      try {
        expect(await v52.query('project_device_rates'), hasLength(1));
      } finally {
        await v52.close();
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
        final rows = await upgraded.query(
          'project_device_rates',
          orderBy: 'project_id, device_id, is_breaking',
        );
        expect(rows, hasLength(4));
        expect(rows, [
          _rateRow(
            projectId: 'project:li-legacy',
            projectKey: '李杰||新村',
            deviceId: 1,
            isBreaking: 0,
            rateFen: 12345,
          ),
          _rateRow(
            projectId: 'project:li-legacy',
            projectKey: '李杰||新村',
            deviceId: 1,
            isBreaking: 1,
            rateFen: 16000,
          ),
          _rateRow(
            projectId: 'project:li-legacy',
            projectKey: '李杰||新村',
            deviceId: 2,
            isBreaking: 1,
            rateFen: 8000,
          ),
          _rateRow(
            projectId: 'project:wang-fallback',
            projectKey: '王五||二号',
            deviceId: 2,
            isBreaking: 0,
            rateFen: 8000,
          ),
        ]);

        await DbMigrations.ensureProjectRateSnapshots(upgraded);
        expect(await upgraded.query('project_device_rates'), hasLength(4));
      } finally {
        await upgraded.close();
      }
    },
  );
}

Future<void> _createV52RateSnapshotTables(Database db) async {
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
      equipment_type TEXT NOT NULL DEFAULT 'excavator',
      lifecycle_initial_cost_fen INTEGER,
      lifecycle_estimated_residual_fen INTEGER
    );
  ''');
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
      income_fen INTEGER NOT NULL,
      unit TEXT NOT NULL,
      quantity_scaled INTEGER,
      exclude_from_fuel_eff INTEGER NOT NULL DEFAULT 0,
      is_breaking INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE RESTRICT
    );
  ''');
  await db.execute('''
    CREATE TABLE project_device_rates (
      project_id TEXT NOT NULL,
      project_key TEXT NOT NULL,
      device_id INTEGER NOT NULL,
      is_breaking INTEGER NOT NULL DEFAULT 0,
      rate_fen INTEGER NOT NULL,
      PRIMARY KEY (project_id, device_id, is_breaking),
      FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE RESTRICT
    );
  ''');
}

Future<void> _seedV52RateSnapshotData(Database db) async {
  await db.insert('projects', {
    'id': 'project:li-legacy',
    'contact': '李杰',
    'site': '新村',
    'status': 'active',
    'created_at': '2026-05-01T00:00:00.000Z',
    'updated_at': '2026-05-01T00:00:00.000Z',
    'legacy_project_key': '李杰||新村',
  });
  await db.insert('projects', {
    'id': 'project:wang-fallback',
    'contact': '王五',
    'site': '二号',
    'status': 'active',
    'created_at': '2026-05-01T00:00:00.000Z',
    'updated_at': '2026-05-01T00:00:00.000Z',
  });
  await db.insert('devices', {
    'id': 1,
    'name': 'SANY 1#',
    'brand': 'SANY',
    'default_unit_price_fen': 10000,
    'breaking_unit_price_fen': 16000,
    'base_meter_hours': 0.0,
  });
  await db.insert('devices', {
    'id': 2,
    'name': 'HITACHI 1#',
    'brand': 'HITACHI',
    'default_unit_price_fen': 8000,
    'base_meter_hours': 0.0,
  });
  await db.insert('project_device_rates', {
    'project_id': 'project:li-legacy',
    'project_key': '李杰||新村',
    'device_id': 1,
    'is_breaking': 0,
    'rate_fen': 12345,
  });
  await _insertTiming(
    db,
    projectId: 'project:li-legacy',
    contact: '李杰',
    site: '新村',
    deviceId: 1,
    isBreaking: 0,
  );
  await _insertTiming(
    db,
    projectId: 'project:li-legacy',
    contact: '李杰',
    site: '新村',
    deviceId: 1,
    isBreaking: 1,
  );
  await _insertTiming(
    db,
    projectId: 'project:li-legacy',
    contact: '李杰',
    site: '新村',
    deviceId: 2,
    isBreaking: 1,
  );
  await _insertTiming(
    db,
    projectId: 'project:wang-fallback',
    contact: '王五',
    site: '二号',
    deviceId: 2,
    isBreaking: 0,
  );
  await _insertTiming(
    db,
    projectId: 'project:wang-fallback',
    contact: '王五',
    site: '二号',
    deviceId: 1,
    type: 'rent',
    isBreaking: 0,
  );
}

Future<void> _insertTiming(
  Database db, {
  required String projectId,
  required String contact,
  required String site,
  required int deviceId,
  required int isBreaking,
  String type = 'hours',
}) {
  return db.insert('timing_records', {
    'project_id': projectId,
    'device_id': deviceId,
    'start_date': 20260501,
    'contact': contact,
    'site': site,
    'type': type,
    'start_meter': 0.0,
    'end_meter': 10.0,
    'hours': 10.0,
    'income_fen': 0,
    'unit': type == 'rent' ? 'rent' : 'hour',
    'is_breaking': isBreaking,
  });
}

Matcher _rateRow({
  required String projectId,
  required String projectKey,
  required int deviceId,
  required int isBreaking,
  required int rateFen,
}) {
  return allOf(
    containsPair('project_id', projectId),
    containsPair('project_key', projectKey),
    containsPair('device_id', deviceId),
    containsPair('is_breaking', isBreaking),
    containsPair('rate_fen', rateFen),
  );
}
