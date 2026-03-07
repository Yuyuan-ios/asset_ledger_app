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
    _db = await _initDb();
    return _db!;
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
        await _ensureSchemaCompat(db);
      },
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
        breaking_unit_price REAL,
        base_meter_hours REAL NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        custom_avatar_path TEXT,
        equipment_type TEXT NOT NULL DEFAULT 'excavator'
      );
    ''');

    // -------------------------- timing_records --------------------------
    // ✅ v7：增加 exclude_from_fuel_eff / is_breaking
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
        exclude_from_fuel_eff INTEGER NOT NULL DEFAULT 0,
        is_breaking INTEGER NOT NULL DEFAULT 0
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
        is_breaking INTEGER NOT NULL DEFAULT 0,
        rate REAL NOT NULL,
        PRIMARY KEY (project_key, device_id, is_breaking)
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_project_device_rates_project
      ON project_device_rates(project_key);
    ''');

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
          is_breaking INTEGER NOT NULL DEFAULT 0,
          rate REAL NOT NULL,
          PRIMARY KEY (project_key, device_id, is_breaking)
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

    // ✅ v6 -> v7：timing_records 增加 is_breaking
    if (oldVersion < 7) {
      await db.execute('''
        ALTER TABLE timing_records
        ADD COLUMN is_breaking INTEGER NOT NULL DEFAULT 0;
      ''');
    }

    // ✅ v7 -> v8：设备增加破碎默认单价；项目设备单价覆盖按模式拆分
    if (oldVersion < 8) {
      await db.execute('''
        ALTER TABLE devices
        ADD COLUMN breaking_unit_price REAL;
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS project_device_rates_v2 (
          project_key TEXT NOT NULL,
          device_id INTEGER NOT NULL,
          is_breaking INTEGER NOT NULL DEFAULT 0,
          rate REAL NOT NULL,
          PRIMARY KEY (project_key, device_id, is_breaking)
        );
      ''');

      await db.execute('''
        INSERT OR REPLACE INTO project_device_rates_v2 (
          project_key, device_id, is_breaking, rate
        )
        SELECT project_key, device_id, 0, rate
        FROM project_device_rates;
      ''');

      await db.execute('DROP TABLE IF EXISTS project_device_rates;');
      await db.execute(
        'ALTER TABLE project_device_rates_v2 RENAME TO project_device_rates;',
      );
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_project_device_rates_project
        ON project_device_rates(project_key);
      ''');
    }

    // ✅ v8 -> v9：设备增加 equipment_type
    if (oldVersion < 9) {
      await db.execute('''
        ALTER TABLE devices
        ADD COLUMN equipment_type TEXT NOT NULL DEFAULT 'excavator';
      ''');
    }
  }

  static Future<void> _ensureSchemaCompat(Database db) async {
    // devices.breaking_unit_price 兜底
    final deviceCols = await db.rawQuery('PRAGMA table_info(devices);');
    final hasBreakingUnitPrice = deviceCols.any(
      (row) => row['name'] == 'breaking_unit_price',
    );
    if (!hasBreakingUnitPrice) {
      await db.execute(
        'ALTER TABLE devices ADD COLUMN breaking_unit_price REAL;',
      );
    }

    final hasEquipmentType = deviceCols.any(
      (row) => row['name'] == 'equipment_type',
    );
    if (!hasEquipmentType) {
      await db.execute(
        "ALTER TABLE devices ADD COLUMN equipment_type TEXT NOT NULL DEFAULT 'excavator';",
      );
    }

    // project_device_rates 兜底：必须含 is_breaking 且主键为 3 列
    final rateCols = await db.rawQuery(
      'PRAGMA table_info(project_device_rates);',
    );
    final hasIsBreaking = rateCols.any((row) => row['name'] == 'is_breaking');
    final pkCols = rateCols
        .where((row) => ((row['pk'] as int?) ?? 0) > 0)
        .map((row) => row['name'] as String)
        .toList();
    final has3Key =
        pkCols.length == 3 &&
        pkCols.contains('project_key') &&
        pkCols.contains('device_id') &&
        pkCols.contains('is_breaking');

    if (!hasIsBreaking || !has3Key) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS project_device_rates_v8_fix (
          project_key TEXT NOT NULL,
          device_id INTEGER NOT NULL,
          is_breaking INTEGER NOT NULL DEFAULT 0,
          rate REAL NOT NULL,
          PRIMARY KEY (project_key, device_id, is_breaking)
        );
      ''');
      await db.execute('''
        INSERT OR REPLACE INTO project_device_rates_v8_fix (
          project_key, device_id, is_breaking, rate
        )
        SELECT project_key, device_id, 0, rate
        FROM project_device_rates;
      ''');
      await db.execute('DROP TABLE IF EXISTS project_device_rates;');
      await db.execute(
        'ALTER TABLE project_device_rates_v8_fix RENAME TO project_device_rates;',
      );
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_project_device_rates_project
        ON project_device_rates(project_key);
      ''');
    }
  }

  /// 显式演示数据入口：仅在开发/演示模式下由上层主动调用
  static Future<void> seedDemoData() async {
    final db = await database;

    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM devices'),
    ) ?? 0;
    if (count > 0) return;

    await inTransaction((txn) async {
      await txn.insert('devices', {
        'name': 'SANY 1#',
        'brand': 'SANY',
        'model': null,
        'default_unit_price': 350.0,
        'breaking_unit_price': null,
        'base_meter_hours': 0.0,
        'is_active': 1,
        'custom_avatar_path': null,
        'equipment_type': 'excavator',
      });

      await txn.insert('devices', {
        'name': 'SANY 2#',
        'brand': 'SANY',
        'model': null,
        'default_unit_price': 360.0,
        'breaking_unit_price': null,
        'base_meter_hours': 120.0,
        'is_active': 1,
        'custom_avatar_path': null,
        'equipment_type': 'excavator',
      });
    });
  }
}
