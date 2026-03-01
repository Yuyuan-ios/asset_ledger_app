// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

// 1.1 SQLite 插件：sqflite
import 'package:sqflite/sqflite.dart';

// 1.2 路径拼接：path
import 'package:path/path.dart';

// =====================================================================
// ============================== 二、数据库单例 AppDatabase ==============================
// =====================================================================

class AppDatabase {
  // -------------------------------------------------------------------
  // 2.1 单例缓存：避免重复 openDatabase
  // -------------------------------------------------------------------
  static Database? _db;

  // -------------------------------------------------------------------
  // 2.2 数据库文件名 & 版本号
  //
  // 版本策略：
  // - v2：devices 增加 custom_avatar_path
  // - v3：fuel_logs 增加 supplier
  // - v4：新增 maintenance_records（维保）
  // - v5：新增 account_payments（收款） + project_device_rates（项目×设备单价覆盖）
  // - v6：timing_records 增加 exclude_from_fuel_eff（包油：不计入燃油效率）
  // -------------------------------------------------------------------
  static const String _dbName = 'excavator_ledger.db';
  static const int _dbVersion = 6;

  // -------------------------------------------------------------------
  // 2.3 对外唯一入口：获取 Database 实例
  // -------------------------------------------------------------------
  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  // =====================================================================
  // ============================== 三、初始化数据库 ==============================
  // =====================================================================

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
    );
  }

  // =====================================================================
  // ============================== 四、建表：首次创建（onCreate） ==============================
  // =====================================================================

  static Future<void> _onCreate(Database db, int version) async {
    // ----------------------------- devices -----------------------------
    await db.execute('''
      CREATE TABLE devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        brand TEXT NOT NULL,
        model TEXT,
        default_unit_price REAL NOT NULL,
        base_meter_hours REAL NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        custom_avatar_path TEXT
      );
    ''');

    // -------------------------- timing_records --------------------------
    // ✅ v6：增加 exclude_from_fuel_eff
    await db.execute('''
      CREATE TABLE timing_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER NOT NULL,
        start_date INTEGER NOT NULL,
        contact TEXT NOT NULL,
        site TEXT NOT NULL,
        type TEXT NOT NULL,
        start_meter REAL NOT NULL,
        end_meter REAL NOT NULL,
        hours REAL NOT NULL,
        income REAL NOT NULL,
        exclude_from_fuel_eff INTEGER NOT NULL DEFAULT 0
      );
    ''');

    // ---------------------------- fuel_logs ----------------------------
    await db.execute('''
      CREATE TABLE fuel_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER NOT NULL,
        date INTEGER NOT NULL,
        supplier TEXT NOT NULL,
        liters REAL NOT NULL,
        cost REAL NOT NULL
      );
    ''');

    // ----------------------- maintenance_records -----------------------
    await db.execute('''
      CREATE TABLE maintenance_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER,
        ymd INTEGER NOT NULL,
        item TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT
      );
    ''');

    // ------------------------ account_payments -------------------------
    await db.execute('''
      CREATE TABLE account_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_key TEXT NOT NULL,
        ymd INTEGER NOT NULL,
        amount REAL NOT NULL,
        note TEXT
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_account_payments_project_ymd
      ON account_payments(project_key, ymd);
    ''');

    // --------------------- project_device_rates ------------------------
    await db.execute('''
      CREATE TABLE project_device_rates (
        project_key TEXT NOT NULL,
        device_id INTEGER NOT NULL,
        rate REAL NOT NULL,
        PRIMARY KEY (project_key, device_id)
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_project_device_rates_project
      ON project_device_rates(project_key);
    ''');

    // ----------------------------- 演示数据 -----------------------------
    await db.insert('devices', {
      'name': 'SANY 1#',
      'brand': 'SANY',
      'model': null,
      'default_unit_price': 350.0,
      'base_meter_hours': 0.0,
      'is_active': 1,
      'custom_avatar_path': null,
    });

    await db.insert('devices', {
      'name': 'SANY 2#',
      'brand': 'SANY',
      'model': null,
      'default_unit_price': 360.0,
      'base_meter_hours': 120.0,
      'is_active': 1,
      'custom_avatar_path': null,
    });
  }

  // =====================================================================
  // ============================== 五、升级：增量迁移（onUpgrade） ==============================
  // =====================================================================

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // v1 -> v2：devices 增加 custom_avatar_path
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE devices ADD COLUMN custom_avatar_path TEXT;',
      );
    }

    // v2 -> v3：fuel_logs 增加 supplier
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE fuel_logs ADD COLUMN supplier TEXT NOT NULL DEFAULT '';",
      );
    }

    // v3 -> v4：新增 maintenance_records
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS maintenance_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id INTEGER,
          ymd INTEGER NOT NULL,
          item TEXT NOT NULL,
          amount REAL NOT NULL,
          note TEXT
        );
      ''');
    }

    // v4 -> v5：新增 account_payments + project_device_rates
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS account_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          project_key TEXT NOT NULL,
          ymd INTEGER NOT NULL,
          amount REAL NOT NULL,
          note TEXT
        );
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_account_payments_project_ymd
        ON account_payments(project_key, ymd);
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS project_device_rates (
          project_key TEXT NOT NULL,
          device_id INTEGER NOT NULL,
          rate REAL NOT NULL,
          PRIMARY KEY (project_key, device_id)
        );
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_project_device_rates_project
        ON project_device_rates(project_key);
      ''');
    }

    // ✅ v5 -> v6：timing_records 增加 exclude_from_fuel_eff
    if (oldVersion < 6) {
      await db.execute('''
        ALTER TABLE timing_records
        ADD COLUMN exclude_from_fuel_eff INTEGER NOT NULL DEFAULT 0;
      ''');
    }
  }
}
