import 'dart:math' as math;

const double defaultMaxLifecycleTailRatio = 0.25;

/// Payback status code (no display copy).
///
/// The display variants (multiplier / 100% / percentage / surplus / shortfall)
/// are derived and localized in the view layer from
/// [LifecyclePaybackResult.paybackRate] and
/// [LifecyclePaybackResult.lifeCycleProfitFen]; the calculator emits no copy.
enum PaybackStatus { noCost, payingBack, paidBack }

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

  /// Kept for source compatibility with the old capped-tail visual model.
  /// The lifecycle payback bar no longer caps surplus width.
  final double maxTailRatio;
}

class LifecyclePaybackResult {
  const LifecyclePaybackResult({
    required this.totalRecoverableFen,
    required this.lifeCycleProfitFen,
    required this.paybackRate,
    required this.isCostUnset,
    required this.isPaidBack,
    required this.receivedPrincipalFen,
    required this.estimatedResidualSegmentFen,
    required this.surplusSegmentFen,
    required this.paybackGapFen,
    required this.visualTotalFen,
    required this.receivedPrincipalSegmentRatio,
    required this.estimatedResidualSegmentRatio,
    required this.surplusSegmentRatio,
    required this.paybackGapSegmentRatio,
    required this.netSegmentRatio,
    required this.residualSegmentRatio,
    required this.gapSegmentRatio,
    required this.tailRatio,
    required this.tailIsCapped,
    required this.status,
  });

  final int totalRecoverableFen;
  final int lifeCycleProfitFen;
  final double? paybackRate;
  final bool isCostUnset;
  final bool isPaidBack;
  final int receivedPrincipalFen;
  final int estimatedResidualSegmentFen;
  final int surplusSegmentFen;
  final int paybackGapFen;
  final int visualTotalFen;
  final double receivedPrincipalSegmentRatio;
  final double estimatedResidualSegmentRatio;
  final double surplusSegmentRatio;
  final double paybackGapSegmentRatio;

  /// Compatibility alias for the first visual segment.
  ///
  /// New callers should use [receivedPrincipalSegmentRatio].
  final double netSegmentRatio;

  /// Compatibility alias for [estimatedResidualSegmentRatio].
  final double residualSegmentRatio;

  /// Compatibility alias for [paybackGapSegmentRatio].
  final double gapSegmentRatio;

  /// Compatibility alias for [surplusSegmentRatio].
  final double tailRatio;

  /// The new surplus segment is never visually capped.
  final bool tailIsCapped;
  final PaybackStatus status;
}

/// Device lifecycle payback calculation.
///
/// `pendingReceivable` may only be shown as an auxiliary UI label; it is not
/// part of the lifecycle net profit here:
/// lifecycle net profit = net received + estimated residual - initial cost.
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
      receivedPrincipalFen: 0,
      estimatedResidualSegmentFen: 0,
      surplusSegmentFen: 0,
      paybackGapFen: 0,
      visualTotalFen: 0,
      receivedPrincipalSegmentRatio: 0,
      estimatedResidualSegmentRatio: 0,
      surplusSegmentRatio: 0,
      paybackGapSegmentRatio: 0,
      netSegmentRatio: 0,
      residualSegmentRatio: 0,
      gapSegmentRatio: 1,
      tailRatio: 0,
      tailIsCapped: false,
      status: PaybackStatus.noCost,
    );
  }

  final paybackRate = totalRecoverableFen / initialCostFen;
  final isPaidBack = totalRecoverableFen >= initialCostFen;
  final safeCostFen = math.max(initialCostFen, 0);
  final safeReceivedFen = math.max(netReceivedFen, 0);
  final safeResidualFen = math.max(estimatedResidualFen, 0);
  final receivedPrincipalFen = math.min(
    safeReceivedFen,
    math.max(safeCostFen - safeResidualFen, 0),
  );
  final estimatedResidualSegmentFen = safeResidualFen;
  final surplusSegmentFen = math.max(safeReceivedFen - receivedPrincipalFen, 0);
  final coloredTotalFen =
      receivedPrincipalFen + estimatedResidualSegmentFen + surplusSegmentFen;
  final paybackGapFen = math.max(safeCostFen - coloredTotalFen, 0);
  final visualTotalFen = math.max(safeCostFen, coloredTotalFen);
  final receivedPrincipalSegmentRatio = _segmentRatio(
    receivedPrincipalFen,
    visualTotalFen,
  );
  final estimatedResidualSegmentRatio = _segmentRatio(
    estimatedResidualSegmentFen,
    visualTotalFen,
  );
  final surplusSegmentRatio = _segmentRatio(surplusSegmentFen, visualTotalFen);
  final paybackGapSegmentRatio = _segmentRatio(paybackGapFen, visualTotalFen);

  return LifecyclePaybackResult(
    totalRecoverableFen: totalRecoverableFen,
    lifeCycleProfitFen: lifeCycleProfitFen,
    paybackRate: paybackRate,
    isCostUnset: false,
    isPaidBack: isPaidBack,
    receivedPrincipalFen: receivedPrincipalFen,
    estimatedResidualSegmentFen: estimatedResidualSegmentFen,
    surplusSegmentFen: surplusSegmentFen,
    paybackGapFen: paybackGapFen,
    visualTotalFen: visualTotalFen,
    receivedPrincipalSegmentRatio: receivedPrincipalSegmentRatio,
    estimatedResidualSegmentRatio: estimatedResidualSegmentRatio,
    surplusSegmentRatio: surplusSegmentRatio,
    paybackGapSegmentRatio: paybackGapSegmentRatio,
    netSegmentRatio: receivedPrincipalSegmentRatio,
    residualSegmentRatio: estimatedResidualSegmentRatio,
    gapSegmentRatio: paybackGapSegmentRatio,
    tailRatio: surplusSegmentRatio,
    tailIsCapped: false,
    status: isPaidBack ? PaybackStatus.paidBack : PaybackStatus.payingBack,
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

String _groupThousands(int value) {
  final source = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < source.length; i++) {
    if (i > 0 && (source.length - i) % 3 == 0) buffer.write(',');
    buffer.write(source[i]);
  }
  return buffer.toString();
}

double _segmentRatio(int amountFen, int visualTotalFen) {
  if (visualTotalFen <= 0) return 0;
  final ratio = amountFen / visualTotalFen;
  if (ratio.isNaN || !ratio.isFinite) return 0;
  return ratio.clamp(0.0, 1.0).toDouble();
}
