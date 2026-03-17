import 'dart:async';

import 'package:asset_ledger/data/db/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  test(
    'AppDatabase.seedDemoData seeds only once into an empty devices table',
    () async {
      final dbPath = await getDatabasesPath();
      final filePath = p.join(dbPath, 'excavator_ledger.db');

      await deleteDatabase(filePath);

      final db = await AppDatabase.database;

      final beforeSeed = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM devices'),
      );
      expect(beforeSeed, 0);

      await AppDatabase.seedDemoData();

      final afterFirstSeed = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM devices'),
      );
      expect(afterFirstSeed, 2);

      await AppDatabase.seedDemoData();

      final afterSecondSeed = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM devices'),
      );
      expect(afterSecondSeed, 2);
    },
  );

  test(
    'AppDatabase.database shares one in-flight initialization across concurrent callers',
    () async {
      final gate = Completer<void>();
      var initCalls = 0;

      AppDatabase.debugInitDbOverride = () async {
        initCalls++;
        await gate.future;
        return openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onCreate: (db, _) async {
            await db.execute('CREATE TABLE smoke (id INTEGER PRIMARY KEY);');
          },
        );
      };

      final first = AppDatabase.database;
      final second = AppDatabase.database;
      final third = AppDatabase.database;

      await Future<void>.delayed(Duration.zero);
      expect(initCalls, 1);

      gate.complete();

      final dbs = await Future.wait([first, second, third]);
      expect(dbs.every((db) => identical(db, dbs.first)), isTrue);
    },
  );

  test(
    'AppDatabase.database clears failed initialization and allows retry',
    () async {
      var initCalls = 0;
      var shouldFail = true;

      AppDatabase.debugInitDbOverride = () async {
        initCalls++;
        if (shouldFail) {
          throw StateError('boom');
        }
        return openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onCreate: (db, _) async {
            await db.execute('CREATE TABLE retry_ok (id INTEGER PRIMARY KEY);');
          },
        );
      };

      await expectLater(AppDatabase.database, throwsStateError);
      expect(initCalls, 1);

      shouldFail = false;
      final db = await AppDatabase.database;
      expect(initCalls, 2);
      expect(db.isOpen, isTrue);
    },
  );
}
