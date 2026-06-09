import 'dart:io';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/db/db_schema_compat.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_setup.dart';

/// R5.26-B0.5：money fen 主存迁移前的 no-NULL 安全网（test-only）。
///
/// 目标：在不改 schema、不做 migration、不改生产逻辑的前提下，钉死
/// `account_payments.amount_fen` 与 `project_write_offs.amount_fen` 在现有
/// migration / DbSchemaCompat.ensure / onOpen 路径中**永远不会残留 NULL**，
/// 为后续 R5.26-B1 / B2 把这两列改成 NOT NULL（需重建表）提供前置保障。
///
/// 覆盖三类 legacy 场景：
/// - 场景 A：fen 列缺失（pre-v18 历史库）→ 升级链补列 + 回填。
/// - 场景 B：fen 列已存在但值为 NULL（结构漂移）→ ensure 自愈。
/// - 回填语义：只填 NULL，不覆盖既有 fen 值（B1/B2 重建表的 COALESCE 依据）。
///
/// schema readiness 现状（随 B 系列推进）：project_write_offs.amount_fen（R5.26-B2）
/// 与 account_payments.amount_fen（R5.26-B1）均已重建为 NOT NULL。当前 schema 已不
/// 允许这两列插入 NULL，故场景 B / no-clobber 改用 legacy-nullable 桩（DROP+CREATE
/// 为 nullable amount_fen 形态）复刻漂移前提，再调 ensure 验证自愈与不覆盖语义。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late Directory tmpDir;
  late String dbPath;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('money_fen_no_null_');
    dbPath = p.join(tmpDir.path, 'asset_ledger.db');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  // ---------------------------------------------------------------------------
  // 场景 A：pre-v18 历史库（fen 列缺失）经真实开库路径后无 NULL。
  // ---------------------------------------------------------------------------
  test(
    'legacy pre-v18 db (amount_fen column missing) backfills non-null fen for '
    'all account_payments and project_write_offs rows after real open path',
    () async {
      // 1) 构造一个 v17 历史库：全量 schema 后把两张钱表重建成缺 fen 列的旧形态，
      //    再插入多行（含易触发浮点 round 的金额），并保留一行的既有非 NULL 行为
      //    （此处所有行都缺 fen 列，模拟真正的 pre-v18 数据）。
      final legacy = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 17,
          onConfigure: _enableForeignKeys,
          onCreate: (db, _) async {
            await DbSchema.create(db);
            await _recreateMoneyTablesWithoutFen(db);
            await _insertProject(db, id: 'project:money');

            await db.insert('account_payments', {
              'id': 1,
              'project_id': 'project:money',
              'project_key': '甲方||金额工地',
              'ymd': 20260518,
              'amount': 123.45,
              'source_type': 'merge_allocation',
              'merge_batch_id': 'batch-money',
              'merge_batch_total_amount': 5000.01,
              'created_at': '2026-05-18T00:00:00.000Z',
            });
            await db.insert('account_payments', {
              'id': 2,
              'project_id': 'project:money',
              'project_key': '甲方||金额工地',
              'ymd': 20260519,
              'amount': 0.1,
              'source_type': 'manual',
            });
            await db.insert('account_payments', {
              'id': 3,
              'project_id': 'project:money',
              'project_key': '甲方||金额工地',
              'ymd': 20260520,
              'amount': 19.99,
              'source_type': 'manual',
            });

            await db.insert('project_write_offs', {
              'id': 'wo-1',
              'project_id': 'project:money',
              'amount': 6.78,
              'reason': 'rounding',
              'write_off_date': '2026-05-18',
              'created_at': '2026-05-18T00:00:00.000Z',
              'updated_at': '2026-05-18T00:00:00.000Z',
            });
            await db.insert('project_write_offs', {
              'id': 'wo-2',
              'project_id': 'project:money',
              'amount': 0.03,
              'reason': 'bad_debt',
              'write_off_date': '2026-05-19',
              'created_at': '2026-05-19T00:00:00.000Z',
              'updated_at': '2026-05-19T00:00:00.000Z',
            });
          },
        ),
      );
      // sanity：旧库确实缺 fen 列。
      expect(
        await _columnExists(legacy, 'account_payments', 'amount_fen'),
        isFalse,
      );
      await legacy.close();

      // 2) 用与生产一致的开库路径重开（onUpgrade=迁移链，onOpen=兜底 ensure）。
      final db = await _openCurrentDb(dbPath);
      try {
        // 列已补齐。
        expect(
          await _columnExists(db, 'account_payments', 'amount_fen'),
          isTrue,
        );
        expect(
          await _columnExists(
            db,
            'account_payments',
            'merge_batch_total_amount_fen',
          ),
          isTrue,
        );
        expect(
          await _columnExists(db, 'project_write_offs', 'amount_fen'),
          isTrue,
        );

        // 核心不变式：两表均无 NULL amount_fen。
        expect(await _nullFenCount(db, 'account_payments'), 0);
        expect(await _nullFenCount(db, 'project_write_offs'), 0);

        // 行数无丢失。
        expect(await _rowCount(db, 'account_payments'), 3);
        expect(await _rowCount(db, 'project_write_offs'), 2);

        // 逐行 fen == round(amount*100)，且 REAL amount 兼容列仍保留原值。
        await _expectFenMatchesAmount(db, 'account_payments');
        await _expectFenMatchesAmount(db, 'project_write_offs');

        // merge_batch_total_amount_fen 同样被回填（有 merge 总额的那一行）。
        final mergeRow = (await db.query(
          'account_payments',
          where: 'id = ?',
          whereArgs: [1],
        )).single;
        expect(mergeRow['amount_fen'], 12345);
        expect(mergeRow['merge_batch_total_amount_fen'], 500001);
        // 其它列未被测试构造误判 / 未丢失。
        expect(mergeRow['source_type'], 'merge_allocation');
        expect(mergeRow['merge_batch_id'], 'batch-money');
        expect(mergeRow['created_at'], '2026-05-18T00:00:00.000Z');
      } finally {
        await db.close();
      }
    },
  );

  // ---------------------------------------------------------------------------
  // 场景 B：结构漂移（fen 列在、值为 NULL）经 onOpen ensure 自愈。
  //
  // R5.26-B1/B2 后两列均 NOT NULL，当前 schema 已无法插入 amount_fen=NULL，故用
  // legacy-nullable 桩（DROP+CREATE account_payments 为 nullable amount_fen 形态）
  // 复刻漂移前提，再调 ensureMoneyFenSchema + ensureAccountPaymentAmountFenNotNull
  // 验证自愈为 NOT NULL / 无 NULL / COALESCE 正确。
  // ---------------------------------------------------------------------------
  test(
    'drifted nullable account_payments.amount_fen (with NULL) is healed to '
    'NOT NULL by ensure (onOpen-equivalent path)',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onConfigure: _enableForeignKeys,
          onCreate: (db, _) async {
            await DbSchema.create(db);
            await _recreateAccountPaymentsNullable(db);
            await _insertProject(db, id: 'project:drift');
            await db.insert('account_payments', {
              'id': 1,
              'project_id': 'project:drift',
              'project_key': '甲方||漂移工地',
              'ymd': 20260601,
              'amount': 88.80,
              'amount_fen': null,
            });
          },
        ),
      );
      try {
        // sanity：列在、nullable、值为 NULL。
        expect(await _columnExists(db, 'account_payments', 'amount_fen'), isTrue);
        expect(
          await _isColumnNullable(db, 'account_payments', 'amount_fen'),
          isTrue,
        );
        expect(await _nullFenCount(db, 'account_payments'), 1);

        // 兜底回填（ensureMoneyFenSchema）+ 重建为 NOT NULL（B1）。
        await DbMigrations.ensureMoneyFenSchema(db);
        await DbMigrations.ensureAccountPaymentAmountFenNotNull(db);

        // 列翻为 NOT NULL，NULL 被自愈为 round(amount*100)。
        expect(
          await _isColumnNullable(db, 'account_payments', 'amount_fen'),
          isFalse,
        );
        expect(await _nullFenCount(db, 'account_payments'), 0);
        expect(
          (await db.query('account_payments')).single['amount_fen'],
          8880,
        );
      } finally {
        await db.close();
      }
    },
  );

  // ---------------------------------------------------------------------------
  // 回填语义：只填 NULL，不覆盖既有 fen 值。
  // ---------------------------------------------------------------------------
  test(
    'money fen backfill fills only NULL rows and never clobbers an existing '
    'fen value, and is idempotent',
    () async {
      // B1 后当前 schema 不允许插 amount_fen=NULL，故用 legacy-nullable 桩复刻
      // 「一行 NULL、一行明确非 round(amount*100) 值」，验证 ensureMoneyFenSchema 的
      // no-clobber 语义（只填 NULL、不覆盖既有 fen）。
      final db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onConfigure: _enableForeignKeys,
          onCreate: (db, _) async {
            await DbSchema.create(db);
            await _recreateAccountPaymentsNullable(db);
            await _insertProject(db, id: 'project:keep');
            // 一行 fen=NULL（待回填）。
            await db.insert('account_payments', {
              'id': 1,
              'project_id': 'project:keep',
              'project_key': '甲方||保留工地',
              'ymd': 20260601,
              'amount': 50.0,
              'amount_fen': null,
            });
            // 一行 fen 故意与 amount 不一致且非 NULL（必须保留，不被回填覆盖）。
            await db.insert('account_payments', {
              'id': 2,
              'project_id': 'project:keep',
              'project_key': '甲方||保留工地',
              'ymd': 20260602,
              'amount': 100.0,
              'amount_fen': 1,
            });
          },
        ),
      );
      try {
        // 跑两次，验证幂等。
        await DbMigrations.ensureMoneyFenSchema(db);
        await DbMigrations.ensureMoneyFenSchema(db);

        expect(await _nullFenCount(db, 'account_payments'), 0);
        // NULL 行被回填到 round(50*100)=5000。
        expect(
          (await db.query(
            'account_payments',
            where: 'id = ?',
            whereArgs: [1],
          )).single['amount_fen'],
          5000,
        );
        // 既有非 NULL 行的 fen=1 不被覆盖（即便与 amount 不一致）。
        expect(
          (await db.query(
            'account_payments',
            where: 'id = ?',
            whereArgs: [2],
          )).single['amount_fen'],
          1,
        );
      } finally {
        await db.close();
      }
    },
  );

  // ---------------------------------------------------------------------------
  // Schema readiness：两列均已 NOT NULL（B1 + B2 done）。
  // ---------------------------------------------------------------------------
  test(
    'fresh schema at current version: both account_payments.amount_fen and '
    'project_write_offs.amount_fen are NOT NULL (B1 + B2 done)',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onCreate: (db, _) => DbSchema.create(db),
        ),
      );
      try {
        // ⚠️ canary：R5.26-B1 已把 account_payments.amount_fen 重建为 NOT NULL；
        //    R5.26-B2 已把 project_write_offs.amount_fen 重建为 NOT NULL。
        expect(
          await _isColumnNullable(db, 'account_payments', 'amount_fen'),
          isFalse,
          reason: 'B1 done: account_payments.amount_fen 已是 NOT NULL',
        );
        expect(
          await _isColumnNullable(db, 'project_write_offs', 'amount_fen'),
          isFalse,
          reason: 'B2 done: project_write_offs.amount_fen 已是 NOT NULL',
        );

        // REAL 兼容列仍保留且仍 NOT NULL（本轮不动 REAL 主口径列）。
        expect(
          await _columnExists(db, 'account_payments', 'amount'),
          isTrue,
        );
        expect(
          await _isColumnNullable(db, 'account_payments', 'amount'),
          isFalse,
        );
        expect(
          await _columnExists(db, 'project_write_offs', 'amount'),
          isTrue,
        );
        expect(
          await _isColumnNullable(db, 'project_write_offs', 'amount'),
          isFalse,
        );
      } finally {
        await db.close();
      }
    },
  );
}

