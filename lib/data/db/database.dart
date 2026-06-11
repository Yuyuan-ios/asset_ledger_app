// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

// 1.1 SQLite 插件：sqflite
import 'dart:io';

import 'package:sqflite/sqflite.dart';

// 1.2 路径拼接：path
import 'package:path/path.dart';
import 'db_migrations.dart';
import 'db_seed.dart';
import 'db_schema.dart';
import 'db_schema_compat.dart';

/// DB 层正式入口关系（轻量架构图）
///
/// - [AppDatabase]：数据库 facade（open/upgrade/transaction/seed 入口）
/// - [DbSchema]：首次建库（onCreate）的全量 schema
/// - [DbSchemaCompat]：历史数据库打开时的结构兜底（onOpen）
/// - [DbSeed]：开发/演示数据写入（仅上层主动调用）
///
/// 说明：
/// - 增量迁移仍统一在 [AppDatabase._onUpgrade] 维护，避免迁移分散。
/// - 页面与业务层不应直接操作 schema/compat/seed，只通过 [AppDatabase] 进入。

// =====================================================================
// ============================== 二、数据库单例 AppDatabase ==============================
// =====================================================================

class AppDatabase {
  // -------------------------------------------------------------------
  // 2.1 单例缓存：避免重复 openDatabase
  // -------------------------------------------------------------------
  static Database? _db;
  static Future<Database>? _dbFuture;

  /// 仅供测试覆盖并发/失败场景时注入初始化实现。
  static Future<Database> Function()? debugInitDbOverride;

  // -------------------------------------------------------------------
  // 2.2 数据库文件名 & 版本号
  //
  // 版本策略：
  // - v2：devices 增加 custom_avatar_path
  // - v3：fuel_logs 增加 supplier
  // - v4：新增 maintenance_records（维保）
  // - v5：新增 account_payments（收款） + project_device_rates（项目×设备单价覆盖）
  // - v6：timing_records 增加 exclude_from_fuel_eff（包油：不计入燃油效率）
  // - v7：timing_records 增加 is_breaking（破碎模式）
  // - v8：devices 增加 breaking_unit_price；project_device_rates 增加 is_breaking
  // - v9：devices 增加 equipment_type（excavator/loader）
  // - v10：新增 timing_calculation_history（计时记录工时计算依据）
  // - v11：新增 account_project_merge_groups / members（账户项目合并关系）
  // - v12：account_payments 增加合并收款分摊批次字段
  // - v13：新增 projects；核心业务表增加 project_id
  // - v14：projects 增加状态；核心 project_id 外键硬化
  // - v15：新增 external import / external work record 基础表
  // - v16：新增 project_write_offs（项目核销记录）
  // - v17：新增 sync_outbox / sync_state / entity_sync_meta / work_records
  // - v18：account_payments / project_write_offs 第一批核心金额 fen 字段
  // - v19：external_work_records 单价可空并新增 record_kind
  // - v20：external_work_records 增加来源项目累计实收款 project_received_fen
  // - v21：移除 projects.legacy_project_key 的全局 UNIQUE 约束；改为 active-scope
  //        partial unique index（同 legacy_project_key 下只允许一个 active 项目）。
  // - v22：新增 operation_audit_logs（append-only 操作审计表 + 3 个索引）；
  //        不改任何旧业务表；不纳入 backup/restore（per-device 操作历史）。
  // - v23：新增 operation_tokens（confirmation token 可变状态机表 + 3 个索引）；
  //        不改任何旧业务表 / 不改 operation_audit_logs；不纳入 backup/restore
  //        （per-device 安全 / 会话状态，恢复后旧 token 靠 hash/freshness 失效）。
  // - v24：operation_audit_logs 新增 nullable token_id + token_id 索引；
  //        不加 FK，不纳入 backup/restore。
  // - v25：timing_records 新增 nullable allocation_cutoff_date；
  //        仅作为未来显式分摊右开边界持久化基线，当前业务逻辑不读取。
  // - v26：sync_state 新增 nullable gate_state（R5.21 push gate）；
  //        restore 同事务写 'restore-pending'，SyncManager.pushPending 在 push 前
  //        据此短路；不动旧业务表 / sync_outbox / entity_sync_meta。
  // - v27：sync_outbox 新增 nullable transaction_group_id / local_sequence
  //        （R5.22-A）；标记同事务 cluster 的多条 outbox 为有序组。入队侧写入，
  //        SyncManager push ordering/replay 留待 R5.22-B；旧行与单条入队保持 NULL。
  // - v28：sync_outbox 新增 nullable next_retry_at（R5.22-B）；push 失败后写入
  //        退避时间点，listPending 跳过未到期行；成功行删除，旧/未失败行保持 NULL。
  // - v29：timing_records 新增 nullable income_fen（R5.26-B3）；income 的整数分
  //        镜像 round(income*100)，与 REAL income 双写并回填历史行。读路径本轮
  //        不切换（应收/汇总仍按 income REAL 计算），income_fen 仅作存储/同步地基，
  //        读路径切换留待 B4；不动 income REAL 的 NOT NULL 语义、不重建表。
  // - v30：project_write_offs.amount_fen 提升为 INTEGER NOT NULL（R5.26-B2）；
  //        SQLite 不能原地改列约束，故重建表，回填用
  //        COALESCE(amount_fen, ROUND(amount*100)) 兜底残留 NULL；保留 amount REAL
  //        兼容列、CHECK(amount>0)、TEXT 主键、projects FK RESTRICT 与两索引。
  //        不动 account_payments（B1）、不改 model/payload/读路径。
  // - v31：account_payments.amount_fen 提升为 INTEGER NOT NULL（R5.26-B1）；
  //        SQLite 不能原地改列约束，故重建表（14 列全集），回填用
  //        COALESCE(amount_fen, ROUND(amount*100)) 兜底残留 NULL；保留 amount REAL
  //        兼容列、id INTEGER PRIMARY KEY AUTOINCREMENT、projects FK RESTRICT 与
  //        idx_account_payments_project_ymd 索引。sqlite_sequence 写回
  //        max(old_seq, current_max_id)（保留历史高水位、不让 AUTOINCREMENT 倒退）。
  //        merge_batch_total_amount_fen 保持 nullable（不翻 NOT NULL）。
  //        不动 project_write_offs / timing_records、不改 model/payload/读路径。
  // - v32：timing_records 新增 nullable display_end_date；
  //        rent/台班 UI inclusive 展示结束日，仅用于记录展示与编辑回填。
  //        additive ADD COLUMN，不回填、不重建表、不参与收入/账户/结清计算。
  // - v33：timing_records 新增 nullable unit / quantity_scaled（S2 计量泛化
  //        第一片）。additive ADD COLUMN + 回填（hours 行 unit='HOUR'、
  //        quantity_scaled=round(hours*1000)；rent 行 unit='RENT'、quantity
  //        保持 NULL）。hours/type 仍是权威，读路径不切换。
  // - v34：timing_records.income_fen 提升为 INTEGER NOT NULL（重建表）。
  //        onUpgrade 刻意为空（timing 非叶子表，事务内 FK PRAGMA 不生效，
  //        DROP 会级联删 timing_calculation_history）；重建走 onOpen 的
  //        ensureTimingIncomeFenNotNull。unit/quantity_scaled 保持 nullable。
  // -------------------------------------------------------------------
  static const String _dbName = 'asset_ledger.db';
  static const List<String> _legacyDbNames = ['excavator_ledger.db'];
  static const int _dbVersion = 34;

