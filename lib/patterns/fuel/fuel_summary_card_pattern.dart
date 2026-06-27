import 'package:flutter/material.dart';

import '../layout/summary_card_surface.dart';
import '../../tokens/mapper/summary_card_tokens.dart';

class FuelSummaryCard extends StatelessWidget {
  final Widget child;
  final double? height;

  const FuelSummaryCard({super.key, required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    return SummaryCardSurface(
      height: height,
      padding: const EdgeInsets.all(SummaryCardTokens.cardPadding),
      child: child,
    );
  }
}
