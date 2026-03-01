// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

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
// - 本年度燃油汇总（农历年度映射）
// - supplier 可选过滤
//
// ⚠️ 注意：
// - 这里先提供“农历年度区间计算”的接口与默认实现（简化版）
// - 你后续要做到“真正农历”时，只需要替换 _resolveLunarYearRange(...) 的实现
//   其他代码无需动（保证架构稳定）
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
    // ① 得到本年度（农历映射）的起止区间
    final range = _resolveLunarYearRange(nowYmd);

    // ② 供应人过滤（可空）
    final s = (supplier ?? '').trim();

    double litersSum = 0.0;
    double costSum = 0.0;

    for (final x in logs) {
      // ③ 年度区间过滤
      if (x.date < range.startYmd || x.date > range.endYmd) continue;

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
      yearLabel: range.yearLabel,
      liters: litersSum,
      cost: costSum,
    );
  }

  // =====================================================================
  // ============================== 五、年度区间（农历映射） ==============================
  // =====================================================================
  //
  // ✅ 你已确认口径：
  // - 数据存公历（YYYYMMDD）不变
  // - 统计按农历年度：正月初一 ~ 除夕
  //
  // 但：真正农历需要算法/库支持（这期先不扩复杂度）
  //
  // 所以这里先做“架构正确的占位实现”：
  // - 默认返回公历年度 0101 ~ 1231
  // - 后续引入农历库时：只改这里即可
  //
  // 这样：FuelPage / FuelStore / Widget 完全不用改
  // =====================================================================

  static _YearRange _resolveLunarYearRange(int nowYmd) {
    // ---------------------------------------------------------------
    // ✅ 占位实现（本期先保证闭环）：
    // - yearLabel = 公历年
    // - start = YYYY0101
    // - end   = YYYY1231
    //
    // 后续升级为真正农历：
    // - 根据 nowYmd -> 计算所属农历年
    // - 再推导该农历年正月初一的公历日 与 除夕公历日
    // ---------------------------------------------------------------
    final y = nowYmd ~/ 10000;
    final start = y * 10000 + 101;
    final end = y * 10000 + 1231;

    return _YearRange(yearLabel: y, startYmd: start, endYmd: end);
  }
}

// =====================================================================
// ============================== 六、内部结构：年度区间 ==============================
// =====================================================================
//
// 说明：
// - yearLabel：用于 UI 展示“本年度”对应的年份标识
// - startYmd/endYmd：区间（闭区间）
// =====================================================================

class _YearRange {
  final int yearLabel;
  final int startYmd;
  final int endYmd;

  const _YearRange({
    required this.yearLabel,
    required this.startYmd,
    required this.endYmd,
  });
}
