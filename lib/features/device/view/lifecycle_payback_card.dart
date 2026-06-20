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
      height: 36,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          if (result.isCostUnset || availableWidth <= 0) {
            return const _PlaceholderBar();
          }

          final tailRatio = result.tailRatio;
          final costWidth = result.isPaidBack && tailRatio > 0
              ? availableWidth / (1 + tailRatio)
              : availableWidth;
          final tailWidth = (availableWidth - costWidth).clamp(
            0.0,
            availableWidth,
          );

          return Row(
            children: [
              SizedBox(
                width: costWidth,
                child: _CostSegmentContainer(result: result),
              ),
              if (tailWidth > 0.5) ...[
                Container(width: 2, color: Colors.white),
                Expanded(
                  child: Container(
                    height: 36,
                    decoration: const BoxDecoration(
                      color: _iosProfitTail,
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CostSegmentContainer extends StatelessWidget {
  const _CostSegmentContainer({required this.result});

  final LifecyclePaybackResult result;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final netWidth = width * result.netSegmentRatio;
          final residualWidth = width * result.residualSegmentRatio;
          final residualLeft = netWidth;
          final gapLeft = netWidth + residualWidth;
          final hasGap = result.gapSegmentRatio > 0.001;

          return Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: _iosGap)),
              if (netWidth > 0.5)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: netWidth,
                  child: const ColoredBox(color: _iosGreen),
                ),
              if (residualWidth > 0.5)
                Positioned(
                  left: residualLeft,
                  top: 0,
                  bottom: 0,
                  width: residualWidth,
                  child: const ColoredBox(color: _iosTeal),
                ),
              if (netWidth > 0.5 && residualWidth > 0.5)
                _Separator(left: netWidth),
              if (residualWidth > 0.5 && hasGap) _Separator(left: gapLeft),
            ],
          );
        },
      ),
    );
  }
}

class _PlaceholderBar extends StatelessWidget {
  const _PlaceholderBar();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: const ColoredBox(color: _iosGap, child: SizedBox.expand()),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.left});

  final double left;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left - 1,
      top: 0,
      bottom: 0,
      width: 2,
      child: const ColoredBox(color: Colors.white),
    );
  }
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
