import 'package:flutter/material.dart';

import '../../core/foundation/spacing.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/sheet_tokens.dart';

/// 纯展示主按钮：不感知 store，仅通过参数驱动。
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = SheetTokens.actionButtonHeight,
    this.horizontalPadding = AppSpace.xxl,
    this.backgroundColor = AppColors.sheetAction,
    this.foregroundColor = AppColors.sheetActionOn,
    this.borderRadius = SheetTokens.actionButtonRadius,
    this.textStyle,
  });

  final String label;
  final VoidCallback? onPressed;

  final double height;
  final double horizontalPadding;
  final Color backgroundColor;
  final Color foregroundColor;
  final double borderRadius;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.45),
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.8),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: Text(
          label,
          style:
              textStyle ??
              const TextStyle(
                fontSize: SheetTokens.actionTextSize,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
