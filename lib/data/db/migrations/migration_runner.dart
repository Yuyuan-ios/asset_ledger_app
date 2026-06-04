part of '../db_migrations.dart';

class MigrationRunner {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    await Migration001010.apply(db, oldVersion, newVersion);
    await Migration011017.apply(db, oldVersion, newVersion);
    await Migration018.apply(db, oldVersion, newVersion);
    await Migration019.apply(db, oldVersion, newVersion);
    await Migration020.apply(db, oldVersion, newVersion);
    await Migration021.apply(db, oldVersion, newVersion);
    await Migration022.apply(db, oldVersion, newVersion);
    await Migration023.apply(db, oldVersion, newVersion);
    await Migration024.apply(db, oldVersion, newVersion);
    await Migration025.apply(db, oldVersion, newVersion);
  }
}
