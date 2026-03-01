import 'package:flutter/material.dart';

Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  String cancelText = '取消',
  String confirmText = '确定',
  bool barrierDismissible = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AppConfirmDialog(
      title: title,
      content: content,
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
    required this.content,
    this.cancelText = '取消',
    this.confirmText = '确定',
  });

  final String title;
  final String content;
  final String cancelText;
  final String confirmText;

  @override
  Widget build(BuildContext context) {
    const contentStyle = TextStyle(
      fontFamilyFallback: ['Apple Color Emoji', 'Noto Color Emoji'],
    );

    return AlertDialog(
      title: Text(title),
      content: Text(content, style: contentStyle),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
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
