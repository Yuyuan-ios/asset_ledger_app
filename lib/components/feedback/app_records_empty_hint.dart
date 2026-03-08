import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';

class AppRecordsEmptyHint extends StatelessWidget {
  const AppRecordsEmptyHint({
    super.key,
    required this.height,
    required this.titleStyle,
    required this.subtitleStyle,
    this.title = '暂无记录',
    this.subtitle = '点击右上角 + 新建',
    this.subtitleTopGap = 6,
  });

  final double height;
  final String title;
  final String subtitle;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final double subtitleTopGap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: titleStyle),
            SizedBox(height: subtitleTopGap),
            Text(subtitle, style: subtitleStyle),
          ],
        ),
      ),
    );
  }
}

/// 最近记录空态的统一样式封装（Timing/Fuel/Maintenance 共用）
class AppRecentRecordsEmptyState extends StatelessWidget {
  const AppRecentRecordsEmptyState({
    super.key,
    this.title = '暂无记录',
    this.subtitle = '点击右上角 + 新建',
    this.height = TimingTokens.emptyStateHeight,
    this.subtitleTopGap = TimingTokens.emptyStateSubtitleTopGap,
  });

  final String title;
  final String subtitle;
  final double height;
  final double subtitleTopGap;

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTypography.bodySecondary(
      context,
      fontSize: TimingTokens.emptyStateTitleFontSize,
      color: TimingColors.textSecondary,
    );
    final subtitleStyle = AppTypography.caption(
      context,
      fontSize: TimingTokens.emptyStateSubtitleFontSize,
      color: TimingColors.textTertiary,
    );

    return AppRecordsEmptyHint(
      height: height,
      title: title,
      subtitle: subtitle,
      titleStyle: titleStyle,
      subtitleStyle: subtitleStyle,
      subtitleTopGap: subtitleTopGap,
    );
  }
}
