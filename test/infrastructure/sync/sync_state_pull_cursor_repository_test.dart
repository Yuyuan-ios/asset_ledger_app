import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/infrastructure/sync/sync_state_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
    AppDatabase.debugInitDbOverride = () {
      return openDatabase(
        inMemoryDatabasePath,
        version: AppDatabase.schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, _) => DbSchema.create(db),
      );
    };
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  test(
    'readPullCursor defaults to 0 and persists non-negative cursor',
    () async {
      final repository = LocalSyncStateRepository(
        now: () => DateTime.utc(2026, 6, 16, 12),
      );

      expect(await repository.readPullCursor(), 0);

      await repository.writePullCursor(42);

      expect(await repository.readPullCursor(), 42);
      final db = await AppDatabase.database;
      final row = (await db.query(
        'sync_state',
        where: 'scope = ?',
        whereArgs: [SyncStateRepository.kPullCursorScope],
      )).single;
      expect(row['pull_cursor'], 42);
      expect(row['updated_at'], '2026-06-16T12:00:00.000Z');
    },
  );

  test('writePullCursor rejects negative cursor', () async {
    const repository = LocalSyncStateRepository();

    expect(() => repository.writePullCursor(-1), throwsA(isA<ArgumentError>()));
  });
}
