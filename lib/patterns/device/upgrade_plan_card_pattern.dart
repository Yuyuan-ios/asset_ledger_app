import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/core_tokens.dart';

class UpgradePlanCard extends StatelessWidget {
  const UpgradePlanCard({
    super.key,
    required this.title,
    required this.subtitle1,
    required this.subtitle2,
    this.badge,
    this.emphasized = false,
    this.onTap,
  });

  final String title;
  final String subtitle1;
  final String subtitle2;
  final String? badge;
  final bool emphasized;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(DeviceTokens.upgradePlanRadius),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: DeviceTokens.upgradeSurface,
            borderRadius: BorderRadius.circular(DeviceTokens.upgradePlanRadius),
            border: Border.all(
              color: emphasized
                  ? DeviceTokens.upgradeBadgeBg
                  : DeviceTokens.upgradeSurface,
              width: emphasized
                  ? DeviceTokens.upgradePlanBorderEmphasized
                  : DeviceTokens.upgradePlanBorderNormal,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            DeviceTokens.upgradePlanPadLeft,
            DeviceTokens.upgradePlanPadTop,
            DeviceTokens.upgradePlanPadRight,
            DeviceTokens.upgradePlanPadBottom,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: AppTypography.sectionTitle(
                            context,
                            fontSize: DeviceTokens.upgradePlanTitleSize,
                            fontWeight: DeviceTokens.upgradePlanTitleWeight,
                            color: DeviceTokens.upgradeAccent,
                          ),
                        ),
                        const SizedBox(
                          width: DeviceTokens.upgradePlanTitleSubtitleGap,
                        ),
                        Text(
                          subtitle1,
                          style: AppTypography.body(
                            context,
                            fontSize: DeviceTokens.upgradePlanSubtitle1Size,
                            color: DeviceTokens.upgradeSubText,
                          ),
                        ),
                      ],
                    ),
                    if (subtitle2.isNotEmpty)
                      const SizedBox(
                        height: DeviceTokens.upgradePlanSubtitle2TopGap,
                      ),
                    Text(
                      subtitle2,
                      style: AppTypography.body(
                        context,
                        fontSize: DeviceTokens.upgradePlanSubtitle2Size,
                        color: DeviceTokens.upgradeSubText,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DeviceTokens.upgradeBadgePadH,
                    vertical: DeviceTokens.upgradeBadgePadV,
                  ),
                  decoration: BoxDecoration(
                    color: DeviceTokens.upgradeBadgeBg,
                    borderRadius: BorderRadius.circular(
                      DeviceTokens.upgradeBadgeRadius,
                    ),
                  ),
                  child: Text(
                    badge!,
                    style: AppTypography.sectionTitle(
                      context,
                      fontSize: DeviceTokens.upgradeBadgeTextSize,
                      fontWeight: DeviceTokens.upgradeBadgeTextWeight,
                      color: DeviceTokens.upgradeBadgeText,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
