import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  test(
    'fresh install sync_outbox schema includes nullable transaction_group_id '
    'TEXT and local_sequence INTEGER, and keeps all other columns',
    () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => DbSchema.create(db),
      );
      try {
        final columns = await _syncOutboxColumns(db);

        // Lock the full column set + order. Adding the two R5.22-A columns must
        // not loosen the unknown-column contract: this asserts the exact set.
        expect(
          columns.keys,
          orderedEquals(<String>[
            'id',
            'entity_type',
            'entity_id',
            'operation',
            'payload_json',
            'payload_hash',
            'status',
            'retry_count',
            'last_error',
            'transaction_group_id',
            'local_sequence',
            'created_at',
            'updated_at',
          ]),
        );

        final groupCol = columns['transaction_group_id'];
        expect(groupCol, isNotNull);
        expect(groupCol!['type'], 'TEXT');
        expect(groupCol['notnull'], 0, reason: 'transaction_group_id nullable');

        final seqCol = columns['local_sequence'];
        expect(seqCol, isNotNull);
        expect(seqCol!['type'], 'INTEGER');
        expect(seqCol['notnull'], 0, reason: 'local_sequence nullable');
      } finally {
        await db.close();
      }
    },
  );
}

Future<Map<String, Map<String, Object?>>> _syncOutboxColumns(
  DatabaseExecutor db,
) async {
  final rows = await db.rawQuery('PRAGMA table_info(sync_outbox);');
  return {for (final row in rows) row['name']! as String: row};
}
