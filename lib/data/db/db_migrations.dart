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
part 'migrations/migration_025.dart';
part 'migrations/migration_026.dart';
part 'migrations/migration_027.dart';
part 'migrations/migration_028.dart';
part 'migrations/migration_029.dart';
part 'migrations/migration_030.dart';
part 'migrations/migration_031.dart';
part 'migrations/migration_032.dart';
part 'migrations/migration_033.dart';
part 'migrations/migration_034.dart';
part 'migrations/migration_035.dart';
part 'migrations/migration_036.dart';
part 'migrations/migration_037.dart';
part 'migrations/migration_038.dart';
part 'migrations/migration_039.dart';
part 'migrations/migration_040.dart';
part 'migrations/migration_041.dart';
part 'migrations/migration_042.dart';
part 'migrations/migration_043.dart';
part 'migrations/migration_044.dart';
part 'migrations/migration_045.dart';
part 'migrations/migration_046.dart';
part 'migrations/migration_047.dart';
part 'migrations/migration_048.dart';
part 'migrations/migration_049.dart';
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

  static Future<void> ensureTimingAllocationCutoffDate(Database db) {
    return Migration025.ensureTimingAllocationCutoffDate(db);
  }

  static Future<void> ensureSyncStateGateState(Database db) {
    return Migration026.ensureSyncStateGateState(db);
  }

  static Future<void> ensureSyncOutboxTransactionGroup(Database db) {
    return Migration027.ensureSyncOutboxTransactionGroup(db);
  }

  static Future<void> ensureSyncOutboxNextRetryAt(Database db) {
    return Migration028.ensureSyncOutboxNextRetryAt(db);
  }

  static Future<void> ensureTimingIncomeFen(Database db) {
    return Migration029.ensureTimingIncomeFen(db);
  }

  static Future<void> ensureProjectWriteOffAmountFenNotNull(Database db) {
    return Migration030.ensureProjectWriteOffAmountFenNotNull(db);
  }

  static Future<void> ensureAccountPaymentAmountFenNotNull(Database db) {
    return Migration031.ensureAccountPaymentAmountFenNotNull(db);
  }

  static Future<void> ensureTimingDisplayEndDate(Database db) {
    return Migration032.ensureTimingDisplayEndDate(db);
  }

  static Future<void> ensureTimingQuantityUnit(Database db) {
    return Migration033.ensureTimingQuantityUnit(db);
  }

  static Future<void> ensureTimingIncomeFenNotNull(Database db) {
    return Migration034.ensureTimingIncomeFenNotNull(db);
  }

  static Future<void> ensureUnitPriceFenColumns(Database db) {
    return Migration035.ensureUnitPriceFenColumns(db);
  }

  static Future<void> ensureTimingUnitNotNull(Database db) {
    return Migration036.ensureTimingUnitNotNull(db);
  }

  static Future<void> ensureFuelMaintenanceMoneyFen(Database db) {
    return Migration037.ensureFuelMaintenanceMoneyFen(db);
  }

  static Future<void> ensureDeviceDefaultUnitPriceFenNotNull(Database db) {
    return Migration038.ensureDeviceDefaultUnitPriceFenNotNull(db);
  }

  static Future<void> ensureProjectDeviceRateFenNotNull(Database db) {
    return Migration039.ensureProjectDeviceRateFenNotNull(db);
  }

  static Future<void> ensureFuelCostFenNotNull(Database db) {
    return Migration040.ensureFuelCostFenNotNull(db);
  }

  static Future<void> ensureMaintenanceAmountFenNotNull(Database db) {
    return Migration041.ensureMaintenanceAmountFenNotNull(db);
  }

  static Future<void> ensureFuelCostRealDropped(Database db) {
    return Migration042.ensureFuelCostRealDropped(db);
  }

  static Future<void> ensureMaintenanceAmountRealDropped(Database db) {
    return Migration043.ensureMaintenanceAmountRealDropped(db);
  }

  static Future<void> ensureDeviceUnitPriceRealsDropped(Database db) {
    return Migration044.ensureDeviceUnitPriceRealsDropped(db);
  }

  static Future<void> ensureProjectDeviceRateRealDropped(Database db) {
    return Migration045.ensureProjectDeviceRateRealDropped(db);
  }

  static Future<void> ensureProjectWriteOffAmountRealDropped(Database db) {
    return Migration046.ensureProjectWriteOffAmountRealDropped(db);
  }

  static Future<void> ensureAccountPaymentAmountRealsDropped(Database db) {
    return Migration047.ensureAccountPaymentAmountRealsDropped(db);
  }

  static Future<void> ensureTimingIncomeRealDropped(Database db) {
    return Migration048.ensureTimingIncomeRealDropped(db);
  }

  static Future<void> ensureSyncStatePullCursor(Database db) {
    return Migration049.ensureSyncStatePullCursor(db);
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
