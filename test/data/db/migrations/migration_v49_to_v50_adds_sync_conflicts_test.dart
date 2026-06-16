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
      'asset_ledger_migration_050_',
    );
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test(
    'v49 to v50 upgrade creates sync_conflicts with defaults and unique key',
    () async {
      final v49 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(version: 49, onCreate: (db, _) async {}),
      );
      try {
        expect(await _tableExists(v49, 'sync_conflicts'), isFalse);
      } finally {
        await v49.close();
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
        expect(await _tableExists(upgraded, 'sync_conflicts'), isTrue);
        final columns = await upgraded.rawQuery(
          'PRAGMA table_info(sync_conflicts);',
        );
        expect(_columnNames(columns), containsAll(_expectedColumns));
        expect(_column(columns, 'status')!['dflt_value'], "'pending'");
        expect(_column(columns, 'remote_deleted')!['dflt_value'], '0');
        expect(_column(columns, 'remote_base_version')!['dflt_value'], '0');

        await upgraded.insert('sync_conflicts', {
          'id': 'conflict-1',
          'entity_type': 'timing_record',
          'entity_id': '101',
          'remote_server_seq': 9,
          'remote_new_version': 2,
          'remote_payload_json': '{"record":{}}',
          'remote_payload_hash': 'hash-1',
          'conflict_reason': 'remote_newer_local_dirty',
          'detected_at': '2026-06-16T00:00:00.000Z',
        });
        final row = (await upgraded.query('sync_conflicts')).single;
        expect(row['status'], 'pending');
        expect(row['remote_deleted'], 0);
        expect(row['remote_base_version'], 0);

        await expectLater(
          upgraded.insert('sync_conflicts', {
            'id': 'conflict-duplicate',
            'entity_type': 'timing_record',
            'entity_id': '101',
            'remote_server_seq': 9,
            'remote_new_version': 3,
            'remote_payload_json': '{"record":{"changed":true}}',
            'remote_payload_hash': 'hash-2',
            'conflict_reason': 'remote_newer_local_dirty',
            'detected_at': '2026-06-16T00:01:00.000Z',
          }),
          throwsA(isA<DatabaseException>()),
        );
      } finally {
        await upgraded.close();
      }
    },
  );
}

const _expectedColumns = <String>[
  'id',
  'entity_type',
  'entity_id',
  'remote_server_seq',
  'remote_base_version',
  'remote_new_version',
  'remote_payload_json',
  'remote_payload_hash',
  'remote_deleted',
  'conflict_reason',
  'detected_at',
  'status',
  'resolution',
  'resolved_at',
];

Future<bool> _tableExists(DatabaseExecutor db, String tableName) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    [tableName],
  );
  return rows.isNotEmpty;
}

Set<String> _columnNames(List<Map<String, Object?>> columns) {
  return columns.map((column) => column['name'] as String).toSet();
}

Map<String, Object?>? _column(List<Map<String, Object?>> columns, String name) {
  for (final column in columns) {
    if (column['name'] == name) return column;
  }
  return null;
}
