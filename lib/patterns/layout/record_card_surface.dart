import 'package:flutter/material.dart';

import '../../tokens/mapper/color_tokens.dart';
import '../../tokens/mapper/radius_tokens.dart';

class RecordCardSurface extends StatelessWidget {
  const RecordCardSurface({
    super.key,
    required this.child,
    this.width = double.infinity,
    this.height,
    this.margin,
    this.padding,
    this.constraints,
    this.color = SheetColors.background,
    this.border,
    this.boxShadow,
    this.clipBehavior,
    this.onTap,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final Color color;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final Clip? clipBehavior;
  final VoidCallback? onTap;

  static BorderRadius get borderRadius =>
      BorderRadius.circular(RadiusTokens.recordCard);

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
              borderRadius: borderRadius,
              onTap: onTap,
              child: paddedChild,
            ),
          );

    return Container(
      width: width,
      height: height,
      margin: margin,
      constraints: constraints,
      clipBehavior:
          clipBehavior ?? (onTap == null ? Clip.none : Clip.antiAlias),
      decoration: BoxDecoration(
        color: color,
        border: border,
        borderRadius: borderRadius,
        boxShadow: boxShadow,
      ),
      child: content,
    );
  }
}
