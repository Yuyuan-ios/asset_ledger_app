import 'package:flutter/material.dart';

import '../../tokens/mapper/core_tokens.dart';

ColorScheme buildAppColorScheme(ColorScheme base) {
  return base.copyWith(
    primary: SheetColors.action,
    onPrimary: SheetColors.actionOn,
    secondary: SheetColors.action,
    surface: SheetColors.background,
  );
}
