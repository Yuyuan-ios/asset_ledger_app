import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../core/utils/format_utils.dart';
import '../../features/account/state/account_store.dart';
import '../../tokens/mapper/account_tokens.dart';
import '../../tokens/mapper/color_tokens.dart';

const Offset _overviewChartShadowOffset = Offset(3, 4);

class AccountOverviewVm {
  final double totalReceivable;
  final double totalReceived;
  final double totalRemaining;
  final double? totalRatio;
  final List<AccountDeviceReceivable> deviceReceivables;

  const AccountOverviewVm({
    required this.totalReceivable,
    required this.totalReceived,
    required this.totalRemaining,
    required this.totalRatio,
    required this.deviceReceivables,
  });
}

class AccountOverviewCard extends StatelessWidget {
  const AccountOverviewCard({super.key, required this.vm});

  final AccountOverviewVm vm;

  @override
  Widget build(BuildContext context) {
    final items = _buildItems(vm.deviceReceivables);
    final titleStyle = AppTypography.sectionTitle(
      context,
      fontSize: AccountTokens.overviewTitleFontSize,
      fontWeight: AccountTokens.overviewTitleWeight,
      letterSpacing: AccountTokens.overviewTitleLetterSpacing,
      color: Colors.black,
    );
    final bodyStyle = AppTypography.body(
      context,
      fontSize: AccountTokens.overviewLegendValueSize,
      color: Colors.black,
    );
    final emptyStyle = AppTypography.caption(
      context,
      fontSize: 12,
      color: SheetColors.hint,
    );

    return Container(
      width: double.infinity,
      height: AccountTokens.overviewCardHeight,
      padding: const EdgeInsets.fromLTRB(
        AccountTokens.overviewCardPaddingLeft,
        AccountTokens.overviewCardPaddingTop,
        AccountTokens.overviewCardPaddingRight,
        AccountTokens.overviewCardPaddingBottom,
      ),
      decoration: BoxDecoration(
        color: SheetColors.background,
        border: Border.all(
          color: AccountTokens.overviewCardBorderColor,
          width: AccountTokens.overviewCardBorderWidth,
        ),
        borderRadius: BorderRadius.circular(AccountTokens.overviewCardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AccountTokens.overviewCardShadowOpacity,
            ),
            blurRadius: AccountTokens.overviewCardShadowBlur,
            offset: const Offset(
              AccountTokens.overviewCardShadowOffsetX,
              AccountTokens.overviewCardShadowOffsetY,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Text('总    览', style: titleStyle)),
          const Divider(
            height: AccountTokens.overviewDividerThickness,
            thickness: AccountTokens.overviewDividerThickness,
            color: TimingColors.divider,
          ),
          const SizedBox(height: AccountTokens.overviewMiddleTopGap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: AccountTokens.overviewLeftColumnWidth,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AccountTokens.overviewChartColumnPadding,
                      AccountTokens.overviewChartColumnPadding,
                      AccountTokens.overviewChartColumnPadding,
                      0,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: AccountTokens.overviewChartSize,
                        height: AccountTokens.overviewChartSize,
                        child: _OverviewDonut(items: items),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AccountTokens.overviewChartListGap),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AccountTokens.overviewRightPaddingLeft,
                      AccountTokens.overviewRightPaddingTop,
                      AccountTokens.overviewRightPaddingRight,
                      AccountTokens.overviewRightPaddingBottom,
                    ),
                    child: items.isEmpty
                        ? Text('暂无设备数据', style: emptyStyle)
                        : SingleChildScrollView(
                            physics: BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                for (final item in items) ...[
                                  _OverviewLegendRow(item: item),
                                  if (item != items.last)
                                    const SizedBox(
                                      height:
                                          AccountTokens.overviewLegendRowGap,
                                    ),
                                ],
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AccountTokens.overviewPieTopGap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: AccountTokens.overviewLeftColumnWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AccountTokens.overviewChartColumnPadding,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: AccountTokens.overviewPieSize,
                        height: AccountTokens.overviewPieSize,
                        child: _OverviewPie(
                          received: vm.totalReceived,
                          remaining: vm.totalRemaining,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AccountTokens.overviewChartListGap),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AccountTokens.overviewRightPaddingLeft,
                      AccountTokens.overviewRightPaddingTop,
                      AccountTokens.overviewRightPaddingRight,
                      AccountTokens.overviewRightPaddingBottom,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(
                          height: AccountTokens.overviewSummaryTopPadding,
                        ),
                        _kv(
                          context,
                          '总应收',
                          FormatUtils.money(vm.totalReceivable),
                          bodyStyle,
                        ),
                        const SizedBox(height: 6),
                        _kv(
                          context,
                          '已收',
                          FormatUtils.money(vm.totalReceived),
                          bodyStyle,
                        ),
                        const SizedBox(height: 6),
                        _kv(
                          context,
                          '剩余',
                          FormatUtils.money(vm.totalRemaining),
                          bodyStyle,
                        ),
                        const SizedBox(height: 6),
                        _kv(
                          context,
                          '回款',
                          FormatUtils.percent1(vm.totalRatio),
                          bodyStyle,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_DeviceReceivable> _buildItems(
    List<AccountDeviceReceivable> deviceReceivables,
  ) {
    final items = deviceReceivables
        .map(
          (e) => _DeviceReceivable(
            deviceId: e.deviceId,
            name: e.name,
            amount: e.amount,
          ),
        )
        .toList();

    final totalAmount = items.fold<double>(0, (sum, item) => sum + item.amount);

    for (var i = 0; i < items.length; i++) {
      final color = AccountTokens
          .overviewChartPalette[i % AccountTokens.overviewChartPalette.length];
      items[i] = items[i].copyWith(
        ratio: totalAmount <= 0 ? 0 : (items[i].amount / totalAmount),
        color: color,
      );
    }
    return items;
  }

  Widget _kv(BuildContext context, String k, String v, TextStyle? bodyStyle) {
    return Row(
      children: [
        Expanded(child: Text(k, style: bodyStyle)),
        Text(v, style: bodyStyle),
      ],
    );
  }
}

class _DeviceReceivable {
  final int deviceId;
  final String name;
  final double amount;
  final double ratio;
  final Color color;

  const _DeviceReceivable({
    required this.deviceId,
    required this.name,
    required this.amount,
    this.ratio = 0,
    this.color = Colors.grey,
  });

  _DeviceReceivable copyWith({double? ratio, Color? color}) {
    return _DeviceReceivable(
      deviceId: deviceId,
      name: name,
      amount: amount,
      ratio: ratio ?? this.ratio,
      color: color ?? this.color,
    );
  }
}

class _OverviewLegendRow extends StatelessWidget {
  final _DeviceReceivable item;

  const _OverviewLegendRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final nameStyle = AppTypography.body(
      context,
      fontSize: AccountTokens.overviewLegendNameSize,
      color: Colors.black,
    );
    final valueStyle = AppTypography.body(
      context,
      fontSize: AccountTokens.overviewLegendValueSize,
      color: Colors.black,
    );

    return Row(
      children: [
        const SizedBox(width: AccountTokens.overviewLegendLeftInset),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: nameStyle,
          ),
        ),
        Text(FormatUtils.money(item.amount), style: valueStyle),
      ],
    );
  }
}

class _OverviewDonut extends StatelessWidget {
  final List<_DeviceReceivable> items;

