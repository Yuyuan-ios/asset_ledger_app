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
      'asset_ledger_migration_026_',
    );
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test(
    'v25 to v26 upgrade adds nullable sync_state gate_state and keeps old rows',
    () async {
      final v25 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 25,
          onCreate: (db, _) async {
            await _createV25SyncStateSchema(db);
            await db.insert('sync_state', {
              'scope': 'owner',
              'last_pull_cursor': 'cursor-25',
              'last_push_at': '2026-06-04T10:00:00.000Z',
              'last_success_at': '2026-06-04T10:01:00.000Z',
              'last_error': 'legacy-error',
              'updated_at': '2026-06-04T10:02:00.000Z',
            });
          },
        ),
      );
      try {
        expect(_columnByName(await _tableInfo(v25), 'gate_state'), isNull);
      } finally {
        await v25.close();
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
        final gateState = _columnByName(
          await _tableInfo(upgraded),
          'gate_state',
        );
        expect(gateState, isNotNull);
        expect(gateState!['type'], 'TEXT');
        expect(gateState['notnull'], 0);
        expect(gateState['dflt_value'], isNull);

        final rows = await upgraded.query(
          'sync_state',
          where: 'scope = ?',
          whereArgs: ['owner'],
        );
        expect(rows, hasLength(1));
        expect(rows.single['last_pull_cursor'], 'cursor-25');
        expect(rows.single['last_push_at'], '2026-06-04T10:00:00.000Z');
        expect(rows.single['last_success_at'], '2026-06-04T10:01:00.000Z');
        expect(rows.single['last_error'], 'legacy-error');
        expect(rows.single['updated_at'], '2026-06-04T10:02:00.000Z');
        expect(rows.single['gate_state'], isNull);
      } finally {
        await upgraded.close();
      }
    },
  );
}

Future<void> _createV25SyncStateSchema(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE sync_state (
      scope TEXT PRIMARY KEY,
      last_pull_cursor TEXT,
      last_push_at TEXT,
      last_success_at TEXT,
      last_error TEXT,
      updated_at TEXT NOT NULL
    );
  ''');
}

Future<List<Map<String, Object?>>> _tableInfo(DatabaseExecutor db) {
  return db.rawQuery('PRAGMA table_info(sync_state);');
}

Map<String, Object?>? _columnByName(
  List<Map<String, Object?>> columns,
  String name,
) {
  for (final column in columns) {
    if (column['name'] == name) {
      return column;
    }
  }
  return null;
}
