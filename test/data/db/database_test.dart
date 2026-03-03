import 'package:asset_ledger/data/db/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  test('AppDatabase.seedDemoData seeds only once into an empty devices table', () async {
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
  });
}
