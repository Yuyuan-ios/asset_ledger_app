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

enum _UpgradePlan { pro, max }

extension on _UpgradePlan {
  SubscriptionProductKind get productKind {
    return switch (this) {
      _UpgradePlan.pro => SubscriptionProductKind.pro,
      _UpgradePlan.max => SubscriptionProductKind.max,
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

  _UpgradePlan _selectedPlan = _UpgradePlan.pro;

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
      message = snapshot.allowsMaxFeatures
          ? '订阅已生效，Max 权益已解锁'
          : '订阅已生效，Pro 权益已解锁';
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
        final proPrice = _planPrice(
          snapshot: snapshot,
          kind: SubscriptionProductKind.pro,
          fallback: '以 App Store 显示为准',
        );
        final maxPrice = _planPrice(
          snapshot: snapshot,
          kind: SubscriptionProductKind.max,
          fallback: '以 App Store 显示为准',
        );
        final purchasing =
            snapshot.isPurchasing ||
            snapshot.status == SubscriptionStatus.pending;
        final entitlementCoversSelectedPlan = _selectedPlan == _UpgradePlan.max
            ? snapshot.allowsMaxFeatures
            : snapshot.allowsProFeatures;
        final canBuy =
            canUsePurchaseFlow &&
            selectedProduct != null &&
            !snapshot.isLoadingProducts &&
            !snapshot.isBusy &&
            !entitlementCoversSelectedPlan;
        final buttonText = snapshot.isLoadingProducts
            ? '加载中...'
            : !canUsePurchaseFlow
            ? '暂未开放'
            : purchasing
            ? '处理中...'
            : entitlementCoversSelectedPlan
            ? '已订阅'
            : selectedProduct == null
            ? '暂不可购买'
            : _selectedPlan == _UpgradePlan.max && snapshot.allowsProFeatures
            ? '升级到 Max'
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
                        const UpgradeBenefitItem(text: 'Pro 与 Max 均为年度自动续期订阅'),
                        UpgradePlanCard(
                          title: 'Pro',
                          subtitle1: '$proPrice · 年度自动续期',
                          subtitle2: '解锁基础 Pro 功能，订阅有效期内可用。',
                          emphasized: _selectedPlan == _UpgradePlan.pro,
                          onTap: snapshot.isBusy
                              ? null
                              : () => setState(
                                  () => _selectedPlan = _UpgradePlan.pro,
                                ),
                        ),
                        const SizedBox(height: DeviceTokens.upgradePlanGap),
                        UpgradePlanCard(
                          title: 'Max',
                          subtitle1: '$maxPrice · 年度自动续期',
                          subtitle2: '更高等级权益，包含 Pro 能力，并为后续高级能力预留。',
                          badge: '包含 Pro',
                          emphasized: _selectedPlan == _UpgradePlan.max,
                          onTap: snapshot.isBusy
                              ? null
                              : () => setState(
                                  () => _selectedPlan = _UpgradePlan.max,
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
