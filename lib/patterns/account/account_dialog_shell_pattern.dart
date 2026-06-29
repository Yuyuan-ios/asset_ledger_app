import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/account_tokens.dart';
import '../../tokens/mapper/core_tokens.dart';

class AccountDialogShell extends StatelessWidget {
  const AccountDialogShell({
    super.key,
    required this.title,
    required this.child,
    required this.cancelText,
    required this.confirmText,
    required this.onCancel,
    required this.onConfirm,
    this.confirmKey,
    this.confirmChild,
    this.scrollable = false,
  });

  static const double maxWidth = 342;
  static const double horizontalInset = 24;
  static const double verticalInset = 24;

  final String title;
  final Widget child;
  final String cancelText;
  final String confirmText;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final Key? confirmKey;
  final Widget? confirmChild;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final width = math.max(
      0.0,
      math.min(maxWidth, size.width - horizontalInset * 2),
    );
    final maxHeight = math.max(
      120.0,
      size.height - verticalInset * 2 - viewInsets.vertical,
    );
    final titleStyle = AppTypography.sectionTitle(
      context,
      fontSize: AccountTokens.projectDetailSectionTitleSize,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: verticalInset,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: titleStyle),
                const SizedBox(height: 24),
                Flexible(
                  fit: FlexFit.loose,
                  child: scrollable
                      ? SingleChildScrollView(child: child)
                      : child,
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brand.withValues(alpha: 0.8),
                        minimumSize: const Size(96, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(cancelText),
                    ),
                    FilledButton(
                      key: confirmKey,
                      onPressed: onConfirm,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(96, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: const StadiumBorder(),
                      ),
                      child: confirmChild ?? Text(confirmText),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
