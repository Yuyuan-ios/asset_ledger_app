import 'package:flutter/material.dart';

import '../../tokens/mapper/core_tokens.dart';

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
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        content: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xCC4A382C),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
