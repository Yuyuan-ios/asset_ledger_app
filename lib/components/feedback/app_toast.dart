import 'package:flutter/material.dart';

import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/toast_tokens.dart';
import 'app_toast_bubble.dart';

class AppToast {
  static void show(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: DurationTokens.snackBar,
        margin: const EdgeInsets.fromLTRB(
          ToastTokens.snackBarMarginHorizontal,
          0,
          ToastTokens.snackBarMarginHorizontal,
          ToastTokens.snackBarMarginBottom,
        ),
        content: Center(
          child: AppToastBubble(message),
        ),
      ),
    );
  }
}
