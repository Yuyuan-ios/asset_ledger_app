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
      'asset_ledger_migration_027_',
    );
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test(
    'v26 to v27 upgrade adds nullable sync_outbox transaction_group_id / '
    'local_sequence and keeps old rows with NULL values',
    () async {
      final v26 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 26,
          onCreate: (db, _) async {
            await _createV26SyncOutboxSchema(db);
            await db.insert('sync_outbox', {
              'id': 'outbox-legacy-1',
              'entity_type': 'timing_record',
              'entity_id': '42',
              'operation': 'create',
              'payload_json': '{"id":42}',
              'payload_hash': 'hash-legacy',
              'status': 'pending',
              'retry_count': 0,
              'last_error': null,
              'created_at': '2026-06-04T10:00:00.000Z',
              'updated_at': '2026-06-04T10:00:00.000Z',
            });
          },
        ),
      );
      try {
        final cols = await _tableInfo(v26);
        expect(_columnByName(cols, 'transaction_group_id'), isNull);
        expect(_columnByName(cols, 'local_sequence'), isNull);
      } finally {
        await v26.close();
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
        final cols = await _tableInfo(upgraded);

        final groupCol = _columnByName(cols, 'transaction_group_id');
        expect(groupCol, isNotNull);
        expect(groupCol!['type'], 'TEXT');
        expect(groupCol['notnull'], 0);
        expect(groupCol['dflt_value'], isNull);

        final seqCol = _columnByName(cols, 'local_sequence');
        expect(seqCol, isNotNull);
        expect(seqCol!['type'], 'INTEGER');
        expect(seqCol['notnull'], 0);
        expect(seqCol['dflt_value'], isNull);

        final rows = await upgraded.query(
          'sync_outbox',
          where: 'id = ?',
          whereArgs: ['outbox-legacy-1'],
        );
        expect(rows, hasLength(1));
        final row = rows.single;
        // Old row content preserved.
        expect(row['entity_type'], 'timing_record');
        expect(row['entity_id'], '42');
        expect(row['operation'], 'create');
        expect(row['payload_hash'], 'hash-legacy');
        expect(row['status'], 'pending');
        // New columns are NULL for pre-existing rows.
        expect(row['transaction_group_id'], isNull);
        expect(row['local_sequence'], isNull);
      } finally {
        await upgraded.close();
      }
    },
  );
}

/// v26 sync_outbox: the current schema minus the two R5.22-A columns.
Future<void> _createV26SyncOutboxSchema(DatabaseExecutor db) async {
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
