import 'package:flutter/material.dart';

import '../../tokens/mapper/core_tokens.dart' as tokens;
import 'color_mapper.dart';

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: tokens.AppColors.brand,
    );
    final cs = buildAppColorScheme(base.colorScheme);

    return base.copyWith(
      colorScheme: cs,
      scaffoldBackgroundColor: tokens.AppColors.scaffoldBg,
      dividerColor: tokens.AppColors.divider,
      dialogTheme: const DialogThemeData(
        backgroundColor: tokens.AppColors.sheetBackground,
        surfaceTintColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: tokens.DialogTokens.insetHorizontal,
          vertical: tokens.DialogTokens.insetVertical,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(tokens.DialogTokens.radius),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.AppColors.sheetAction,
          foregroundColor: tokens.AppColors.sheetActionOn,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.AppColors.sheetAction,
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.AppColors.cardFill,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(tokens.AppRadius.card),
          ),
          side: BorderSide(color: tokens.AppColors.cardBorder),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: tokens.AppColors.textPrimary,
      ),
    );
  }
}
