import 'package:flutter/material.dart';

import '../../../data/services/subscription_service.dart';
import '../../../core/foundation/typography.dart';
import '../../../tokens/mapper/core_tokens.dart';
import '../../../tokens/mapper/timing_tokens.dart';
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

  @override
  Widget build(BuildContext context) {
    const headerBg = Color(0xFFEDEAFF);
    return Scaffold(
      backgroundColor: const Color(0xFFFF7F2A),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              height: MediaQuery.of(context).padding.top,
              color: headerBg,
            ),
            Container(
              color: headerBg,
              padding: const EdgeInsets.fromLTRB(8, 0, 12, 10),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFF7F2A),
                    ),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 22,
                    ),
                    label: Text(
                      '设备',
                      style: AppTypography.body(
                        context,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFFF7F2A),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '立即升级！',
                      textAlign: TextAlign.center,
                      style: AppTypography.pageTitle(
                        context,
                        fontSize: TimingTokens.headerTitleSize,
                        fontWeight: FontWeight.w700,
                        height: TimingTokens.headerTitleLineHeight,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 88),
                ],
              ),
            ),
            Container(height: 1, color: Colors.black.withValues(alpha: 0.08)),
            Expanded(
              child: Container(
                color: const Color(0xFFFF7F2A),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 158,
                      child: Image.asset(
                        'assets/images/upgrade_hero_equipment.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 58),
                    _benefit('自定义头像'),
                    _benefit('解锁应用中的所有功能'),
                    const SizedBox(height: 0),
                    _planCard(
                      context,
                      title: '12元 / 年',
                      subtitle1: '仅需 1元 / 月',
                      subtitle2: '附带 7天免费试用',
                      badge: '省50%',
                      emphasized: _selectedPlan == _UpgradePlan.annual,
                      onTap: () =>
                          setState(() => _selectedPlan = _UpgradePlan.annual),
                    ),
                    const SizedBox(height: 14),
                    _planCard(
                      context,
                      title: '2元 / 月',
                      subtitle1: '',
                      subtitle2: '按月订阅',
                      emphasized: _selectedPlan == _UpgradePlan.monthly,
                      onTap: () =>
                          setState(() => _selectedPlan = _UpgradePlan.monthly),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.brand,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _submitting ? null : _submit,
                        child: Text(
                          _submitting ? '处理中...' : '继续',
                          style: AppTypography.sectionTitle(
                            context,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    DefaultTextStyle(
                      style:
                          AppTypography.body(
                            context,
                            fontSize: 16,
                            color: Colors.white,
                          ) ??
                          const TextStyle(fontSize: 16, color: Colors.white),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const TermsPage(),
                                ),
                              );
                            },
                            child: const Text('条款'),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const PrivacyPage(),
                                ),
                              );
                            },
                            child: const Text('隐私'),
                          ),
                          const Text('恢复购买'),
                        ],
                      ),
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

  Widget _benefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: Icon(Icons.check, color: Color(0xFF5B3FDE)),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard(
    BuildContext context, {
    required String title,
    required String subtitle1,
    required String subtitle2,
    String? badge,
    bool emphasized = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: emphasized ? const Color(0xFFB5E61D) : Colors.white,
              width: emphasized ? 3 : 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: AppTypography.sectionTitle(
                            context,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF5B3FDE),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          subtitle1,
                          style: AppTypography.body(
                            context,
                            fontSize: 14,
                            color: const Color(0xFF5A5A5A),
                          ),
                        ),
                      ],
                    ),

                    if (subtitle2.isNotEmpty) const SizedBox(height: 6),
                    Text(
                      subtitle2,
                      style: AppTypography.body(
                        context,
                        fontSize: 18,
                        color: const Color(0xFF5A5A5A),
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB5E61D),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge,
                    style: AppTypography.sectionTitle(
                      context,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
