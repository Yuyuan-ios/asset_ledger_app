import 'package:flutter/material.dart';

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

class UpgradePage extends StatefulWidget {
  const UpgradePage({super.key});

  @override
  State<UpgradePage> createState() => _UpgradePageState();
}

class _UpgradePageState extends State<UpgradePage> {
  _UpgradePlan _selectedPlan = _UpgradePlan.annual;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      SubscriptionService.setPlanForDebug(Plan.pro);
      await SubscriptionService.refresh();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
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

  @override
  Widget build(BuildContext context) {
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
                    const UpgradeBenefitItem(text: '自定义头像'),
                    const UpgradeBenefitItem(text: '解锁应用中的所有功能'),
                    UpgradePlanCard(
                      title: '12元 / 年',
                      subtitle1: '仅需 1元 / 月',
                      subtitle2: '附带 7天免费试用',
                      badge: '省50%',
                      emphasized: _selectedPlan == _UpgradePlan.annual,
                      onTap: () =>
                          setState(() => _selectedPlan = _UpgradePlan.annual),
                    ),
                    const SizedBox(height: DeviceTokens.upgradePlanGap),
                    UpgradePlanCard(
                      title: '2元 / 月',
                      subtitle1: '',
                      subtitle2: '按月订阅',
                      emphasized: _selectedPlan == _UpgradePlan.monthly,
                      onTap: () =>
                          setState(() => _selectedPlan = _UpgradePlan.monthly),
                    ),
                    const SizedBox(height: DeviceTokens.upgradeContinueTopGap),
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
                        onPressed: _submitting ? null : _submit,
                        child: Text(
                          _submitting ? '处理中...' : '继续',
                          style: AppTypography.sectionTitle(
                            context,
                            fontSize: DeviceTokens.upgradeContinueTextSize,
                            fontWeight: DeviceTokens.upgradeContinueTextWeight,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: DeviceTokens.upgradeFooterTopGap),
                    UpgradeFooterLinksPattern(
                      onTermsTap: _openTermsPage,
                      onPrivacyTap: _openPrivacyPage,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
