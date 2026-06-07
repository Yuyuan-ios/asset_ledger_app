import 'package:flutter/material.dart';

import '../../../core/config/support_feedback_config.dart';
import '../../../core/foundation/typography.dart';
import '../../../patterns/device/upgrade_benefit_item_pattern.dart';
import '../../../patterns/device/upgrade_footer_links_pattern.dart';
import '../../../patterns/device/upgrade_header_pattern.dart';
import '../../../patterns/device/upgrade_plan_card_pattern.dart';
import '../../../patterns/device/upgrade_subscription_disclosure_pattern.dart';
import '../../../tokens/mapper/core_tokens.dart';
import '../application/controllers/subscription_controller.dart';
import '../domain/entities/subscription.dart';
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

  String get fallbackTitle {
    return switch (this) {
      _UpgradePlan.annual => '机账通 Pro 年度订阅',
      _UpgradePlan.monthly => '机账通 Pro 月度订阅',
    };
  }

  String get periodLabel {
    return switch (this) {
      _UpgradePlan.annual => '每年 / 1 year',
      _UpgradePlan.monthly => '每月 / 1 month',
    };
  }

  String get unitLabel {
    return switch (this) {
      _UpgradePlan.annual => '年',
      _UpgradePlan.monthly => '月',
    };
  }

  String get planCardTitle {
    return switch (this) {
      _UpgradePlan.annual => '年套餐',
      _UpgradePlan.monthly => '月套餐',
    };
  }
}

class UpgradePage extends StatefulWidget {
  const UpgradePage({super.key});

  @override
  State<UpgradePage> createState() => _UpgradePageState();
}

class _UpgradePageState extends State<UpgradePage> {
  static const _subscriptionController = SubscriptionController();

  _UpgradePlan _selectedPlan = _UpgradePlan.annual;

  @override
  void initState() {
    super.initState();
    Future.microtask(_subscriptionController.init);
  }

  Future<void> _submit() async {
    await _subscriptionController.buySelectedProduct(_selectedPlan.productKind);
  }

  Future<void> _restorePurchases() async {
    await _subscriptionController.restorePurchases();
  }

  Future<void> _openTermsPage() async {
    final opened = await _subscriptionController.openTermsOfService();
    if (opened || !mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TermsPage()));
  }

  Future<void> _openPrivacyPage() async {
    final opened = await _subscriptionController.openPrivacyPolicy();
    if (opened || !mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PrivacyPage()));
  }

  String _productTitle({
    required SubscriptionSnapshot snapshot,
    required _UpgradePlan plan,
  }) {
    final title = snapshot.productFor(plan.productKind)?.title.trim();
    if (title == null || title.isEmpty) return plan.fallbackTitle;
    return title;
  }

  String _priceLabel({
    required SubscriptionSnapshot snapshot,
    required _UpgradePlan plan,
  }) {
    final price = snapshot.productFor(plan.productKind)?.price.trim();
    if (price == null || price.isEmpty) {
      return '等待 App Store 商品信息 / Loading from App Store';
    }
    return price;
  }

  String _unitPriceLabel({
    required SubscriptionSnapshot snapshot,
    required _UpgradePlan plan,
  }) {
    final price = snapshot.productFor(plan.productKind)?.price.trim();
    if (price == null || price.isEmpty) {
      return '商品信息加载后显示 / Available after product details load';
    }
    return '$price / ${plan.unitLabel}';
  }

  String _planSubtitle({
    required SubscriptionSnapshot snapshot,
    required _UpgradePlan plan,
  }) {
    return '${_priceLabel(snapshot: snapshot, plan: plan)} · ${plan.periodLabel}';
  }

  Widget _buildStatusMessage(
    BuildContext context,
    SubscriptionSnapshot snapshot,
  ) {
    final canUsePurchaseFlow = _subscriptionController.canUsePurchaseFlow;
    String? message = snapshot.errorMessage;
    if (!canUsePurchaseFlow) {
      message = '订阅购买服务暂不可用，请稍后重试';
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
      valueListenable: _subscriptionController.notifier,
      builder: (context, snapshot, _) {
        final selectedProduct = snapshot.productFor(_selectedPlan.productKind);
        final subscriptionVerificationConfigured =
            _subscriptionController.canUsePurchaseFlow;
        // In TestFlight / sandbox smoke tests we allow the purchase flow to run
        // with local entitlement verification. Production builds must keep
        // server-side verification enabled.
        final canUsePurchaseFlow = subscriptionVerificationConfigured;
        final purchasing =
            snapshot.isPurchasing ||
            snapshot.status == SubscriptionStatus.pending;
        final canBuy =
            canUsePurchaseFlow &&
            selectedProduct != null &&
            !snapshot.isLoadingProducts &&
            !snapshot.isBusy &&
            !snapshot.allowsProFeatures;
        final buttonText = snapshot.isLoadingProducts
            ? '加载中...'
            : !canUsePurchaseFlow
            ? '暂不可购买'
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
                  title: '立即升级',
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
                        const UpgradeBenefitItem(text: '解锁自定义设备头像等 Pro 功能'),
                        const UpgradeBenefitItem(text: '订阅有效期内持续使用已开放高级功能'),
                        UpgradePlanCard(
                          title: _UpgradePlan.annual.planCardTitle,
                          subtitle1: _planSubtitle(
                            snapshot: snapshot,
                            plan: _UpgradePlan.annual,
                          ),
                          subtitle2: '订阅有效期内持续使用当前 Pro 权益。',
                          badge: '推荐',
                          emphasized: _selectedPlan == _UpgradePlan.annual,
                          onTap: snapshot.isBusy
                              ? null
                              : () => setState(
                                  () => _selectedPlan = _UpgradePlan.annual,
                                ),
                        ),
                        const SizedBox(height: DeviceTokens.upgradePlanGap),
                        UpgradePlanCard(
                          title: _UpgradePlan.monthly.planCardTitle,
                          subtitle1: _planSubtitle(
                            snapshot: snapshot,
                            plan: _UpgradePlan.monthly,
                          ),
                          subtitle2: '按月订阅，订阅有效期内持续使用当前 Pro 权益。',
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
                        UpgradeSubscriptionDisclosurePattern(
                          subscriptionTitle: _productTitle(
                            snapshot: snapshot,
                            plan: _selectedPlan,
                          ),
                          subscriptionLength: _selectedPlan.periodLabel,
                          subscriptionPrice: _priceLabel(
                            snapshot: snapshot,
                            plan: _selectedPlan,
                          ),
                          unitPrice: _unitPriceLabel(
                            snapshot: snapshot,
                            plan: _selectedPlan,
                          ),
                          canPurchaseSelectedProduct: selectedProduct != null,
                          privacyPolicyUrl:
                              SupportFeedbackConfig.privacyPolicyUrl,
                          termsOfServiceUrl:
                              SupportFeedbackConfig.termsOfServiceUrl,
                          onPrivacyTap: _openPrivacyPage,
                          onTermsTap: _openTermsPage,
                        ),
                        const SizedBox(height: DeviceTokens.upgradePlanGap),
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
                          onRestoreTap: snapshot.isBusy || !canUsePurchaseFlow
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
