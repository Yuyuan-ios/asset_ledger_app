import 'dart:ui';

import 'package:flutter/material.dart';
import '../../core/foundation/typography.dart';
import '../../tokens/mapper/core_tokens.dart';

Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  String? content,
  Widget? contentWidget,
  String cancelText = '取消',
  String confirmText = '确定',
  bool confirmDestructive = false,
  bool barrierDismissible = false,
}) async {
  assert(content != null || contentWidget != null);

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AppConfirmDialog(
      title: title,
      content: content,
      contentWidget: contentWidget,
      cancelText: cancelText,
      confirmText: confirmText,
      confirmDestructive: confirmDestructive,
    ),
  );
  return ok == true;
}

Future<void> showAppAlertDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = '知道了',
  bool barrierDismissible = false,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => AppAlertDialog(
      title: title,
      message: message,
      confirmText: confirmText,
    ),
  );
}

class AppAlertDialog extends StatelessWidget {
  const AppAlertDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = '知道了',
  });

  final String title;
  final String message;
  final String confirmText;

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTypography.sectionTitle(
      context,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );
    final contentStyle =
        AppTypography.body(context, color: AppColors.textPrimary)?.copyWith(
          fontFamilyFallback: const ['Apple Color Emoji', 'Noto Color Emoji'],
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassTokens.blur,
          sigmaY: GlassTokens.blur,
        ),
        child: AlertDialog(
          backgroundColor: GlassTokens.surfaceBottomBackground,
          surfaceTintColor: Colors.transparent,
          title: Text(title, style: titleStyle),
          content: DefaultTextStyle.merge(
            style: contentStyle,
            child: Text(message),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(confirmText),
            ),
          ],
        ),
      ),
    );
  }
}

class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    this.content,
    this.contentWidget,
    this.cancelText = '取消',
    this.confirmText = '确定',
    this.confirmDestructive = false,
  }) : assert(content != null || contentWidget != null);

  final String title;
  final String? content;
  final Widget? contentWidget;
  final String cancelText;
  final String confirmText;
  final bool confirmDestructive;

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTypography.sectionTitle(
      context,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );
    final contentStyle =
        AppTypography.body(context, color: AppColors.textPrimary)?.copyWith(
          fontFamilyFallback: const ['Apple Color Emoji', 'Noto Color Emoji'],
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassTokens.blur,
          sigmaY: GlassTokens.blur,
        ),
        child: AlertDialog(
          backgroundColor: GlassTokens.surfaceBottomBackground,
          surfaceTintColor: Colors.transparent,
          title: Text(title, style: titleStyle),
          content: DefaultTextStyle.merge(
            style: contentStyle,
            child: contentWidget ?? Text(content ?? ''),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brand.withValues(alpha: 0.8),
              ),
              child: Text(cancelText),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: confirmDestructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    )
                  : null,
              child: Text(confirmText),
            ),
          ],
        ),
      ),
    );
  }
}
