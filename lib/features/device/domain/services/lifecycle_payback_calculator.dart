import 'dart:math' as math;

const double defaultMaxLifecycleTailRatio = 0.25;

class LifecyclePaybackAmounts {
  const LifecyclePaybackAmounts({
    this.initialCostFen,
    this.estimatedResidualFen,
  });

  final int? initialCostFen;
  final int? estimatedResidualFen;
}

class LifecyclePaybackInput {
  const LifecyclePaybackInput({
    required this.initialCostFen,
    required this.netReceivedFen,
    required this.estimatedResidualFen,
    this.maxTailRatio = defaultMaxLifecycleTailRatio,
  });

  final int? initialCostFen;
  final int? netReceivedFen;
  final int? estimatedResidualFen;
  final double maxTailRatio;
}

class LifecyclePaybackResult {
  const LifecyclePaybackResult({
    required this.totalRecoverableFen,
    required this.lifeCycleProfitFen,
    required this.paybackRate,
    required this.isCostUnset,
    required this.isPaidBack,
    required this.netSegmentRatio,
    required this.residualSegmentRatio,
    required this.gapSegmentRatio,
    required this.tailRatio,
    required this.tailIsCapped,
    required this.statusText,
    required this.resultText,
  });

  final int totalRecoverableFen;
  final int lifeCycleProfitFen;
  final double? paybackRate;
  final bool isCostUnset;
  final bool isPaidBack;
  final double netSegmentRatio;
  final double residualSegmentRatio;
  final double gapSegmentRatio;
  final double tailRatio;
  final bool tailIsCapped;
  final String statusText;
  final String resultText;
}

/// 设备生命周期回本计算。
///
/// `pendingReceivable` 只允许作为 UI 辅助标签展示，不参与这里的生命周期净收益：
/// 生命周期净收益 = 已实收净额 + 预计残值 - 初始成本。
LifecyclePaybackResult calculateLifecyclePayback(LifecyclePaybackInput input) {
  final initialCostFen = input.initialCostFen ?? 0;
  final netReceivedFen = input.netReceivedFen ?? 0;
  final estimatedResidualFen = input.estimatedResidualFen ?? 0;
  final totalRecoverableFen = netReceivedFen + estimatedResidualFen;
  final lifeCycleProfitFen = totalRecoverableFen - initialCostFen;

  if (initialCostFen <= 0) {
    return const LifecyclePaybackResult(
      totalRecoverableFen: 0,
      lifeCycleProfitFen: 0,
      paybackRate: null,
      isCostUnset: true,
      isPaidBack: false,
      netSegmentRatio: 0,
      residualSegmentRatio: 0,
      gapSegmentRatio: 1,
      tailRatio: 0,
      tailIsCapped: false,
      statusText: '未设置成本',
      resultText: '设置后可查看回本进度与预计盈余',
    );
  }

  final paybackRate = totalRecoverableFen / initialCostFen;
  final isPaidBack = totalRecoverableFen >= initialCostFen;
  final statusText = _statusText(paybackRate, isPaidBack: isPaidBack);
  final resultText = _resultText(lifeCycleProfitFen);
  final maxTailRatio = math.max(0.0, input.maxTailRatio);

  if (!isPaidBack) {
    final netSegmentRatio = _clampRatio(netReceivedFen / initialCostFen);
    final residualSegmentRatio = _clampDouble(
      estimatedResidualFen / initialCostFen,
      0,
      1 - netSegmentRatio,
    );
    final gapSegmentRatio = _clampRatio(
      1 - netSegmentRatio - residualSegmentRatio,
    );

    return LifecyclePaybackResult(
      totalRecoverableFen: totalRecoverableFen,
      lifeCycleProfitFen: lifeCycleProfitFen,
      paybackRate: paybackRate,
      isCostUnset: false,
      isPaidBack: false,
      netSegmentRatio: netSegmentRatio,
      residualSegmentRatio: residualSegmentRatio,
      gapSegmentRatio: gapSegmentRatio,
      tailRatio: 0,
      tailIsCapped: false,
      statusText: statusText,
      resultText: resultText,
    );
  }

  final netForCostFen = _clampInt(netReceivedFen, 0, initialCostFen);
  final residualForCostFen = initialCostFen - netForCostFen;
  final profitRatio = math.max(0.0, lifeCycleProfitFen / initialCostFen);
  final tailRatio = math.min(profitRatio, maxTailRatio);

  return LifecyclePaybackResult(
    totalRecoverableFen: totalRecoverableFen,
    lifeCycleProfitFen: lifeCycleProfitFen,
    paybackRate: paybackRate,
    isCostUnset: false,
    isPaidBack: true,
    netSegmentRatio: netForCostFen / initialCostFen,
    residualSegmentRatio: residualForCostFen / initialCostFen,
    gapSegmentRatio: 0,
    tailRatio: tailRatio,
    tailIsCapped: profitRatio > maxTailRatio,
    statusText: statusText,
    resultText: resultText,
  );
}

String formatLifecycleMoneyFen(int amountFen, {bool explicitPlus = false}) {
  final sign = amountFen < 0
      ? '-'
      : explicitPlus && amountFen > 0
      ? '+'
      : '';
  final yuan = (amountFen.abs() / 100).round();
  return '$sign¥${_groupThousands(yuan)}';
}

String formatLifecycleMoneyYuan(num amountYuan, {bool explicitPlus = false}) {
  return formatLifecycleMoneyFen(
    (amountYuan * 100).round(),
    explicitPlus: explicitPlus,
  );
}

String _statusText(double paybackRate, {required bool isPaidBack}) {
  if (isPaidBack) {
    if (paybackRate >= 2) return '已回本 ${paybackRate.toStringAsFixed(2)}x';
    if ((paybackRate - 1).abs() < 0.000001) return '已回本 100%';
    return '已回本 ${(paybackRate * 100).toStringAsFixed(1)}%';
  }
  return '回本 ${(paybackRate * 100).toStringAsFixed(1)}%';
}

String _resultText(int lifeCycleProfitFen) {
  if (lifeCycleProfitFen > 0) {
    return '预计盈余 ${formatLifecycleMoneyFen(lifeCycleProfitFen, explicitPlus: true)}';
  }
  if (lifeCycleProfitFen == 0) return '已回本，暂无盈余';
  return '还差 ${formatLifecycleMoneyFen(lifeCycleProfitFen.abs())} 回本';
}

String _groupThousands(int value) {
  final source = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < source.length; i++) {
    if (i > 0 && (source.length - i) % 3 == 0) buffer.write(',');
    buffer.write(source[i]);
  }
  return buffer.toString();
}

int _clampInt(int value, int min, int max) {
  return math.min(math.max(value, min), max);
}

double _clampRatio(double value) => _clampDouble(value, 0, 1);

double _clampDouble(double value, double min, double max) {
  if (value.isNaN || !value.isFinite) return min;
  return math.min(math.max(value, min), max);
}
