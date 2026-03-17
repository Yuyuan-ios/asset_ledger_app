// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

// 1.1 SQLite 插件：sqflite
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
  // -------------------------------------------------------------------
  static const String _dbName = 'excavator_ledger.db';
  static const int _dbVersion = 9;

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
}
