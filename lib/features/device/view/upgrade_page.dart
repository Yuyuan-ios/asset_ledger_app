import 'package:flutter/material.dart';

import '../../../core/foundation/typography.dart';
import '../../../patterns/device/upgrade_benefit_item_pattern.dart';
import '../../../patterns/device/upgrade_footer_links_pattern.dart';
import '../../../patterns/device/upgrade_header_pattern.dart';
import '../../../patterns/device/upgrade_plan_card_pattern.dart';
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

  Widget _buildStatusMessage(
    BuildContext context,
    SubscriptionSnapshot snapshot,
  ) {
    final canUsePurchaseFlow = _subscriptionController.canUsePurchaseFlow;
    String? message = snapshot.errorMessage;
    if (!canUsePurchaseFlow) {
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
      valueListenable: _subscriptionController.notifier,
      builder: (context, snapshot, _) {
        final selectedProduct = snapshot.productFor(_selectedPlan.productKind);
        final subscriptionVerificationConfigured =
            _subscriptionController.canUsePurchaseFlow;
        // In TestFlight / sandbox smoke tests we allow the purchase flow to run
        // with local entitlement verification. Production builds must keep
        // server-side verification enabled.
        final canUsePurchaseFlow = subscriptionVerificationConfigured;
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
            canUsePurchaseFlow &&
            selectedProduct != null &&
            !snapshot.isLoadingProducts &&
            !snapshot.isBusy &&
            !snapshot.allowsProFeatures;
        final buttonText = snapshot.isLoadingProducts
            ? '加载中...'
            : !canUsePurchaseFlow
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
                        const UpgradeBenefitItem(text: '多留一份清楚的电子账'),
                        const UpgradeBenefitItem(text: '云备份、协作记录、高级统计将优先开放'),
                        UpgradePlanCard(
                          title: '年套餐',
                          subtitle1: '$yearlyPrice · 年度订阅',
                          subtitle2: '如果对您有帮助，请开发者喝瓶红牛持续开发',
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
                          subtitle2: '按月支持维护，体验当前 Pro 权益。',
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