  const _OverviewDonut({required this.items});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _OverviewDonutPainter(items: items));
  }
}

class _OverviewDonutPainter extends CustomPainter {
  final List<_DeviceReceivable> items;

  _OverviewDonutPainter({required this.items});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - AccountTokens.overviewChartStroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final shadowRect = rect.shift(_overviewChartShadowOffset);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AccountTokens.overviewChartStroke
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;
    final shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AccountTokens.overviewChartStroke
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    if (items.isEmpty) {
      shadowPaint.color = Colors.black.withValues(alpha: 0.12);
      canvas.drawArc(shadowRect, 0, 2 * 3.1415926, false, shadowPaint);
      paint.shader = null;
      paint.color = SheetColors.fieldBorder;
      canvas.drawArc(rect, 0, 2 * 3.1415926, false, paint);
      return;
    }

    var start = -3.1415926 / 2;
    for (final item in items) {
      final sweep = 2 * 3.1415926 * item.ratio;
      if (sweep <= 0) continue;
      shadowPaint.color = item.color.withValues(alpha: 0.2);
      canvas.drawArc(shadowRect, start, sweep, false, shadowPaint);
      paint.shader = null;
      paint.color = item.color;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _OverviewDonutPainter oldDelegate) {
    return oldDelegate.items != items;
  }
}

