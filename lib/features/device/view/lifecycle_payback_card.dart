import 'package:flutter/material.dart';

import '../../../core/foundation/typography.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../tokens/mapper/device_tokens.dart';
import '../domain/services/lifecycle_payback_calculator.dart';
import 'lifecycle_payback_l10n.dart';

const double _paybackBarHeight = LifecyclePaybackTokens.barHeight;
const double _paybackBarDividerWidth = LifecyclePaybackTokens.barDividerWidth;
const double _minVisibleSegmentWidth =
    LifecyclePaybackTokens.minVisibleSegmentWidth;
const double _operationSummaryWidth = 168;

Color _businessLedgerMutedText() {
  return DeviceTokens.actionCardTitleColor.withValues(alpha: 0.56);
}

class LifecyclePaybackCard extends StatelessWidget {
  const LifecyclePaybackCard({
    super.key,
    required this.deviceName,
    required this.operatedHours,
    required this.operationItems,
    required this.initialCostFen,
    required this.netReceivedFen,
    required this.estimatedResidualFen,
    required this.pendingReceivableFen,
    required this.onTap,
  });

  final String deviceName;
  final double operatedHours;
  final int operationItems;
  final int? initialCostFen;
  final int netReceivedFen;
  final int? estimatedResidualFen;
  final int pendingReceivableFen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = calculateLifecyclePayback(
      LifecyclePaybackInput(
        initialCostFen: initialCostFen,
        netReceivedFen: netReceivedFen,
        estimatedResidualFen: estimatedResidualFen,
      ),
    );

