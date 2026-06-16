import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/infrastructure/sync/sync_state_repository.dart';
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
      'asset_ledger_migration_049_',
    );
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test(
    'v48 to v49 upgrade adds sync_state pull_cursor default 0 and keeps rows',
    () async {
      final v48 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 48,
          onCreate: (db, _) async {
            await _createV48SyncStateSchema(db);
            await db.insert('sync_state', {
              'scope': SyncStateRepository.kPushGateScope,
              'last_pull_cursor': 'legacy-cursor',
              'last_push_at': '2026-06-15T10:00:00.000Z',
              'last_success_at': '2026-06-15T10:01:00.000Z',
              'last_error': 'legacy-error',
              'gate_state': SyncStateRepository.gateRestorePending,
              'updated_at': '2026-06-15T10:02:00.000Z',
            });
          },
        ),
      );
      try {
        expect(_columnByName(await _tableInfo(v48), 'pull_cursor'), isNull);
      } finally {
        await v48.close();
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
        final pullCursor = _columnByName(
          await _tableInfo(upgraded),
          'pull_cursor',
        );
        expect(pullCursor, isNotNull);
        expect(pullCursor!['type'], 'INTEGER');
        expect(pullCursor['notnull'], 1);
        expect(pullCursor['dflt_value'], '0');

        final rows = await upgraded.query(
          'sync_state',
          where: 'scope = ?',
          whereArgs: [SyncStateRepository.kPushGateScope],
        );
        expect(rows, hasLength(1));
        expect(rows.single['last_pull_cursor'], 'legacy-cursor');
        expect(rows.single['pull_cursor'], 0);
        expect(
          rows.single['gate_state'],
          SyncStateRepository.gateRestorePending,
        );
        expect(rows.single['updated_at'], '2026-06-15T10:02:00.000Z');
      } finally {
        await upgraded.close();
      }
    },
  );
}

Future<void> _createV48SyncStateSchema(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE sync_state (
      scope TEXT PRIMARY KEY,
      last_pull_cursor TEXT,
      last_push_at TEXT,
      last_success_at TEXT,
      last_error TEXT,
      gate_state TEXT,
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