class _OverviewPie extends StatelessWidget {
  final double received;
  final double remaining;

  const _OverviewPie({required this.received, required this.remaining});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverviewPiePainter(received: received, remaining: remaining),
    );
  }
}

class _OverviewPiePainter extends CustomPainter {
  final double received;
  final double remaining;

  _OverviewPiePainter({required this.received, required this.remaining});

  @override
  void paint(Canvas canvas, Size size) {
    final total = (received + remaining);
    final receivedRatio = total <= 0 ? 0.0 : (received / total);
    final remainingRatio = total <= 0 ? 0.0 : (remaining / total);

    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final shadowCenter = center + _overviewChartShadowOffset;
    final shadowRect = Rect.fromCircle(center: shadowCenter, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AccountTokens.overviewPieBorderWidth
      ..color = AccountTokens.overviewPieBorderColor
      ..isAntiAlias = true;
    final shadowPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    if (total <= 0) {
      shadowPaint.color = Colors.black.withValues(alpha: 0.1);
      canvas.drawCircle(shadowCenter, radius, shadowPaint);
      paint.shader = null;
      paint.color = SheetColors.fieldBorder;
      canvas.drawCircle(center, radius, paint);
      canvas.drawCircle(center, radius, borderPaint);
      return;
    }

    final hasDivider = receivedRatio > 0 && remainingRatio > 0;
    var start = -3.1415926 / 2;
    final sliceBoundaries = <double>[start];

    void drawSlice({
      required double ratio,
      required Color color,
      required String label,
    }) {
      final sweep = 2 * 3.1415926 * ratio;
      if (sweep <= 0) return;
      shadowPaint.color = color.withValues(alpha: 0.16);
      canvas.drawArc(shadowRect, start, sweep, true, shadowPaint);
      paint.shader = null;
      paint.color = color;
      canvas.drawArc(rect, start, sweep, true, paint);

      if (ratio >= AccountTokens.overviewPieLabelMinRatio) {
        final mid = start + sweep / 2;
        final labelRadius = radius * AccountTokens.overviewPieLabelRadiusRatio;
        final offset = Offset(
          center.dx + labelRadius * math.cos(mid),
          center.dy + labelRadius * math.sin(mid),
        );
        final painter = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: AccountTokens.overviewPieLabelSize,
              fontWeight: AccountTokens.overviewPieLabelWeight,
              color: Colors.white,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();
        final textOffset =
            offset - Offset(painter.width / 2, painter.height / 2);
        painter.paint(canvas, textOffset);
      }

      start += sweep;
      sliceBoundaries.add(start);
    }

    drawSlice(
      ratio: remainingRatio,
      color: AccountTokens.overviewPieRemaining,
      label: '${(remainingRatio * 100).round()}%',
    );

    drawSlice(
      ratio: receivedRatio,
      color: AccountTokens.overviewPieReceived,
      label: '${(receivedRatio * 100).round()}%',
    );

    if (hasDivider) {
      final dividerPaint = Paint()
        ..color = SheetColors.background
        ..style = PaintingStyle.stroke
        ..strokeWidth = AccountTokens.overviewPieDividerWidth
        ..strokeCap = StrokeCap.butt
        ..isAntiAlias = true;

      for (final angle in sliceBoundaries.take(2)) {
        final end = Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        );
        canvas.drawLine(center, end, dividerPaint);
      }
    }

    canvas.drawCircle(
      center,
      radius - (AccountTokens.overviewPieBorderWidth / 2),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _OverviewPiePainter oldDelegate) {
    return oldDelegate.received != received ||
        oldDelegate.remaining != remaining;
  }
}
