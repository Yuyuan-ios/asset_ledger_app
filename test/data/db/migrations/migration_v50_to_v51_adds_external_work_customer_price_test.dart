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
      'asset_ledger_migration_051_',
    );
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test(
    'v50 to v51 adds nullable customer_unit_price_fen without touching amount_fen',
    () async {
      final v50 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 50,
          onCreate: (db, _) async {
            // 旧版 external_work_records（无 customer_unit_price_fen）。
            await db.execute('''
              CREATE TABLE external_work_records (
                id TEXT PRIMARY KEY,
                import_batch_id TEXT NOT NULL,
                local_unit_price_fen INTEGER,
                amount_fen INTEGER NOT NULL,
                record_kind TEXT NOT NULL DEFAULT 'hours'
              );
            ''');
            await db.insert('external_work_records', {
              'id': 'r1',
              'import_batch_id': 'b1',
              'amount_fen': 18000,
              'record_kind': 'hours',
            });
          },
        ),
      );
      try {
        expect(
          await _hasColumn(
            v50,
            'external_work_records',
            'customer_unit_price_fen',
          ),
          isFalse,
        );
      } finally {
        await v50.close();
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
        expect(
          await _hasColumn(
            upgraded,
            'external_work_records',
            'customer_unit_price_fen',
          ),
          isTrue,
        );

        // 旧行：新列默认 null，应付金额不被迁移改动。
        final row = (await upgraded.query(
          'external_work_records',
          where: 'id = ?',
          whereArgs: ['r1'],
        )).single;
        expect(row['customer_unit_price_fen'], isNull);
        expect(row['amount_fen'], 18000);

        // 可写入客户单价。
        await upgraded.update(
          'external_work_records',
          {'customer_unit_price_fen': 20000},
          where: 'id = ?',
          whereArgs: ['r1'],
        );
        final updated = (await upgraded.query(
          'external_work_records',
          where: 'id = ?',
          whereArgs: ['r1'],
        )).single;
        expect(updated['customer_unit_price_fen'], 20000);
      } finally {
        await upgraded.close();
      }
    },
  );
}

Future<bool> _hasColumn(
  DatabaseExecutor db,
  String table,
  String column,
) async {
  final columns = await db.rawQuery('PRAGMA table_info($table);');
  return columns.any((c) => c['name'] == column);
}
