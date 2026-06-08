part of '../db_migrations.dart';

/// v29：timing_records 新增 nullable income_fen（R5.26-B3）。
///
/// income_fen 是 REAL income 的整数分镜像（round(income * 100)），与 income 双写。
/// 本片为 additive 迁移：只补列 + 回填，不重建表、不动 income REAL 的 NOT NULL
/// 语义、不切换读路径（应收/汇总本轮仍按 income REAL 计算，留待 B4）。
/// - hours 记录：income_fen 仅是 income 快照的 fen 镜像，应收仍由 hours × rate 重算。
/// - rent 记录：income_fen 同样由 income 回填；后续读路径切换时应逐记录证明与
///   Money.fromYuan(income).fen 等价。
/// ensure* 形式幂等，可由 DbSchemaCompat.ensure 在 onOpen 兜底已升级过的库：
/// 列缺失则 ADD，值为 NULL 则按 income 回填，已有非 NULL income_fen 不被覆盖。
class Migration029 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 29) {
      await ensureTimingIncomeFen(db);
    }
  }

  static Future<void> ensureTimingIncomeFen(Database db) async {
    if (!await _tableExists(db, 'timing_records')) {
      return;
    }

    await _addColumnIfMissing(db, 'timing_records', 'income_fen', 'INTEGER');

    // 防御：回填引用 income 列。生产 timing_records 始终含 income，但极简/历史
    // schema（如纯 FK 升级测试桩）可能缺 income，此时只补列、跳过回填，避免
    // 整条迁移链因 "no such column: income" 中断。
    if (!await _columnExists(db, 'timing_records', 'income')) {
      return;
    }

    await db.execute('''
      UPDATE timing_records
      SET income_fen = CAST(ROUND(income * 100) AS INTEGER)
      WHERE income_fen IS NULL;
    ''');
  }
}
