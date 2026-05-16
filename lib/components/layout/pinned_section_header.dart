import 'package:flutter/material.dart';

import '../../core/foundation/spacing.dart';
import '../../core/foundation/typography.dart';
import '../../tokens/mapper/core_tokens.dart';

class PinnedSectionHeader extends StatelessWidget {
  const PinnedSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding,
    this.backgroundColor,
    this.height = 48,
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTypography.sectionTitle(
      context,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1,
    );

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.scaffoldBg,
          border: const Border(
            bottom: BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
        child: Padding(
          padding:
              padding ?? const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpace.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
