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
    ),
  );
  return ok == true;
}

class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    this.content,
    this.contentWidget,
    this.cancelText = '取消',
    this.confirmText = '确定',
  }) : assert(content != null || contentWidget != null);

  final String title;
  final String? content;
  final Widget? contentWidget;
  final String cancelText;
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

    return AlertDialog(
      title: Text(title, style: titleStyle),
      content: DefaultTextStyle.merge(
        style: contentStyle,
        child: contentWidget ?? Text(content ?? ''),
      ),
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
          child: Text(confirmText),
        ),
      ],
    );
  }
}
