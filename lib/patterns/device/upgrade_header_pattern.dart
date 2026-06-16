import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../tokens/mapper/core_tokens.dart';

class UpgradeHeaderPattern extends StatelessWidget {
  const UpgradeHeaderPattern({
    super.key,
    required this.onBack,
    this.backLabel,
    this.title,
  });

  final VoidCallback onBack;
  final String? backLabel;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resolvedBackLabel = backLabel ?? l10n.devicePageTitle;
    final resolvedTitle = title ?? l10n.deviceUpgradeNowTitle;
    return Column(
      children: [
        Container(
          height: MediaQuery.of(context).padding.top,
          color: DeviceTokens.upgradeHeaderBg,
        ),
        Container(
          color: DeviceTokens.upgradeHeaderBg,
          padding: const EdgeInsets.fromLTRB(
            DeviceTokens.upgradeHeaderPadLeft,
            0,
            DeviceTokens.upgradeHeaderPadRight,
            DeviceTokens.upgradeHeaderPadBottom,
          ),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: onBack,
                style: TextButton.styleFrom(
                  foregroundColor: DeviceTokens.upgradePageBg,
                ),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: DeviceTokens.upgradeBackIconSize,
                ),
                label: Text(
                  resolvedBackLabel,
                  style: AppTypography.body(
                    context,
                    fontSize: DeviceTokens.upgradeBackLabelSize,
                    fontWeight: DeviceTokens.upgradeBackLabelWeight,
                    color: DeviceTokens.upgradePageBg,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  resolvedTitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.pageTitle(
                    context,
                    fontSize: DeviceTokens.upgradeHeaderTitleSize,
                    fontWeight: DeviceTokens.upgradeHeaderTitleWeight,
                    height: DeviceTokens.upgradeHeaderTitleLineHeight,
                    color: DeviceTokens.upgradeHeaderTitleColor,
                  ),
                ),
              ),
              const SizedBox(width: DeviceTokens.upgradeHeaderTrailingSpacer),
            ],
          ),
        ),
        Container(
          height: DeviceTokens.upgradeHeaderDividerHeight,
          color: DeviceTokens.upgradeHeaderTitleColor.withValues(
            alpha: DeviceTokens.upgradeHeaderDividerAlpha,
          ),
        ),
      ],
    );
  }
}
