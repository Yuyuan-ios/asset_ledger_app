import 'package:flutter/material.dart';

import '../../../core/foundation/typography.dart';
import '../domain/services/lifecycle_payback_calculator.dart';

const Color _iosGreen = Color(0xFF34C759);
const Color _iosTeal = Color(0xFF30B0C7);
const Color _iosOrange = Color(0xFFFF9500);
const Color _iosText = Color(0xFF1C1C1E);
const Color _iosSecondaryText = Color(0xFF8E8E93);
const Color _iosTertiaryText = Color(0xFFAEAEB2);
const Color _iosBodyText = Color(0xFF3A3A3C);
const Color _iosFill = Color(0xFFF2F2F7);
const Color _iosGap = Color(0xFFE5E5EA);
const Color _iosGapDark = Color(0xFFD1D1D6);
const Color _iosProfitTail = Color(0xFF1C6B30);
const double _paybackBarHeight = 36;
const double _paybackBarRadius = 10;
const double _paybackBarDividerWidth = 2;
const double _minVisibleSegmentWidth = 0.5;

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
    final result = calculateLifecyclePayback(
      LifecyclePaybackInput(
        initialCostFen: initialCostFen,
        netReceivedFen: netReceivedFen,
        estimatedResidualFen: estimatedResidualFen,
      ),
    );

    return Semantics(
      button: true,
      label: _semanticsLabel(result),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _iosGap, width: 0.5),
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
                    '点击设置成本与残值',
                    style: AppTypography.caption(
                      context,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: _iosSecondaryText,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(height: 1, thickness: 0.5, color: _iosGap),
                const SizedBox(height: 12),
                _Footer(
                  result: result,
                  pendingReceivableFen: pendingReceivableFen,
                ),
                if (!result.isCostUnset) ...[
                  const SizedBox(height: 8),
                  Text(
                    '生命周期净收益 = 已实收 + 预计残值 - 初始成本',
                    style: AppTypography.caption(
                      context,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: _iosTertiaryText,
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

  String _semanticsLabel(LifecyclePaybackResult result) {
    final parts = <String>[
      deviceName,
      '初始投入${initialCostFen == null || initialCostFen! <= 0 ? '未设置' : formatLifecycleMoneyFen(initialCostFen!)}',
      '已实收净额${formatLifecycleMoneyFen(netReceivedFen)}',
      '预计售出残值${formatLifecycleMoneyFen(estimatedResidualFen ?? 0)}',
      result.statusText,
      result.resultText,
    ];
    if (pendingReceivableFen > 0) {
      parts.add('待收${formatLifecycleMoneyFen(pendingReceivableFen)}');
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
    this.netSegment,
    this.residualSegment,
    this.tailSegment,
    this.netResidualDivider,
    this.residualGapDivider,
    this.paybackDivider,
  });

  final Rect track;
  final Rect? netSegment;
  final Rect? residualSegment;
  final Rect? tailSegment;
  final Rect? netResidualDivider;
  final Rect? residualGapDivider;
  final Rect? paybackDivider;
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

  final tailRatio = result.tailRatio;
  final hasTail = result.isPaidBack && tailRatio > 0;
  final calculatedCostWidth = hasTail ? width / (1 + tailRatio) : width;
  final calculatedTailWidth = width - calculatedCostWidth;
  final showTail = calculatedTailWidth > _minVisibleSegmentWidth;
  final costWidth = (showTail ? calculatedCostWidth : width)
      .clamp(0.0, width)
      .toDouble();
  final tailWidth = showTail ? width - costWidth : 0.0;

  final netWidth = (costWidth * result.netSegmentRatio)
      .clamp(0.0, costWidth)
      .toDouble();
  final residualLeft = netWidth;
  final residualWidth = (costWidth * result.residualSegmentRatio)
      .clamp(0.0, costWidth - residualLeft)
      .toDouble();
  final gapLeft = netWidth + residualWidth;
  final gapWidth = (costWidth - gapLeft).clamp(0.0, costWidth).toDouble();

  return PaybackBarLayout(
    track: track,
    netSegment: _visibleRect(left: 0, width: netWidth, height: height),
    residualSegment: _visibleRect(
      left: residualLeft,
      width: residualWidth,
      height: height,
    ),
    tailSegment: showTail
        ? _visibleRect(left: costWidth, width: tailWidth, height: height)
        : null,
    netResidualDivider:
        netWidth > _minVisibleSegmentWidth &&
            residualWidth > _minVisibleSegmentWidth
        ? _dividerRect(
            boundary: netWidth,
            width: width,
            height: height,
            dividerWidth: dividerWidth,
          )
        : null,
    residualGapDivider:
        residualWidth > _minVisibleSegmentWidth &&
            gapWidth > _minVisibleSegmentWidth &&
            result.gapSegmentRatio > 0.001
        ? _dividerRect(
            boundary: gapLeft,
            width: width,
            height: height,
            dividerWidth: dividerWidth,
          )
        : null,
    paybackDivider: showTail
        ? _dividerRect(
            boundary: costWidth,
            width: width,
            height: height,
            dividerWidth: dividerWidth,
          )
        : null,
  );
}

Rect? _visibleRect({
  required double left,
  required double width,
  required double height,
}) {
  if (width <= _minVisibleSegmentWidth) return null;
  return Rect.fromLTWH(left, 0, width, height);
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

    final outerRRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_paybackBarRadius),
    );
    final trackPaint = Paint()..color = _iosGap;
    canvas.drawRRect(outerRRect, trackPaint);

    if (result.isCostUnset) return;

    final layout = calculatePaybackBarLayout(result: result, size: size);
    canvas.save();
    canvas.clipRRect(outerRRect);
    _drawRect(canvas, layout.netSegment, _iosGreen);
    _drawRect(canvas, layout.residualSegment, _iosTeal);
    _drawRect(canvas, layout.tailSegment, _iosProfitTail);
    _drawRect(canvas, layout.netResidualDivider, Colors.white);
    _drawRect(canvas, layout.residualGapDivider, Colors.white);
    _drawRect(canvas, layout.paybackDivider, Colors.white);
    canvas.restore();
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              color: _iosText,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '已运营：${operatedHours.toStringAsFixed(1)}小时 / $operationItems项',
          style: AppTypography.caption(
            context,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: _iosSecondaryText,
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
    final costIsUnset = result.isCostUnset;
    final statusColor = costIsUnset
        ? _iosSecondaryText
        : result.isPaidBack
        ? _iosGreen
        : _iosOrange;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            costIsUnset
                ? '未设置初始投入'
                : '初始投入 ${formatLifecycleMoneyFen(initialCostFen!)}',
            style: AppTypography.body(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: costIsUnset ? _iosSecondaryText : _iosBodyText,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          result.statusText,
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
    final tailLabel = result.isPaidBack ? '盈余' : '未回本缺口';
    final tailColor = result.isPaidBack ? _iosProfitTail : _iosGapDark;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        const _LegendItem(color: _iosGreen, label: '已实收净额'),
        const _LegendItem(color: _iosTeal, label: '预计售出残值'),
        _LegendItem(color: tailColor, label: tailLabel),
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
            color: _iosBodyText,
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
    final resultColor = result.isCostUnset
        ? _iosSecondaryText
        : result.lifeCycleProfitFen > 0
        ? _iosGreen
        : result.lifeCycleProfitFen < 0
        ? _iosOrange
        : _iosBodyText;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            result.resultText,
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
              color: _iosFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '待收 ${formatLifecycleMoneyFen(pendingReceivableFen)}',
              style: AppTypography.caption(
                context,
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: _iosSecondaryText,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
