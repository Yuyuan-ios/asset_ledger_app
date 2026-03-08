import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/core_tokens.dart';

class UpgradeFooterLinksPattern extends StatelessWidget {
  const UpgradeFooterLinksPattern({
    super.key,
    required this.onTermsTap,
    required this.onPrivacyTap,
    this.onRestoreTap,
  });

  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;
  final VoidCallback? onRestoreTap;

  @override
  Widget build(BuildContext context) {
    final fallback = TextStyle(
      fontSize: DeviceTokens.upgradeFooterTextSize,
      color: DeviceTokens.upgradeFooterTextColor,
    );
    final style =
        AppTypography.body(
          context,
          fontSize: DeviceTokens.upgradeFooterTextSize,
          color: DeviceTokens.upgradeFooterTextColor,
        ) ??
        fallback;

    return DefaultTextStyle(
      style: style,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(onTap: onTermsTap, child: const Text('条款')),
          GestureDetector(onTap: onPrivacyTap, child: const Text('隐私')),
          if (onRestoreTap != null)
            GestureDetector(onTap: onRestoreTap, child: const Text('恢复购买'))
          else
            const Text('恢复购买'),
        ],
      ),
    );
  }
}