  static int get schemaVersion => _dbVersion;

  // -------------------------------------------------------------------
  // 2.3 对外唯一入口：获取 Database 实例
  // -------------------------------------------------------------------
  static Future<Database> get database async {
    if (_db != null) return _db!;

    final pending = _dbFuture;
    if (pending != null) {
      final db = await pending;
      _db = db;
      return db;
    }

    final future = _openDatabaseOnce();
    _dbFuture = future;

    try {
      final db = await future;
      _db = db;
      return db;
    } finally {
      if (identical(_dbFuture, future)) {
        _dbFuture = null;
      }
    }
  }

  static Future<T> inTransaction<T>(
    Future<T> Function(Transaction txn) action,
  ) async {
    final db = await database;
    return db.transaction(action);
  }

  // =====================================================================
  // ============================== 三、初始化数据库 ==============================
  // =====================================================================

  static Future<Database> _openDatabaseOnce() {
    final override = debugInitDbOverride;
    if (override != null) {
      return override();
    }
    return _initDb();
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    await _migrateLegacyDbFileIfNeeded(dbPath);
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,

      // 3.1 每次打开：开启外键（你当前没用外键，但保留是好习惯）
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },

      // 3.2 首次创建
      onCreate: _onCreate,

      // 3.3 版本升级
      onUpgrade: _onUpgrade,

      // 3.4 打开后兜底校验：避免历史库结构漂移导致新字段不生效
      onOpen: (db) async {
        await DbSchemaCompat.ensure(db);
      },
    );
  }

  // =====================================================================
  // ============================== 四、建表：首次创建（onCreate） ==============================
  // =====================================================================

  static Future<void> _onCreate(Database db, int version) async {
    await DbSchema.create(db);
  }

  // =====================================================================
  // ============================== 五、升级：增量迁移（onUpgrade） ==============================
  // =====================================================================

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await DbMigrations.apply(db, oldVersion, newVersion);
  }

  /// 显式演示数据入口：仅在开发/演示模式下由上层主动调用
  static Future<void> seedDemoData() async {
    final db = await database;
    await DbSeed.seedDemoDataIfEmpty(db);
  }

  /// 测试辅助：清空单例缓存，避免测试之间复用打开的数据库句柄。
  static Future<void> resetForTest() async {
    final db = _db;
    _db = null;
    _dbFuture = null;
    debugInitDbOverride = null;
    if (db != null) {
      await db.close();
    }
  }

  static Future<void> _migrateLegacyDbFileIfNeeded(String dbPath) async {
    final newDbFile = File(join(dbPath, _dbName));
    if (await newDbFile.exists()) return;

    for (final legacyDbName in _legacyDbNames) {
      final legacyDbFile = File(join(dbPath, legacyDbName));
      if (!await legacyDbFile.exists()) continue;
      await legacyDbFile.rename(newDbFile.path);
      return;
    }
  }
}
