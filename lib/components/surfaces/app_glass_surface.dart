import 'dart:ui';

import 'package:flutter/material.dart';

import '../../tokens/mapper/core_tokens.dart';

class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.border,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassTokens.blur,
          sigmaY: GlassTokens.blur,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                GlassTokens.surfaceTopBackground,
                GlassTokens.surfaceBottomBackground,
              ],
            ),
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}
