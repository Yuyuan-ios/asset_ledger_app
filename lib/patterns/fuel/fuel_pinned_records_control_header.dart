import 'package:flutter/material.dart';

import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/fuel_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';

class FuelPinnedRecordsControlHeader extends StatelessWidget {
  const FuelPinnedRecordsControlHeader({
    super.key,
    required this.filter,
    required this.recordsTitle,
  });

  final Widget filter;
  final Widget recordsTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: FuelTokens.pinnedRecordsHeaderHeight,
      decoration: const BoxDecoration(
        color: AppColors.scaffoldBg,
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: FuelTokens.pinnedFilterHeight, child: filter),
          const SizedBox(height: FuelTokens.homeSectionGap),
          SizedBox(
            height:
                TimingTokens.recordsTitleFontSize *
                TimingTokens.recordsTitleLineHeight,
            child: Align(alignment: Alignment.centerLeft, child: recordsTitle),
          ),
          const SizedBox(height: FuelTokens.recordsTitleTopGap),
        ],
      ),
    );
  }
}
