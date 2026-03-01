import 'package:flutter/material.dart';

import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/fuel_tokens.dart';

class FuelSummaryCard extends StatelessWidget {
  final Widget child;
  final double? height;

  const FuelSummaryCard({super.key, required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(FuelTokens.summaryCardPadding),
      decoration: BoxDecoration(
        color: AppColors.sheetBackground,
        border: Border.all(
          color: AppColors.timingCardBorder,
          width: FuelTokens.summaryCardBorderWidth,
        ),
        borderRadius: BorderRadius.circular(FuelTokens.summaryCardRadius),
      ),
      child: child,
    );
  }
}