// ===========================================================================
// Helpers
// ===========================================================================

Future<void> _enableForeignKeys(Database db) async {
  await db.execute('PRAGMA foreign_keys = ON');
}

Future<Database> _openCurrentDb(String path) {
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: AppDatabase.schemaVersion,
      onConfigure: _enableForeignKeys,
      onCreate: (db, _) => DbSchema.create(db),
      onUpgrade: DbMigrations.apply,
      onOpen: (db) => DbSchemaCompat.ensure(db),
    ),
  );
}

Future<void> _insertProject(DatabaseExecutor db, {required String id}) async {
  await db.insert(
    'projects',
    Project(
      id: id,
      contact: '甲方',
      site: '金额工地',
      createdAt: '2026-05-18T00:00:00.000Z',
      updatedAt: '2026-05-18T00:00:00.000Z',
    ).toMap(),
  );
}

/// 把两张钱表重建成 pre-v18 旧形态（无 amount_fen / merge_batch_total_amount_fen）。
Future<void> _recreateMoneyTablesWithoutFen(DatabaseExecutor db) async {
  await db.execute('DROP INDEX IF EXISTS idx_account_payments_project_ymd;');
  await db.execute('DROP INDEX IF EXISTS idx_project_write_offs_project_id;');
  await db.execute(
    'DROP INDEX IF EXISTS idx_project_write_offs_write_off_date;',
  );
  await db.execute('DROP TABLE IF EXISTS account_payments;');
  await db.execute('DROP TABLE IF EXISTS project_write_offs;');

  await db.execute('''
    CREATE TABLE account_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      project_id TEXT NOT NULL,
      project_key TEXT NOT NULL,
      ymd INTEGER NOT NULL,
      amount REAL NOT NULL,
      note TEXT,
      source_type TEXT NOT NULL DEFAULT 'manual',
      merge_group_id INTEGER,
      merge_batch_id TEXT,
      merge_batch_total_amount REAL,
      merge_batch_note TEXT,
      created_at TEXT,
      FOREIGN KEY (project_id)
        REFERENCES projects(id) ON DELETE RESTRICT
    );
  ''');
  await db.execute('''
    CREATE INDEX idx_account_payments_project_ymd
    ON account_payments(project_id, ymd);
  ''');

  await db.execute('''
    CREATE TABLE project_write_offs (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      amount REAL NOT NULL CHECK (amount > 0),
      reason TEXT NOT NULL,
      note TEXT,
      write_off_date TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (project_id)
        REFERENCES projects(id) ON DELETE RESTRICT
    );
  ''');
  await db.execute('''
    CREATE INDEX idx_project_write_offs_project_id
    ON project_write_offs(project_id);
  ''');
  await db.execute('''
    CREATE INDEX idx_project_write_offs_write_off_date
    ON project_write_offs(write_off_date);
  ''');
}

