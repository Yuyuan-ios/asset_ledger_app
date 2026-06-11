/// 计量值的定标整数表示（《机账通商业与实现纲要》§3 / §10.2）。
///
/// quantity_scaled = 计量值 × 1000(7.5h→7500、12.5亩→12500、3趟→3000),
/// 是落账的唯一权威工作量;码表起止、地块面积、架次等只是求它的辅助原始值。
/// 与单位无关:HOUR 下等同既有 hours_milli(WorkHours.milliHours),其余单位
/// 同一定标规则,保证金额计算只有一条整数路径。
class Quantity {
  /// 定标整数（计量值 × 1000）。
  final int scaled;

  const Quantity(this.scaled);

  /// 仅限录入边界使用:把用户输入的十进制计量值转为定标整数。
  /// 核心计算一律使用 [scaled],不得回到 double。
  factory Quantity.fromValue(double value) {
    return Quantity((value * 1000).round());
  }

  static const int scalePerUnit = 1000;
}
