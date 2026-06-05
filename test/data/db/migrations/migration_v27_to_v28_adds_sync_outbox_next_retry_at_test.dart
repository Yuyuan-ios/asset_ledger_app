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
      'asset_ledger_migration_028_',
    );
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test(
    'v27 to v28 upgrade adds nullable sync_outbox next_retry_at and keeps old '
    'rows with NULL value',
    () async {
      final v27 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 27,
          onCreate: (db, _) async {
            await _createV27SyncOutboxSchema(db);
            await db.insert('sync_outbox', {
              'id': 'outbox-legacy-1',
              'entity_type': 'timing_record',
              'entity_id': '7',
              'operation': 'create',
              'payload_json': '{"id":7}',
              'payload_hash': 'hash-legacy',
              'status': 'pending',
              'retry_count': 2,
              'last_error': 'old-error',
              'transaction_group_id': 'txn-old',
              'local_sequence': 1,
              'created_at': '2026-06-04T10:00:00.000Z',
              'updated_at': '2026-06-04T10:00:00.000Z',
            });
          },
        ),
      );
      try {
        expect(_columnByName(await _tableInfo(v27), 'next_retry_at'), isNull);
      } finally {
        await v27.close();
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
        final col = _columnByName(await _tableInfo(upgraded), 'next_retry_at');
        expect(col, isNotNull);
        expect(col!['type'], 'TEXT');
        expect(col['notnull'], 0);
        expect(col['dflt_value'], isNull);

        final rows = await upgraded.query(
          'sync_outbox',
          where: 'id = ?',
          whereArgs: ['outbox-legacy-1'],
        );
        expect(rows, hasLength(1));
        final row = rows.single;
        expect(row['retry_count'], 2);
        expect(row['last_error'], 'old-error');
        expect(row['transaction_group_id'], 'txn-old');
        expect(row['local_sequence'], 1);
        // The new column is NULL for pre-existing rows.
        expect(row['next_retry_at'], isNull);
      } finally {
        await upgraded.close();
      }
    },
  );
}

/// v27 sync_outbox: the current schema minus the v28 next_retry_at column.
Future<void> _createV27SyncOutboxSchema(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE sync_outbox (
      id TEXT PRIMARY KEY,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      operation TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      payload_hash TEXT NOT NULL,
      status TEXT NOT NULL,
      retry_count INTEGER NOT NULL DEFAULT 0 CHECK (retry_count >= 0),
      last_error TEXT,
      transaction_group_id TEXT,
      local_sequence INTEGER,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''');
}

Future<List<Map<String, Object?>>> _tableInfo(DatabaseExecutor db) {
  return db.rawQuery('PRAGMA table_info(sync_outbox);');
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