    return Semantics(
      button: true,
      label: _semanticsLabel(l10n, result),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DeviceActionCardTokens.radius),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DeviceActionCardTokens.backgroundColor,
              borderRadius: BorderRadius.circular(
                DeviceActionCardTokens.radius,
              ),
              border: Border.all(
                color: LifecyclePaybackTokens.hairline,
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetaRow(
                  deviceName: deviceName,
                  operatedHours: operatedHours,
                  operationItems: operationItems,
                ),
                const SizedBox(height: 8),
                _FinancialRow(result: result, initialCostFen: initialCostFen),
                const SizedBox(height: 14),
                PaybackSegmentBar(result: result),
                if (!result.isCostUnset) ...[
                  const SizedBox(height: 12),
                  _Legend(result: result),
                ] else ...[
                  const SizedBox(height: 10),
                  Text(
                    l10n.deviceLifecycleSetCostAction,
                    style: AppTypography.caption(
                      context,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: LifecyclePaybackTokens.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: LifecyclePaybackTokens.hairline,
                ),
                const SizedBox(height: 12),
                _Footer(
                  result: result,
                  pendingReceivableFen: pendingReceivableFen,
                ),
                if (!result.isCostUnset) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.deviceLifecycleNetProfitFormula,
                    style: AppTypography.caption(
                      context,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: _businessLedgerMutedText(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _semanticsLabel(AppLocalizations l10n, LifecyclePaybackResult result) {
    final parts = <String>[
      deviceName,
      l10n.deviceLifecycleInitialInvestmentSemantics(
        initialCostFen == null || initialCostFen! <= 0
            ? l10n.deviceLifecycleInitialInvestmentUnsetValue
            : formatLifecycleMoneyFen(initialCostFen!),
      ),
      l10n.deviceLifecycleNetReceivedSemantics(
        formatLifecycleMoneyFen(netReceivedFen),
      ),
      l10n.deviceLifecycleEstimatedResidualSemantics(
        formatLifecycleMoneyFen(estimatedResidualFen ?? 0),
      ),
      paybackStatusText(l10n, result),
      paybackResultText(l10n, result),
    ];
    if (pendingReceivableFen > 0) {
      parts.add(
        l10n.deviceLifecyclePendingReceivableSemantics(
          formatLifecycleMoneyFen(pendingReceivableFen),
        ),
      );
    }
    return parts.join('，');
  }
}

class PaybackSegmentBar extends StatelessWidget {
  const PaybackSegmentBar({super.key, required this.result});

  final LifecyclePaybackResult result;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _paybackBarHeight,
      child: CustomPaint(painter: _PaybackSegmentPainter(result)),
    );
  }
}

class PaybackBarLayout {
  const PaybackBarLayout({
    required this.track,
    this.receivedPrincipalSegment,
    this.residualSegment,
    this.surplusSegment,
    this.gapSegment,
    this.segmentDividers = const [],
  });

  final Rect track;
  final Rect? receivedPrincipalSegment;
  final Rect? residualSegment;
  final Rect? surplusSegment;
  final Rect? gapSegment;
  final List<Rect> segmentDividers;

  bool get hasSurplusSegment => surplusSegment != null;
}

PaybackBarLayout calculatePaybackBarLayout({
  required LifecyclePaybackResult result,
  required Size size,
  double dividerWidth = _paybackBarDividerWidth,
}) {
  final width = size.width;
  final height = size.height;
  final track = Rect.fromLTWH(0, 0, width, height);

  if (width <= 0 || height <= 0 || result.isCostUnset) {
    return PaybackBarLayout(track: track);
  }

  final receivedPrincipalWidth = _segmentWidth(
    width,
    result.receivedPrincipalSegmentRatio,
  );
  final residualWidth = _segmentWidth(
    width,
    result.estimatedResidualSegmentRatio,
  );
  final surplusWidth = _segmentWidth(width, result.surplusSegmentRatio);
  final gapWidth = _segmentWidth(width, result.paybackGapSegmentRatio);
  final residualLeft = receivedPrincipalWidth;
  final surplusLeft = residualLeft + residualWidth;
  final gapLeft = surplusLeft + surplusWidth;

  final receivedPrincipalSegment = _visibleRect(
    left: 0,
    width: receivedPrincipalWidth,
    height: height,
  );
  final residualSegment = _visibleRect(
    left: residualLeft,
    width: residualWidth,
    height: height,
  );
  final surplusSegment = _visibleRect(
    left: surplusLeft,
    width: surplusWidth,
    height: height,
  );
  final gapSegment = _visibleRect(
    left: gapLeft,
    width: gapWidth,
    height: height,
  );

  return PaybackBarLayout(
    track: track,
    receivedPrincipalSegment: receivedPrincipalSegment,
    residualSegment: residualSegment,
    surplusSegment: surplusSegment,
    gapSegment: gapSegment,
    segmentDividers: _segmentDividers(
      [receivedPrincipalSegment, residualSegment, surplusSegment, gapSegment],
      width: width,
      height: height,
      dividerWidth: dividerWidth,
    ),
  );
}

double _segmentWidth(double width, double ratio) {
  return (width * ratio).clamp(0.0, width).toDouble();
}

Rect? _visibleRect({
  required double left,
  required double width,
  required double height,
}) {
  if (width <= _minVisibleSegmentWidth) return null;
  return Rect.fromLTWH(left, 0, width, height);
}

List<Rect> _segmentDividers(
  List<Rect?> segments, {
  required double width,
  required double height,
  required double dividerWidth,
}) {
  final dividers = <Rect>[];
  Rect? previous;
  for (final segment in segments) {
    if (segment == null) continue;
    if (previous != null) {
      dividers.add(
        _dividerRect(
          boundary: segment.left,
          width: width,
          height: height,
          dividerWidth: dividerWidth,
        ),
      );
    }
    previous = segment;
  }
  return dividers;
}

Rect _dividerRect({
  required double boundary,
  required double width,
  required double height,
  required double dividerWidth,
}) {
  final effectiveDividerWidth = dividerWidth.clamp(0.0, width).toDouble();
  final left = (boundary - effectiveDividerWidth / 2)
      .clamp(0.0, width - effectiveDividerWidth)
      .toDouble();
  return Rect.fromLTWH(left, 0, effectiveDividerWidth, height);
}

class _PaybackSegmentPainter extends CustomPainter {
  const _PaybackSegmentPainter(this.result);

  final LifecyclePaybackResult result;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = LifecyclePaybackTokens.barTrack,
    );
    if (result.isCostUnset) return;

    const dividerColor = LifecyclePaybackTokens.segmentDivider;
    final layout = calculatePaybackBarLayout(result: result, size: size);
    _drawRect(
      canvas,
      layout.receivedPrincipalSegment,
      LifecyclePaybackTokens.receivedPrincipal,
    );
    _drawRect(
      canvas,
      layout.residualSegment,
      LifecyclePaybackTokens.estimatedResidual,
    );
    _drawRect(canvas, layout.surplusSegment, LifecyclePaybackTokens.surplus);
    _drawRect(canvas, layout.gapSegment, LifecyclePaybackTokens.barTrack);
    for (final divider in layout.segmentDividers) {
      _drawRect(canvas, divider, dividerColor);
    }
  }

  @override
  bool shouldRepaint(_PaybackSegmentPainter oldDelegate) {
    return oldDelegate.result != result;
  }
}

void _drawRect(Canvas canvas, Rect? rect, Color color) {
  if (rect == null) return;
  canvas.drawRect(rect, Paint()..color = color);
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.deviceName,
    required this.operatedHours,
    required this.operationItems,
  });

  final String deviceName;
  final double operatedHours;
  final int operationItems;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            deviceName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
              context,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: LifecyclePaybackTokens.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: _operationSummaryWidth,
          child: Text(
            l10n.deviceLifecycleOperationSummary(
              operatedHours.toStringAsFixed(1),
              operationItems,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            textAlign: TextAlign.right,
            style: AppTypography.caption(
              context,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: _businessLedgerMutedText(),
            ),
          ),
        ),
      ],
    );
  }
}

