import 'package:flutter/material.dart';

import '../../tokens/mapper/sheet_tokens.dart';

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.onCancel,
    required this.onConfirm,
    this.cancelText = '取消',
    this.confirmText = '确定',
    this.enabled = true,
  });

  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final String cancelText;
  final String confirmText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardVisible = media.viewInsets.bottom > 0;
    final safeBottomInset = keyboardVisible ? 0.0 : media.viewPadding.bottom;
    final keyboardGap = keyboardVisible ? SheetTokens.footerKeyboardGap : 0.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        SheetTokens.footerHorizontal,
        0,
        SheetTokens.footerHorizontal,
        SheetTokens.footerBottom + safeBottomInset + keyboardGap,
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: enabled ? onCancel : null,
            style: TextButton.styleFrom(
              textStyle: const TextStyle(fontSize: SheetTokens.actionTextSize),
            ),
            child: Text(cancelText),
          ),
          const Spacer(),
          SizedBox(
            width: SheetTokens.actionButtonWidth,
            height: SheetTokens.actionButtonHeight,
            child: FilledButton(
              onPressed: enabled ? onConfirm : null,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    SheetTokens.actionButtonRadius,
                  ),
                ),
                textStyle: const TextStyle(
                  fontSize: SheetTokens.actionTextSize,
                ),
              ),
              child: Text(confirmText),
            ),
          ),
        ],
      ),
    );
  }
}
