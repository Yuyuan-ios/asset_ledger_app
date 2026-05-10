import 'dart:math' as math;

/// 手机端页面布局度量：
/// - 393pt 作为唯一视觉基线
/// - 宽手机把增量优先分配给 gutter 与安全留白
/// - 窄手机只轻微压缩左右边距，不做整页缩放
class PhonePageLayout {
  const PhonePageLayout._();

  static const double designWidth = 393;
  static const double minHorizontalPadding = 6;

  static double resolveHorizontalPadding(
    double viewportWidth, {
    required double basePadding,
    double maxWideGain = 10,
    double wideGrowthFactor = 0.35,
    double narrowCompressionFactor = 0.17,
  }) {
    final extraWidth = math.max(0, viewportWidth - designWidth);
    final deficitWidth = math.max(0, designWidth - viewportWidth);
    final wideGain = math.min(extraWidth * wideGrowthFactor, maxWideGain);
    final narrowLoss = math.min(
      deficitWidth * narrowCompressionFactor,
      math.max(0, basePadding - minHorizontalPadding),
    );

    return (basePadding + wideGain - narrowLoss)
        .clamp(minHorizontalPadding, basePadding + maxWideGain)
        .toDouble();
  }

  static double resolveMaxContentWidth(
    double availableWidth, {
    required double baseWidth,
    double maxWideGain = 16,
    double wideGrowthFactor = 0.4,
  }) {
    if (availableWidth <= baseWidth) {
      return availableWidth;
    }

    final extraWidth = availableWidth - baseWidth;
    final wideGain = math.min(extraWidth * wideGrowthFactor, maxWideGain);
    return math.min(availableWidth, baseWidth + wideGain).toDouble();
  }
}
