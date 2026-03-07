import 'package:flutter/material.dart';

import '../../tokens/mapper/typography_tokens.dart';

class AppTypography {
  static TextStyle? pageTitle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) {
    return Theme.of(context).textTheme.titleLarge?.copyWith(
      fontSize: fontSize ?? TypographyTokens.pageTitleSize,
      fontWeight: fontWeight ?? TypographyTokens.pageTitleWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle? sectionTitle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) {
    return Theme.of(context).textTheme.titleMedium?.copyWith(
      fontSize: fontSize ?? TypographyTokens.sectionTitleSize,
      fontWeight: fontWeight ?? TypographyTokens.sectionTitleWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle? body(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: fontSize ?? TypographyTokens.bodySize,
      fontWeight: fontWeight ?? TypographyTokens.bodyWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle? bodySecondary(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: fontSize ?? TypographyTokens.bodySecondarySize,
      fontWeight: fontWeight ?? TypographyTokens.bodySecondaryWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle? caption(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: fontSize ?? TypographyTokens.captionSize,
      fontWeight: fontWeight ?? TypographyTokens.captionWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle? actionText(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
      fontSize: fontSize ?? TypographyTokens.actionTextSize,
      fontWeight: fontWeight ?? TypographyTokens.actionTextWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }
}
