import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/toast_tokens.dart';

class AppToastBubble extends StatelessWidget {
  const AppToastBubble(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(ToastTokens.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ToastTokens.horizontalPadding,
          vertical: ToastTokens.verticalPadding,
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.caption(
            context,
            color: Colors.white,
            fontSize: ToastTokens.textSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
