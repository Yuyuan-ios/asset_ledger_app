import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/device_tokens.dart';

class DeviceActionCard extends StatelessWidget {
  const DeviceActionCard({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailingIcon,
  });

  final String title;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? leading;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    final content = Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: DeviceActionCardTokens.leadingGap),
        ],
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  context,
                  fontSize: DeviceActionCardTokens.titleFontSize,
                  fontWeight: DeviceActionCardTokens.titleFontWeight,
                  color: DeviceTokens.actionCardTitleColor,
                ),
              ),
              if (hasSubtitle) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: DeviceTokens.actionCardTitleColor.withValues(
                      alpha: 0.56,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(
            trailingIcon,
            size: DeviceActionCardTokens.trailingIconSize,
            color: DeviceTokens.actionCardTrailingIconColor,
          ),
        ],
      ],
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DeviceActionCardTokens.radius),
      child: Container(
        height: hasSubtitle ? null : DeviceActionCardTokens.height,
        constraints: BoxConstraints(
          minHeight: hasSubtitle ? 64 : DeviceActionCardTokens.height,
        ),
        decoration: BoxDecoration(
          color: DeviceTokens.actionCardBackgroundColor,
          borderRadius: BorderRadius.circular(DeviceActionCardTokens.radius),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: DeviceActionCardTokens.horizontalPadding,
          vertical: hasSubtitle ? 10 : 0,
        ),
        child: content,
      ),
    );
  }
}
