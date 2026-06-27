import 'package:flutter/material.dart';

import '../../tokens/mapper/summary_card_tokens.dart';

class SummaryCardSurface extends StatelessWidget {
  const SummaryCardSurface({
    super.key,
    required this.child,
    this.width = double.infinity,
    this.height,
    this.margin,
    this.padding,
    this.constraints,
    this.color = SummaryCardTokens.cardBackground,
    this.onTap,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final paddedChild = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    final content = onTap == null
        ? paddedChild
        : Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: SummaryCardTokens.cardBorderRadius,
              onTap: onTap,
              child: paddedChild,
            ),
          );

    return Container(
      width: width,
      height: height,
      margin: margin,
      constraints: constraints,
      clipBehavior: onTap == null ? Clip.none : Clip.antiAlias,
      decoration: SummaryCardTokens.cardDecoration(color: color),
      child: content,
    );
  }
}
