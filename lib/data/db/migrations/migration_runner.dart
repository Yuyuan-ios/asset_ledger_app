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
    await Migration026.apply(db, oldVersion, newVersion);
    await Migration027.apply(db, oldVersion, newVersion);
    await Migration028.apply(db, oldVersion, newVersion);
    await Migration029.apply(db, oldVersion, newVersion);
    await Migration030.apply(db, oldVersion, newVersion);
    await Migration031.apply(db, oldVersion, newVersion);
    await Migration032.apply(db, oldVersion, newVersion);
    await Migration033.apply(db, oldVersion, newVersion);
    await Migration034.apply(db, oldVersion, newVersion);
    await Migration035.apply(db, oldVersion, newVersion);
    await Migration036.apply(db, oldVersion, newVersion);
    await Migration037.apply(db, oldVersion, newVersion);
    await Migration038.apply(db, oldVersion, newVersion);
    await Migration039.apply(db, oldVersion, newVersion);
    await Migration040.apply(db, oldVersion, newVersion);
    await Migration041.apply(db, oldVersion, newVersion);
    await Migration042.apply(db, oldVersion, newVersion);
    await Migration043.apply(db, oldVersion, newVersion);
    await Migration044.apply(db, oldVersion, newVersion);
    await Migration045.apply(db, oldVersion, newVersion);
    await Migration046.apply(db, oldVersion, newVersion);
  }
}
