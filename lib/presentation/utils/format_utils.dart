// =====================================================================
// ============================== 通用格式化工具 ==============================
// =====================================================================
//
// 目标：
// - 把 toStringAsFixed / YYYYMMDD 解析逻辑收口
// - 确保全 App 金额/工时/日期显示风格一致
//
// 约定：
// - “默认今天日期”的唯一真相：FormatUtils.todayYmd()
// - SuggestService 中的 todayYmd / suggestTodayYmd 仅作为兼容入口（转调）
// =====================================================================

class FormatUtils {
  // -------------------------------------------------------------------
  // 1. 金额：¥1,234.5（当前简化版：不做千分位）
  // -------------------------------------------------------------------
  static String money(double amount) {
    return '¥${amount.toStringAsFixed(0)}';
  }

  // -------------------------------------------------------------------
  // 2. 工时：12.5 h
  // -------------------------------------------------------------------
  static String hours(double h) {
    return '${h.toStringAsFixed(1)} h';
  }

  // -------------------------------------------------------------------
  // 3. 码表：1234.5
  // -------------------------------------------------------------------
  static String meter(double m) {
    return m.toStringAsFixed(1);
  }

  // -------------------------------------------------------------------
  // 4. 日期：int (20250101) -> String (2025-01-01)
  // -------------------------------------------------------------------
  static String date(int dateInt) {
    final s = dateInt.toString();
    if (s.length != 8) return s; // 容错：如果不满8位直接返回原样

    final y = s.substring(0, 4);
    final m = s.substring(4, 6);
    final d = s.substring(6, 8);
    return '$y-$m-$d';
  }

  // -------------------------------------------------------------------
  // 5. 解析日期：支持 YYYYMMDD / YYYY-MM-DD / YYYY.MM.DD
  // - 返回 int (20250101)
  // -------------------------------------------------------------------
  static int? parseDate(String s) {
    final clean = s
        .trim()
        .replaceAll('-', '')
        .replaceAll('.', '')
        .replaceAll('/', '');

    if (clean.length != 8) return null; // 强口径：必须8位
    return int.tryParse(clean);
  }

  // -------------------------------------------------------------------
  // 6. 升数：12.3
  // -------------------------------------------------------------------
  static String liters(double l) {
    return l.toStringAsFixed(1);
  }

  // -------------------------------------------------------------------
  // 7. 金额纯数字：1234.5（用于表单输入框，不带 ¥）
  // -------------------------------------------------------------------
  static String moneyNumber(double amount) {
    return amount.toStringAsFixed(1);
  }

  // =====================================================================
  // ============================== 日期工具（口径收口点） ==============================
  // =====================================================================
  //
  // 设计目标：
  // - “默认今天日期”与“日期格式口径”的唯一真相
  // - Page/Store 若要默认今天，一律使用 FormatUtils.todayYmd()
  // =====================================================================

  /// ✅ 当前口径唯一真相：默认日期只用 YYYYMMDD
  static String todayYmd({DateTime? now}) {
    final t = now ?? DateTime.now();
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  /// ✅ 兼容：将来需要其它展示格式时再用（不参与默认逻辑）
  static List<String> todayFormats({DateTime? now}) {
    final t = now ?? DateTime.now();
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return ['$y$m$d', '$y-$m-$d', '$y.$m.$d'];
  }
}
