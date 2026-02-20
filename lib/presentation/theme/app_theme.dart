import 'package:flutter/material.dart';
import 'app_tokens.dart';

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: AppColors.brand,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.scaffoldBg,
      dividerColor: AppColors.divider,

      // 全局 Card 风格（你说“卡片颜色不动”，以后就只改 Token）
      cardTheme: CardThemeData(
        color: AppColors.cardFill,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
          side: BorderSide(color: AppColors.cardBorder),
        ),
      ),

      // 统一 AppBar 风格（你现在主壳没 AppBar，但页面内可能会用）
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
    );
  }
}
