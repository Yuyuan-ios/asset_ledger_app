/// 计时图表渲染输入模型。
///
/// 说明：
/// - 该模型是 Page -> Pattern 的纯数据载体，不承载业务计算；
/// - 收入值由 TimingMonthlyIncomeService 按 realtime 口径先行计算后注入；
/// - 图表固定渲染 12 个月，targetMonth 用于表达当前统计目标月语义。
class TimingChartData {
  const TimingChartData({
    required this.year,
    required this.targetMonth,
    required this.monthLabels,
    required this.incomeBars,
    required this.expenseBars,
    required this.totalIncomeText,
    required this.totalExpenseText,
  });

  final int year;
  /// 收入分摊使用的有效目标月（1-12）。
  /// 图表始终渲染 12 个月；targetMonth 之后月份在当前统计视图下保持为 0。
  final int targetMonth;
  final List<String> monthLabels;
  final List<double> incomeBars;
  final List<double> expenseBars;
  final String totalIncomeText;
  final String totalExpenseText;
}