/// 把 account_payments 退回 nullable amount_fen 形态（当前 14 列集，仅 amount_fen
/// 可空），用于复刻 B1 落地后「结构漂移出 NULL」的前提。
Future<void> _recreateAccountPaymentsNullable(DatabaseExecutor db) async {
  await db.execute('DROP INDEX IF EXISTS idx_account_payments_project_ymd;');
  await db.execute('DROP TABLE IF EXISTS account_payments;');
  await db.execute('''
    CREATE TABLE account_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      project_id TEXT NOT NULL,
      project_key TEXT NOT NULL,
      ymd INTEGER NOT NULL,
      amount REAL NOT NULL,
      amount_fen INTEGER,
      note TEXT,
      source_type TEXT NOT NULL DEFAULT 'manual',
      merge_group_id INTEGER,
      merge_batch_id TEXT,
      merge_batch_total_amount REAL,
      merge_batch_total_amount_fen INTEGER,
      merge_batch_note TEXT,
      created_at TEXT,
      FOREIGN KEY (project_id)
        REFERENCES projects(id) ON DELETE RESTRICT
    );
  ''');
  await db.execute('''
    CREATE INDEX idx_account_payments_project_ymd
    ON account_payments(project_id, ymd);
  ''');
}

Future<bool> _columnExists(
  DatabaseExecutor db,
  String table,
  String column,
) async {
  final rows = await db.rawQuery('PRAGMA table_info($table);');
  return rows.any((row) => row['name'] == column);
}

