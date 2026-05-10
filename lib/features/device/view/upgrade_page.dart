import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/config/subscription_config.dart';
import '../../../data/services/subscription_service.dart';
import '../../../core/foundation/typography.dart';
import '../../../patterns/device/upgrade_benefit_item_pattern.dart';
import '../../../patterns/device/upgrade_footer_links_pattern.dart';
import '../../../patterns/device/upgrade_header_pattern.dart';
import '../../../patterns/device/upgrade_plan_card_pattern.dart';
import '../../../tokens/mapper/core_tokens.dart';
import 'privacy_page.dart';
import 'terms_page.dart';

enum _UpgradePlan { annual, monthly }

extension on _UpgradePlan {
  SubscriptionProductKind get productKind {
    return switch (this) {
      _UpgradePlan.annual => SubscriptionProductKind.yearly,
      _UpgradePlan.monthly => SubscriptionProductKind.monthly,
    };
  }
}

class UpgradePage extends StatefulWidget {
  const UpgradePage({super.key});

  @override
  State<UpgradePage> createState() => _UpgradePageState();
}

class _UpgradePageState extends State<UpgradePage> {
  _UpgradePlan _selectedPlan = _UpgradePlan.annual;

  @override
  void initState() {
    super.initState();
    Future.microtask(SubscriptionService.init);
  }

  Future<void> _submit() async {
    await SubscriptionService.buySelectedProduct(_selectedPlan.productKind);
  }

  Future<void> _restorePurchases() async {
    await SubscriptionService.restorePurchases();
  }

  void _openTermsPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TermsPage()));
  }

  void _openPrivacyPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PrivacyPage()));
  }

  String _planPrice({
    required SubscriptionSnapshot snapshot,
    required SubscriptionProductKind kind,
    required String fallback,
  }) {
    final product = snapshot.productFor(kind);
    if (product == null) return fallback;
    return product.price;
  }

  String _productDescription(ProductDetails? product, String fallback) {
    final description = product?.description.trim();
    if (description == null || description.isEmpty) return fallback;
    return description;
  }

  Widget _buildStatusMessage(
    BuildContext context,
    SubscriptionSnapshot snapshot,
  ) {
    String? message = snapshot.errorMessage;
    if (!SubscriptionConfig.fromEnvironment.isConfigured) {
      message = '当前版本暂未开放订阅购买';
    } else if (snapshot.isLoadingProducts) {
      message = '正在加载 App Store 订阅商品...';
    } else if (!snapshot.hasProducts) {
      message ??= '订阅商品暂不可用，请稍后重试';
    } else if (snapshot.status == SubscriptionStatus.pending) {
      message = '正在等待 App Store 交易结果...';
    } else if (snapshot.allowsProFeatures) {
      message = '订阅已生效，Pro 功能已解锁';
    }

    if (message == null || message.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: DeviceTokens.upgradePlanGap),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTypography.body(
          context,
          fontSize: DeviceTokens.upgradePlanSubtitle2Size,
          color: DeviceTokens.upgradeSubText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SubscriptionSnapshot>(
      valueListenable: SubscriptionService.notifier,
      builder: (context, snapshot, _) {
        final yearly = snapshot.productFor(SubscriptionProductKind.yearly);
        final monthly = snapshot.productFor(SubscriptionProductKind.monthly);
        final selectedProduct = snapshot.productFor(_selectedPlan.productKind);
        final subscriptionVerificationConfigured =
            SubscriptionConfig.fromEnvironment.isConfigured;
        final yearlyPrice = _planPrice(
          snapshot: snapshot,
          kind: SubscriptionProductKind.yearly,
          fallback: '6元/年',
        );
        final monthlyPrice = _planPrice(
          snapshot: snapshot,
          kind: SubscriptionProductKind.monthly,
          fallback: '1元/月',
        );
        final purchasing =
            snapshot.isPurchasing ||
            snapshot.status == SubscriptionStatus.pending;
        final canBuy =
            subscriptionVerificationConfigured &&
            selectedProduct != null &&
            !snapshot.isLoadingProducts &&
            !snapshot.isBusy &&
            !snapshot.allowsProFeatures;
        final buttonText = snapshot.isLoadingProducts
            ? '加载中...'
            : !subscriptionVerificationConfigured
            ? '暂未开放'
            : purchasing
            ? '处理中...'
            : snapshot.allowsProFeatures
            ? '已订阅'
            : selectedProduct == null
            ? '暂不可购买'
            : '继续';

        return Scaffold(
          backgroundColor: DeviceTokens.upgradePageBg,
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                UpgradeHeaderPattern(
                  onBack: () => Navigator.of(context).pop(),
                  backLabel: '设备',
                  title: '立即升级！',
                ),
                Expanded(
                  child: Container(
                    color: DeviceTokens.upgradePageBg,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        DeviceTokens.upgradeListPadH,
                        DeviceTokens.upgradeListPadTop,
                        DeviceTokens.upgradeListPadH,
                        DeviceTokens.upgradeListPadBottom,
                      ),
                      children: [
                        const SizedBox(height: DeviceTokens.upgradeHeroTopGap),
                        SizedBox(
                          height: DeviceTokens.upgradeHeroHeight,
                          child: Image.asset(
                            'assets/images/upgrade_hero_equipment.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(
                          height: DeviceTokens.upgradeHeroToBenefitsGap,
                        ),
                        const UpgradeBenefitItem(text: '云端数据同步/备份'),
                        const UpgradeBenefitItem(text: '解锁应用中的所有功能'),
                        UpgradePlanCard(
                          title: '年套餐',
                          subtitle1: '$yearlyPrice · 年度订阅',
                          subtitle2: _productDescription(yearly, '附带 7天免费试用'),
                          badge: '省50%',
                          emphasized: _selectedPlan == _UpgradePlan.annual,
                          onTap: snapshot.isBusy
                              ? null
                              : () => setState(
                                  () => _selectedPlan = _UpgradePlan.annual,
                                ),
                        ),
                        const SizedBox(height: DeviceTokens.upgradePlanGap),
                        UpgradePlanCard(
                          title: '月套餐',
                          subtitle1: '$monthlyPrice · 按月订阅',
                          subtitle2: _productDescription(monthly, '月度 Pro 订阅'),
                          emphasized: _selectedPlan == _UpgradePlan.monthly,
                          onTap: snapshot.isBusy
                              ? null
                              : () => setState(
                                  () => _selectedPlan = _UpgradePlan.monthly,
                                ),
                        ),
                        _buildStatusMessage(context, snapshot),
                        const SizedBox(
                          height: DeviceTokens.upgradeContinueTopGap,
                        ),
                        SizedBox(
                          height: DeviceTokens.upgradeContinueHeight,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: DeviceTokens.upgradeSurface,
                              foregroundColor: AppColors.brand,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  DeviceTokens.upgradeContinueRadius,
                                ),
                              ),
                            ),
                            onPressed: canBuy ? _submit : null,
                            child: Text(
                              buttonText,
                              style: AppTypography.sectionTitle(
                                context,
                                fontSize: DeviceTokens.upgradeContinueTextSize,
                                fontWeight:
                                    DeviceTokens.upgradeContinueTextWeight,
                                color: AppColors.brand,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: DeviceTokens.upgradeFooterTopGap,
                        ),
                        UpgradeFooterLinksPattern(
                          onTermsTap: _openTermsPage,
                          onPrivacyTap: _openPrivacyPage,
                          onRestoreTap:
                              snapshot.isBusy ||
                                  !subscriptionVerificationConfigured
                              ? null
                              : _restorePurchases,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
