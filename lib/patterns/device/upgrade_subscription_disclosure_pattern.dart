import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../tokens/mapper/core_tokens.dart';

class UpgradeSubscriptionDisclosurePattern extends StatelessWidget {
  const UpgradeSubscriptionDisclosurePattern({
    super.key,
    required this.subscriptionTitle,
    required this.subscriptionLength,
    required this.subscriptionPrice,
    required this.unitPrice,
    required this.canPurchaseSelectedProduct,
    required this.privacyPolicyUrl,
    required this.termsOfServiceUrl,
    required this.onPrivacyTap,
    required this.onTermsTap,
  });

  final String subscriptionTitle;
  final String subscriptionLength;
  final String subscriptionPrice;
  final String unitPrice;
  final bool canPurchaseSelectedProduct;
  final String privacyPolicyUrl;
  final String termsOfServiceUrl;
  final VoidCallback onPrivacyTap;
  final VoidCallback onTermsTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: DeviceTokens.upgradeSurface,
        borderRadius: BorderRadius.circular(DeviceTokens.upgradePlanRadius),
        border: Border.all(color: DeviceTokens.upgradeBadgeBg, width: 1),
      ),
      padding: const EdgeInsets.all(DeviceTokens.upgradePlanPadLeft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.deviceUpgradeSubscriptionDetailsTitle,
            style: AppTypography.sectionTitle(
              context,
              fontSize: DeviceTokens.upgradePlanTitleSize,
              fontWeight: DeviceTokens.upgradePlanTitleWeight,
              color: DeviceTokens.upgradeAccent,
            ),
          ),
          const SizedBox(height: DeviceTokens.upgradePlanSubtitle2TopGap),
          _DisclosureRow(
            label: l10n.deviceUpgradeSubscriptionNameLabel,
            value: subscriptionTitle,
          ),
          _DisclosureRow(
            label: l10n.deviceUpgradeSubscriptionPeriodLabel,
            value: subscriptionLength,
          ),
          _DisclosureRow(
            label: l10n.deviceUpgradeSubscriptionPriceLabel,
            value: subscriptionPrice,
          ),
          _DisclosureRow(
            label: l10n.deviceUpgradeUnitPriceLabel,
            value: unitPrice,
          ),
          if (!canPurchaseSelectedProduct) ...[
            const SizedBox(height: DeviceTokens.upgradePlanSubtitle2TopGap),
            Text(
              l10n.deviceUpgradeProductNotLoadedMessage,
              style: AppTypography.body(
                context,
                fontSize: DeviceTokens.upgradePlanSubtitle2Size,
                color: DeviceTokens.upgradeSubText,
              ),
            ),
          ],
          const SizedBox(height: DeviceTokens.upgradePlanGap),
          Text(
            l10n.deviceUpgradeUnlocksPremiumMessage,
            style: AppTypography.body(
              context,
              fontSize: DeviceTokens.upgradePlanSubtitle2Size,
              color: DeviceTokens.upgradeSubText,
            ),
          ),
          const SizedBox(height: DeviceTokens.upgradePlanSubtitle2TopGap),
          Text(
            l10n.deviceUpgradeAutoRenewMessage,
            style: AppTypography.body(
              context,
              fontSize: DeviceTokens.upgradePlanSubtitle2Size,
              color: DeviceTokens.upgradeSubText,
            ),
          ),
          const SizedBox(height: DeviceTokens.upgradePlanSubtitle2TopGap),
          Text(
            l10n.deviceUpgradeReviewLegalMessage,
            style: AppTypography.body(
              context,
              fontSize: DeviceTokens.upgradePlanSubtitle2Size,
              color: DeviceTokens.upgradeSubText,
            ),
          ),
          const SizedBox(height: DeviceTokens.upgradePlanSubtitle2TopGap),
          _LegalLink(
            label: l10n.deviceUpgradePrivacyLinkLabel,
            url: privacyPolicyUrl,
            onTap: onPrivacyTap,
          ),
          const SizedBox(height: DeviceTokens.upgradePlanSubtitle2TopGap),
          _LegalLink(
            label: l10n.deviceUpgradeTermsLinkLabel,
            url: termsOfServiceUrl,
            onTap: onTermsTap,
          ),
        ],
      ),
    );
  }
}

class _DisclosureRow extends StatelessWidget {
  const _DisclosureRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: DeviceTokens.upgradePlanSubtitle2TopGap,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: AppTypography.body(
                context,
                fontSize: DeviceTokens.upgradePlanSubtitle2Size,
                color: DeviceTokens.upgradeFooterTextColor,
              ),
            ),
          ),
          const SizedBox(width: DeviceTokens.upgradePlanTitleSubtitleGap),
          Expanded(
            child: Text(
              value,
              style: AppTypography.body(
                context,
                fontSize: DeviceTokens.upgradePlanSubtitle2Size,
                color: DeviceTokens.upgradeSubText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    required this.label,
    required this.url,
    required this.onTap,
  });

  final String label;
  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(DeviceTokens.upgradeBadgeRadius),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: DeviceTokens.upgradeBadgePadV,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.sectionTitle(
                context,
                fontSize: DeviceTokens.upgradePlanSubtitle2Size,
                fontWeight: FontWeight.w600,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              url,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: AppTypography.body(
                context,
                fontSize: DeviceTokens.upgradeFooterTextSize,
                color: DeviceTokens.upgradeSubText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
