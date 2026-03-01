import 'package:flutter/material.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';

class RecordsTitle extends StatelessWidget {
  final int count;
  const RecordsTitle({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Text(
      '最近记录($count)',
      style: const TextStyle(
        fontSize: TimingTokens.recordsTitleFontSize,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: TimingTokens.recordsTitleLineHeight,
      ),
    );
  }
}