class _FinancialRow extends StatelessWidget {
  const _FinancialRow({required this.result, required this.initialCostFen});

  final LifecyclePaybackResult result;
  final int? initialCostFen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final costIsUnset = result.isCostUnset;
    final statusColor = costIsUnset
        ? LifecyclePaybackTokens.textSecondary
        : result.isPaidBack
        ? LifecyclePaybackTokens.surplus
        : LifecyclePaybackTokens.textBody;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            costIsUnset
                ? l10n.deviceLifecycleInitialInvestmentUnset
                : l10n.deviceLifecycleInitialInvestmentAmount(
                    formatLifecycleMoneyFen(initialCostFen!),
                  ),
            style: AppTypography.body(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: costIsUnset
                  ? LifecyclePaybackTokens.textSecondary
                  : LifecyclePaybackTokens.textBody,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          paybackStatusText(l10n, result),
          style: AppTypography.body(
            context,
            fontSize: costIsUnset ? 14 : 16,
            fontWeight: costIsUnset ? FontWeight.w400 : FontWeight.w700,
            color: statusColor,
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.result});

  final LifecyclePaybackResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendItem(
          color: LifecyclePaybackTokens.receivedPrincipal,
          label: l10n.deviceLifecycleReceivedPrincipalLabel,
        ),
        _LegendItem(
          color: LifecyclePaybackTokens.estimatedResidual,
          label: l10n.deviceLifecycleEstimatedResidualLabel,
        ),
        if (result.surplusSegmentFen > 0)
          _LegendItem(
            color: LifecyclePaybackTokens.surplus,
            label: l10n.deviceLifecycleSurplusLabel,
          ),
        if (result.paybackGapSegmentRatio > 0)
          _LegendItem(
            color: LifecyclePaybackTokens.gapMuted,
            label: l10n.deviceLifecyclePaybackGapLabel,
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.caption(
            context,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: LifecyclePaybackTokens.textBody,
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.result, required this.pendingReceivableFen});

  final LifecyclePaybackResult result;
  final int pendingReceivableFen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resultColor = result.isCostUnset
        ? LifecyclePaybackTokens.textSecondary
        : result.lifeCycleProfitFen > 0
        ? LifecyclePaybackTokens.surplus
        : LifecyclePaybackTokens.textBody;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            paybackResultText(l10n, result),
            style: AppTypography.body(
              context,
              fontSize: result.isCostUnset ? 13 : 15,
              fontWeight: result.isCostUnset
                  ? FontWeight.w400
                  : FontWeight.w600,
              color: resultColor,
            ),
          ),
        ),
        if (pendingReceivableFen > 0 && !result.isCostUnset) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: LifecyclePaybackTokens.pendingReceivable,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              l10n.deviceLifecyclePendingReceivableLabel(
                formatLifecycleMoneyFen(pendingReceivableFen),
              ),
              style: AppTypography.caption(
                context,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: LifecyclePaybackTokens.pendingReceivableOnFill,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
