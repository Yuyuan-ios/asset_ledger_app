import 'package:flutter/material.dart';
import '../../core/foundation/typography.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';

class RecordsTitle extends StatelessWidget {
  final int count;
  const RecordsTitle({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTypography.sectionTitle(
      context,
      fontSize: TimingTokens.recordsTitleFontSize,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: TimingTokens.recordsTitleLineHeight,
    );

    return Text('最近记录($count)', style: titleStyle);
  }
}
