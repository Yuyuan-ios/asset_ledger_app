// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import '../../core/date/gregorian_year_range.dart';
import '../models/fuel_log.dart';

// =====================================================================
// ============================== 二、FuelYearSummary（年度汇总 DTO） ==============================
// =====================================================================
//
// 设计目标：
// - 作为统计结果的数据载体（Service -> Store/Page/Widget）
// - 不耦合 UI 文案（文案由 Widget 层拼）
//
// 字段说明：
// - yearLabel：本年度标签（例如 2026）
// - liters：总升数
// - cost：总金额
// =====================================================================

class FuelYearSummary {
  final int yearLabel;
  final double liters;
  final double cost;

  const FuelYearSummary({
    required this.yearLabel,
    required this.liters,
    required this.cost,
  });

  FuelYearSummary copyWith({int? yearLabel, double? liters, double? cost}) {
    return FuelYearSummary(
      yearLabel: yearLabel ?? this.yearLabel,
      liters: liters ?? this.liters,
      cost: cost ?? this.cost,
    );
  }

  @override
  String toString() =>
      'FuelYearSummary(year=$yearLabel, liters=$liters, cost=$cost)';
}

// =====================================================================
// ============================== 三、FuelStatsService（统计服务） ==============================
// =====================================================================
//
// 设计目标（架构原则）：
// - 统计逻辑属于 Service（可复用、可测试）
// - Store/Page 不写复杂聚合/口径
//
// 本期实现：
// - 本年度燃油汇总（公历年度）
// - supplier 可选过滤
// =====================================================================

class FuelStatsService {
  const FuelStatsService._();

  // =====================================================================
  // ============================== 四、对外主入口 ==============================
  // =====================================================================

  // -------------------------------------------------------------------
  // 4.1 本年度汇总（供应人可选）
  //
  // 入参：
  // - logs：FuelStore.logs（全量）
  // - nowYmd：今天（YYYYMMDD），由页面/Store 注入，方便测试
  // - supplier：可选；为空则统计全部供应人
  //
  // 返回：
  // - FuelYearSummary：本年度 liters/cost
  // -------------------------------------------------------------------
  static FuelYearSummary summarizeCurrentYear({
    required List<FuelLog> logs,
    required int nowYmd,
    String? supplier,
  }) {
    // ① 得到本年度（公历年）的起止区间
    final range = GregorianYearRange.containingYmd(nowYmd);

    // ② 供应人过滤（可空）
    final s = (supplier ?? '').trim();

    double litersSum = 0.0;
    double costSum = 0.0;

    for (final x in logs) {
      // ③ 年度区间过滤
      if (!range.containsYmd(x.date)) continue;

      // ④ supplier 过滤（精确匹配 or 包含匹配？）
      // 说明：
      // - 统计口径：你希望输入供应人时快速筛选
      // - 这里按“包含匹配”更宽松；后续可改成精确匹配
      if (s.isNotEmpty) {
        if (!x.supplier.contains(s)) continue;
      }

      litersSum += x.liters;
      costSum += x.cost;
    }

    return FuelYearSummary(
      yearLabel: range.year,
      liters: litersSum,
      cost: costSum,
    );
  }
}
