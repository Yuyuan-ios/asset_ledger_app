import 'package:flutter/material.dart';

import '../../../tokens/mapper/core_tokens.dart';

PageRoute<T> deviceSubpageRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(
      milliseconds: DeviceTokens.avatarPickerForwardDurationMs,
    ),
    reverseTransitionDuration: const Duration(
      milliseconds: DeviceTokens.avatarPickerReverseDurationMs,
    ),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(offset), child: child);
    },
  );
}
