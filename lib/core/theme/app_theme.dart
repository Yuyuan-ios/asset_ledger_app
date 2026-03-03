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
    final textTheme = _withAppTypography(
      base.textTheme.apply(
        bodyColor: tokens.AppColors.textPrimary,
        displayColor: tokens.AppColors.textPrimary,
      ),
    );

    return base.copyWith(
      colorScheme: cs,
      textTheme: textTheme,
      primaryTextTheme: _withAppTypography(
        base.primaryTextTheme.apply(
          bodyColor: tokens.AppColors.textPrimary,
          displayColor: tokens.AppColors.textPrimary,
        ),
      ),
      scaffoldBackgroundColor: tokens.AppColors.scaffoldBg,
      dividerColor: tokens.AppColors.divider,
      dialogTheme: const DialogThemeData(
        backgroundColor: tokens.SheetColors.background,
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
          backgroundColor: tokens.SheetColors.action,
          foregroundColor: tokens.SheetColors.actionOn,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: tokens.SheetColors.action),
      ),
      cardTheme: CardThemeData(
        color: tokens.AppColors.cardFill,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(tokens.RadiusTokens.card),
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

  static TextTheme _withAppTypography(TextTheme theme) {
    TextStyle? mapStyle(TextStyle? style) {
      if (style == null) return null;
      return style.copyWith(
        inherit: true,
        leadingDistribution: TextLeadingDistribution.even,
      );
    }

    return theme.copyWith(
      displayLarge: mapStyle(theme.displayLarge),
      displayMedium: mapStyle(theme.displayMedium),
      displaySmall: mapStyle(theme.displaySmall),
      headlineLarge: mapStyle(theme.headlineLarge),
      headlineMedium: mapStyle(theme.headlineMedium),
      headlineSmall: mapStyle(theme.headlineSmall),
      titleLarge: mapStyle(theme.titleLarge),
      titleMedium: mapStyle(theme.titleMedium),
      titleSmall: mapStyle(theme.titleSmall),
      bodyLarge: mapStyle(theme.bodyLarge),
      bodyMedium: mapStyle(theme.bodyMedium),
      bodySmall: mapStyle(theme.bodySmall),
      labelLarge: mapStyle(theme.labelLarge),
      labelMedium: mapStyle(theme.labelMedium),
      labelSmall: mapStyle(theme.labelSmall),
    );
  }
}