/// PRAGMA table_info 的 notnull==0 表示该列允许 NULL。
Future<bool> _isColumnNullable(
  DatabaseExecutor db,
  String table,
  String column,
) async {
  final rows = await db.rawQuery('PRAGMA table_info($table);');
  final info = rows.firstWhere(
    (row) => row['name'] == column,
    orElse: () => const <String, Object?>{},
  );
  expect(info.isNotEmpty, isTrue, reason: '列 $table.$column 不存在');
  return ((info['notnull'] as int?) ?? 0) == 0;
}

Future<int> _nullFenCount(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS c FROM $table WHERE amount_fen IS NULL',
  );
  return (rows.single['c'] as num?)?.toInt() ?? 0;
}

Future<int> _rowCount(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
  return (rows.single['c'] as num?)?.toInt() ?? 0;
}

/// 逐行断言 amount_fen == round(amount*100)，且 amount REAL 仍为原值。
Future<void> _expectFenMatchesAmount(
  DatabaseExecutor db,
  String table,
) async {
  final rows = await db.query(table);
  expect(rows, isNotEmpty);
  for (final row in rows) {
    final amount = (row['amount'] as num).toDouble();
    final fen = (row['amount_fen'] as num?)?.toInt();
    expect(fen, isNotNull, reason: '$table row ${row['id']} amount_fen 不应为 NULL');
    expect(
      fen,
      (amount * 100).round(),
      reason: '$table row ${row['id']} amount_fen 应等于 round(amount*100)',
    );
  }
}
