import 'package:flutter/material.dart';

import '../../../core/config/support_feedback_config.dart';
import '../../../core/foundation/typography.dart';
import '../../../l10n/gen/app_localizations.dart';
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

enum _UpgradePlan { pro, max }

extension on _UpgradePlan {
  SubscriptionProductKind get productKind {
    return switch (this) {
      _UpgradePlan.pro => SubscriptionProductKind.pro,
      _UpgradePlan.max => SubscriptionProductKind.max,
    };
  }

  String fallbackTitle(AppLocalizations l10n) {
    return switch (this) {
      _UpgradePlan.pro => l10n.deviceUpgradeProFallbackTitle,
      _UpgradePlan.max => l10n.deviceUpgradeMaxFallbackTitle,
    };
  }

  String periodLabel(AppLocalizations l10n) {
    return l10n.deviceUpgradePeriodYear;
  }

  String unitLabel(AppLocalizations l10n) {
    return l10n.deviceUpgradeUnitYear;
  }

  String get planCardTitle {
    return switch (this) {
      _UpgradePlan.pro => 'Pro',
      _UpgradePlan.max => 'Max',
    };
  }

  String planCardBody(AppLocalizations l10n) {
    return switch (this) {
      _UpgradePlan.pro => l10n.deviceUpgradeProBody,
      _UpgradePlan.max => l10n.deviceUpgradeMaxBody,
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
    required AppLocalizations l10n,
    required SubscriptionSnapshot snapshot,
    required _UpgradePlan plan,
  }) {
    final title = snapshot.productFor(plan.productKind)?.title.trim();
    if (title == null || title.isEmpty) return plan.fallbackTitle(l10n);
    return title;
  }

  String _priceLabel({
    required AppLocalizations l10n,
    required SubscriptionSnapshot snapshot,
    required _UpgradePlan plan,
  }) {
    final price = snapshot.productFor(plan.productKind)?.price.trim();
    if (price == null || price.isEmpty) {
      return l10n.deviceUpgradeLoadingProduct;
    }
    return price;
  }

  String _unitPriceLabel({
    required AppLocalizations l10n,
    required SubscriptionSnapshot snapshot,
    required _UpgradePlan plan,
  }) {
    final price = snapshot.productFor(plan.productKind)?.price.trim();
    if (price == null || price.isEmpty) {
      return l10n.deviceUpgradeUnitPricePending;
    }
    return '$price / ${plan.unitLabel(l10n)}';
  }

  String _planSubtitle({
    required AppLocalizations l10n,
    required SubscriptionSnapshot snapshot,
    required _UpgradePlan plan,
  }) {
    return '${_priceLabel(l10n: l10n, snapshot: snapshot, plan: plan)} · ${plan.periodLabel(l10n)}';
  }

  Widget _buildStatusMessage(
    BuildContext context,
    SubscriptionSnapshot snapshot,
  ) {
    final l10n = AppLocalizations.of(context);
    final canUsePurchaseFlow = _subscriptionController.canUsePurchaseFlow;
    String? message = snapshot.errorMessage;
    if (!canUsePurchaseFlow) {
      message = l10n.deviceUpgradePurchaseUnavailable;
    } else if (snapshot.isLoadingProducts) {
      message = l10n.deviceUpgradeLoadingProducts;
    } else if (!snapshot.hasProducts) {
      message ??= l10n.deviceUpgradeProductsUnavailable;
    } else if (snapshot.status == SubscriptionStatus.pending) {
      message = l10n.deviceUpgradeTransactionPending;
    } else if (snapshot.allowsProFeatures) {
      message = snapshot.allowsMaxFeatures
          ? l10n.deviceUpgradeMaxUnlocked
          : l10n.deviceUpgradeProUnlocked;
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
        final l10n = AppLocalizations.of(context);
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
            ? l10n.deviceUpgradeButtonLoading
            : !canUsePurchaseFlow
            ? l10n.deviceUpgradeButtonUnavailable
            : purchasing
            ? l10n.deviceUpgradeButtonProcessing
            : entitlementCoversSelectedPlan
            ? l10n.deviceUpgradeButtonSubscribed
            : selectedProduct == null
            ? l10n.deviceUpgradeButtonUnavailable
            : _selectedPlan == _UpgradePlan.max && snapshot.allowsProFeatures
            ? l10n.deviceUpgradeButtonUpgradeMax
            : l10n.deviceUpgradeButtonContinue;

        return Scaffold(
          backgroundColor: DeviceTokens.upgradePageBg,
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                UpgradeHeaderPattern(
                  onBack: () => Navigator.of(context).pop(),
                  backLabel: l10n.devicePageTitle,
                  title: l10n.deviceUpgradeNowTitle,
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
                        UpgradeBenefitItem(
                          text: l10n.deviceUpgradeBenefitClearLedger,
                        ),
                        UpgradeBenefitItem(
                          text: l10n.deviceUpgradeBenefitAutoRenewal,
                        ),
                        UpgradePlanCard(
                          title: _UpgradePlan.pro.planCardTitle,
                          subtitle1: _planSubtitle(
                            l10n: l10n,
                            snapshot: snapshot,
                            plan: _UpgradePlan.pro,
                          ),
                          subtitle2: _UpgradePlan.pro.planCardBody(l10n),
                          emphasized: _selectedPlan == _UpgradePlan.pro,
                          onTap: snapshot.isBusy
                              ? null
                              : () => setState(
                                  () => _selectedPlan = _UpgradePlan.pro,
                                ),
                        ),
                        const SizedBox(height: DeviceTokens.upgradePlanGap),
                        UpgradePlanCard(
                          title: _UpgradePlan.max.planCardTitle,
                          subtitle1: _planSubtitle(
                            l10n: l10n,
                            snapshot: snapshot,
                            plan: _UpgradePlan.max,
                          ),
                          subtitle2: _UpgradePlan.max.planCardBody(l10n),
                          badge: l10n.deviceUpgradeBadgeIncludesPro,
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
                        UpgradeSubscriptionDisclosurePattern(
                          subscriptionTitle: _productTitle(
                            l10n: l10n,
                            snapshot: snapshot,
                            plan: _selectedPlan,
                          ),
                          subscriptionLength: _selectedPlan.periodLabel(l10n),
                          subscriptionPrice: _priceLabel(
                            l10n: l10n,
                            snapshot: snapshot,
                            plan: _selectedPlan,
                          ),
                          unitPrice: _unitPriceLabel(
                            l10n: l10n,
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
