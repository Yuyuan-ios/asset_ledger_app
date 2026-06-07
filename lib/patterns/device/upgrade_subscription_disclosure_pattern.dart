import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
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
            '订阅信息 / Subscription details',
            style: AppTypography.sectionTitle(
              context,
              fontSize: DeviceTokens.upgradePlanTitleSize,
              fontWeight: DeviceTokens.upgradePlanTitleWeight,
              color: DeviceTokens.upgradeAccent,
            ),
          ),
          const SizedBox(height: DeviceTokens.upgradePlanSubtitle2TopGap),
          _DisclosureRow(label: '订阅名称', value: subscriptionTitle),
          _DisclosureRow(label: '订阅周期', value: subscriptionLength),
          _DisclosureRow(label: '订阅价格', value: subscriptionPrice),
          _DisclosureRow(label: '单位价格', value: unitPrice),
          if (!canPurchaseSelectedProduct) ...[
            const SizedBox(height: DeviceTokens.upgradePlanSubtitle2TopGap),
            Text(
              '商品信息未完整加载前无法购买，请等待 App Store 返回订阅信息。',
              style: AppTypography.body(
                context,
                fontSize: DeviceTokens.upgradePlanSubtitle2Size,
                color: DeviceTokens.upgradeSubText,
              ),
            ),
          ],
          const SizedBox(height: DeviceTokens.upgradePlanGap),
          Text(
            '订阅后可解锁 Pro 功能，并在订阅有效期内持续使用已开放的高级功能。\n'
            'Subscription unlocks premium features while your subscription is active.',
            style: AppTypography.body(
              context,
              fontSize: DeviceTokens.upgradePlanSubtitle2Size,
              color: DeviceTokens.upgradeSubText,
            ),
          ),
          const SizedBox(height: DeviceTokens.upgradePlanSubtitle2TopGap),
          Text(
            '订阅会自动续期，除非你在当前周期结束前至少 24 小时关闭自动续期。你可以在 Apple ID 的订阅设置中管理或取消订阅。\n'
            'Subscriptions renew automatically unless auto-renewal is turned off at least 24 hours before the end of the current period. You can manage or cancel your subscription in your Apple ID subscription settings.',
            style: AppTypography.body(
              context,
              fontSize: DeviceTokens.upgradePlanSubtitle2Size,
              color: DeviceTokens.upgradeSubText,
            ),
          ),
          const SizedBox(height: DeviceTokens.upgradePlanSubtitle2TopGap),
          Text(
            '购买前请阅读《隐私政策》和《使用条款》。\n'
            'Please review the Privacy Policy and Terms of Use before purchasing.',
            style: AppTypography.body(
              context,
              fontSize: DeviceTokens.upgradePlanSubtitle2Size,
              color: DeviceTokens.upgradeSubText,
            ),
          ),
          const SizedBox(height: DeviceTokens.upgradePlanSubtitle2TopGap),
          _LegalLink(
            label: '隐私政策 Privacy Policy',
            url: privacyPolicyUrl,
            onTap: onPrivacyTap,
          ),
          const SizedBox(height: DeviceTokens.upgradePlanSubtitle2TopGap),
          _LegalLink(
            label: '使用条款 Terms of Use',
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
