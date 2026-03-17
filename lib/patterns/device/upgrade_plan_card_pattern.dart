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
    const compactBadgePadH = DeviceTokens.upgradeBadgePadH - 4;
    const compactBadgePadV = DeviceTokens.upgradeBadgePadV - 4;
    const compactBadgeRadius = DeviceTokens.upgradeBadgeRadius - 2;
    const compactBadgeTextSize = DeviceTokens.upgradeBadgeTextSize - 4;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
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
                        if (subtitle1.isNotEmpty) ...[
                          const SizedBox(
                            width: DeviceTokens.upgradePlanTitleSubtitleGap,
                          ),
                          Flexible(
                            child: Text(
                              subtitle1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(
                                context,
                                fontSize: DeviceTokens.upgradePlanSubtitle1Size,
                                color: DeviceTokens.upgradeSubText,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle2.isNotEmpty || badge != null)
                      const SizedBox(
                        height: DeviceTokens.upgradePlanSubtitle2TopGap,
                      ),
                    if (subtitle2.isNotEmpty || badge != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: subtitle2.isNotEmpty
                                ? Text(
                                    subtitle2,
                                    style: AppTypography.body(
                                      context,
                                      fontSize:
                                          DeviceTokens.upgradePlanSubtitle2Size,
                                      color: DeviceTokens.upgradeSubText,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          if (badge != null) ...[
                            const SizedBox(
                              width: DeviceTokens.upgradePlanTitleSubtitleGap,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: compactBadgePadH,
                                vertical: compactBadgePadV,
                              ),
                              decoration: BoxDecoration(
                                color: DeviceTokens.upgradeBadgeBg,
                                borderRadius: BorderRadius.circular(
                                  compactBadgeRadius,
                                ),
                              ),
                              child: Text(
                                badge!,
                                style: AppTypography.sectionTitle(
                                  context,
                                  fontSize: compactBadgeTextSize,
                                  fontWeight:
                                      DeviceTokens.upgradeBadgeTextWeight,
                                  color: DeviceTokens.upgradeBadgeText,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
