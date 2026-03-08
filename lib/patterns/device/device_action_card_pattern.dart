import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/device_tokens.dart';

class DeviceActionCard extends StatelessWidget {
  const DeviceActionCard({
    super.key,
    required this.title,
    required this.onTap,
    this.leading,
    this.trailingIcon,
  });

  final String title;
  final VoidCallback onTap;
  final Widget? leading;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DeviceActionCardTokens.radius),
      child: Container(
        height: DeviceActionCardTokens.height,
        decoration: BoxDecoration(
          color: DeviceTokens.actionCardBackgroundColor,
          borderRadius: BorderRadius.circular(DeviceActionCardTokens.radius),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: DeviceActionCardTokens.horizontalPadding,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: DeviceActionCardTokens.leadingGap),
            ],
            Text(
              title,
              style: AppTypography.body(
                context,
                fontSize: DeviceActionCardTokens.titleFontSize,
                fontWeight: DeviceActionCardTokens.titleFontWeight,
                color: DeviceTokens.actionCardTitleColor,
              ),
            ),
            const Spacer(),
            if (trailingIcon != null)
              Icon(
                trailingIcon,
                size: DeviceActionCardTokens.trailingIconSize,
                color: DeviceTokens.actionCardTrailingIconColor,
              ),
          ],
        ),
      ),
    );
  }
}
