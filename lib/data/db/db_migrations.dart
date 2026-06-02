import 'package:sqflite/sqflite.dart';

import '../models/project.dart';
import '../models/project_key.dart';
import 'schema/external_work_schema.dart';
import 'schema/operation_tokens_schema.dart';
import 'schema/operations_schema.dart';
import 'schema/sync_schema.dart';

part 'migrations/migration_runner.dart';
part 'migrations/migration_001_010.dart';
part 'migrations/migration_011_017.dart';
part 'migrations/migration_018.dart';
part 'migrations/migration_019.dart';
part 'migrations/migration_020.dart';
part 'migrations/migration_021.dart';
part 'migrations/migration_022.dart';
part 'migrations/migration_023.dart';
part 'migrations/migration_024.dart';
part 'migrations/project_identity_migration.dart';
part 'migrations/project_foreign_key_migration.dart';
part 'migrations/migration_helpers.dart';

/// 数据库增量迁移链（onUpgrade）。
///
/// 说明：
/// - 保持 if(oldVersion < X) 的顺序与语义稳定。
/// - 迁移版本需与 AppDatabase._dbVersion 同步维护。
class DbMigrations {
  static Future<void> apply(Database db, int oldVersion, int newVersion) {
    return MigrationRunner.apply(db, oldVersion, newVersion);
  }

  static Future<void> ensureExternalWorkSchema(Database db) {
    return Migration011017.ensureExternalWorkSchema(db);
  }

  static Future<void> ensureSyncSchema(Database db) {
    return Migration011017.ensureSyncSchema(db);
  }

  static Future<void> ensureProjectWriteOffSchema(Database db) {
    return Migration011017.ensureProjectWriteOffSchema(db);
  }

  static Future<void> ensureMoneyFenSchema(Database db) {
    return Migration018.ensureMoneyFenSchema(db);
  }

  static Future<void> ensureNullableExternalWorkUnitPrice(Database db) {
    return Migration019.ensureNullableExternalWorkUnitPrice(db);
  }

  static Future<void> ensureExternalWorkProjectReceivedFen(Database db) {
    return Migration020.ensureExternalWorkProjectReceivedFen(db);
  }

  static Future<void> ensureActiveScopedLegacyProjectKeyUniqueness(
    Database db,
  ) {
    return Migration021.ensureActiveScopedLegacyProjectKeyUniqueness(db);
  }

  static Future<void> ensureOperationAuditLogSchema(Database db) {
    return Migration024.ensureOperationAuditLogTokenId(db);
  }

  static Future<void> ensureOperationTokensSchema(Database db) {
    return Migration023.ensureOperationTokensSchema(db);
  }

  static Future<void> ensureProjectIdentitySchema(
    Database db, {
    bool enforceForeignKeys = false,
  }) {
    return ProjectIdentityMigration.ensure(
      db,
      enforceForeignKeys: enforceForeignKeys,
    );
  }
}
