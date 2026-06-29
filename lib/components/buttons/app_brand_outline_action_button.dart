import 'package:flutter/material.dart';

import '../../tokens/mapper/core_tokens.dart';

ButtonStyle appBrandOutlineActionButtonStyle({
  EdgeInsetsGeometry? padding,
  Size? minimumSize,
  MaterialTapTargetSize? tapTargetSize,
  TextStyle? textStyle,
  VisualDensity? visualDensity,
  Color borderColor = AppColors.brandOutlineActionBorder,
}) {
  return OutlinedButton.styleFrom(
    foregroundColor: AppColors.brandOutlineAction,
    padding: padding,
    minimumSize: minimumSize,
    tapTargetSize: tapTargetSize,
    textStyle: textStyle,
    visualDensity: visualDensity,
    shape: const StadiumBorder(),
  ).copyWith(
    backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) return null;
      if (states.contains(WidgetState.pressed)) {
        return AppColors.brandOutlineActionPressed;
      }
      return AppColors.brandOutlineActionBackground;
    }),
    side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
      if (states.contains(WidgetState.disabled)) return null;
      return BorderSide(color: borderColor);
    }),
    overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) return null;
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return AppColors.brandOutlineActionPressed.withValues(alpha: 0.55);
      }
      return null;
    }),
  );
}
