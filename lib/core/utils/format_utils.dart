// =====================================================================
// ============================== 通用格式化工具 ==============================
// =====================================================================
//
// 目标：
// - 把 toStringAsFixed / YYYYMMDD 解析逻辑收口
// - 确保全 App 金额/工时/日期显示风格一致
//
// 约定：
// - 存储层默认今天日期的唯一真相：FormatUtils.todayYmd()
// - 展示层默认今天日期：FormatUtils.todayDisplayDate()
// =====================================================================

enum DateDisplayStyle { yyyymmdd, yyyyMmDd, yyyyDotMmDotDd }

class FormatUtils {
  /// 全局日期显示格式口径（改这一处，全 App 日期显示统一）
  static const DateDisplayStyle dateDisplayStyle =
      DateDisplayStyle.yyyyDotMmDotDd;

  // -------------------------------------------------------------------
  // 日期输入统一文案（表单口径）
  // -------------------------------------------------------------------
  static String get ymdInputLabel {
    switch (dateDisplayStyle) {
      case DateDisplayStyle.yyyymmdd:
        return '日期（YYYYMMDD）';
      case DateDisplayStyle.yyyyMmDd:
        return '日期（YYYY-MM-DD）';
      case DateDisplayStyle.yyyyDotMmDotDd:
        return '日期（YYYY.MM.DD）';
    }
  }

  static String get ymdInputHint {
    switch (dateDisplayStyle) {
      case DateDisplayStyle.yyyymmdd:
        return '例如：20260208';
      case DateDisplayStyle.yyyyMmDd:
        return '例如：2026-02-08';
      case DateDisplayStyle.yyyyDotMmDotDd:
        return '例如：2026.02.08';
    }
  }

  static String get ymdInvalidMsg => '日期格式应为 ${_datePatternText()}';

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
    switch (dateDisplayStyle) {
      case DateDisplayStyle.yyyymmdd:
        return '$y$m$d';
      case DateDisplayStyle.yyyyMmDd:
        return '$y-$m-$d';
      case DateDisplayStyle.yyyyDotMmDotDd:
        return '$y.$m.$d';
    }
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
  // 6. 百分比：12.3%
  // -------------------------------------------------------------------
  static String percent1(double? ratio) {
    if (ratio == null) return '-';
    return '${(ratio * 100).toStringAsFixed(1)}%';
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
  // - 默认今天日期与日期格式口径统一收口
  // - 存储值使用 todayYmd()，显示值使用 todayDisplayDate()
  // =====================================================================

  /// 存储层默认今天日期（YYYYMMDD）
  static String todayYmd({DateTime? now}) {
    final t = now ?? DateTime.now();
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  /// 仅用于 UI 输入框默认显示（遵循全局显示口径）
  static String todayDisplayDate({DateTime? now}) {
    return date(ymdFromDate(now ?? DateTime.now()));
  }

  /// YYYYMMDD(int) -> DateTime
  static DateTime dateFromYmd(int ymd) {
    final y = ymd ~/ 10000;
    final m = (ymd ~/ 100) % 100;
    final d = ymd % 100;
    return DateTime(y, m, d);
  }

  /// DateTime -> YYYYMMDD(int)
  static int ymdFromDate(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  static String _datePatternText() {
    switch (dateDisplayStyle) {
      case DateDisplayStyle.yyyymmdd:
        return 'YYYYMMDD（例如 20260208）';
      case DateDisplayStyle.yyyyMmDd:
        return 'YYYY-MM-DD（例如 2026-02-08）';
      case DateDisplayStyle.yyyyDotMmDotDd:
        return 'YYYY.MM.DD（例如 2026.02.08）';
    }
  }
}
