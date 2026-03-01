import 'package:flutter/material.dart';

import '../../tokens/mapper/core_tokens.dart';

ColorScheme buildAppColorScheme(ColorScheme base) {
  return base.copyWith(
    primary: AppColors.sheetAction,
    onPrimary: AppColors.sheetActionOn,
    secondary: AppColors.sheetAction,
    surface: AppColors.sheetBackground,
  );
}
