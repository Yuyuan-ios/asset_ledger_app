import 'package:flutter/material.dart';

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension();

  @override
  AppThemeExtension copyWith() => const AppThemeExtension();

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    return const AppThemeExtension();
  }
}
