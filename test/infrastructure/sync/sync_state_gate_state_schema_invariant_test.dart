import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  test(
    'fresh install sync_state schema includes nullable text gate_state',
    () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      );
      try {
        final columns = await _syncStateColumns(db);

        expect(
          columns.keys,
          orderedEquals(<String>[
            'scope',
            'last_pull_cursor',
            'last_push_at',
            'last_success_at',
            'last_error',
            'gate_state',
            'updated_at',
          ]),
        );

        final gateState = columns['gate_state'];
        expect(gateState, isNotNull);
        expect(gateState!['type'], 'TEXT');
        expect(gateState['notnull'], 0);
      } finally {
        await db.close();
      }
    },
  );
}

Future<Map<String, Map<String, Object?>>> _syncStateColumns(
  DatabaseExecutor db,
) async {
  final rows = await db.rawQuery('PRAGMA table_info(sync_state);');
  return {for (final row in rows) row['name']! as String: row};
}
