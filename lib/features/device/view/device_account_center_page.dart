import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../app/phone_login_store.dart';
import '../../../patterns/device/device_action_card_pattern.dart';
import '../../../patterns/device/device_section_group_pattern.dart';
import '../../../patterns/layout/phone_page_layout.dart';
import '../../../tokens/mapper/core_tokens.dart';
import '../domain/entities/subscription.dart';
import 'device_account_status.dart';

class AccountCenterPage extends StatefulWidget {
  const AccountCenterPage({
    super.key,
    required this.loginSession,
    required this.subscriptionListenable,
    required this.onOpenPhoneLogin,
    required this.onOpenUpgradePage,
    required this.onRestorePurchases,
    required this.onOpenLocalBackup,
    required this.onOpenLocalRestore,
    required this.onOpenSyncInfo,
    required this.onOpenCloudBackup,
    this.cloudBackupAvailable = true,
    this.cloudBackupUnavailableMessage = '云端备份服务暂未配置',
  });

  final PhoneLoginSession loginSession;
  final ValueListenable<SubscriptionSnapshot> subscriptionListenable;
  final Future<PhoneLoginSession> Function() onOpenPhoneLogin;
  final VoidCallback onOpenUpgradePage;
  final Future<void> Function() onRestorePurchases;
  final VoidCallback onOpenLocalBackup;
  final VoidCallback onOpenLocalRestore;
  final VoidCallback onOpenSyncInfo;
  final VoidCallback onOpenCloudBackup;
  final bool cloudBackupAvailable;
  final String cloudBackupUnavailableMessage;

  @override
  State<AccountCenterPage> createState() => _AccountCenterPageState();
}

class _AccountCenterPageState extends State<AccountCenterPage> {
  late PhoneLoginSession _loginSession;

  @override
  void initState() {
    super.initState();
    _loginSession = widget.loginSession;
  }

  Future<void> _openPhoneLogin() async {
    final session = await widget.onOpenPhoneLogin();
    if (!mounted) return;
    setState(() => _loginSession = session);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          '账户中心',
          style: TextStyle(
            fontSize: DeviceTokens.avatarPickerTitleFontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = PhonePageLayout.resolveHorizontalPadding(
              constraints.maxWidth,
              basePadding: DeviceTokens.pageHorizontalPadding,
            );

            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                DeviceTokens.pageBottomPadding,
              ),
              children: [
                ValueListenableBuilder<SubscriptionSnapshot>(
                  valueListenable: widget.subscriptionListenable,
                  builder: (context, subscription, _) {
                    return _AccountCenterContent(
                      loginSession: _loginSession,
                      subscription: subscription,
                      onOpenPhoneLogin: _openPhoneLogin,
                      onOpenUpgradePage: widget.onOpenUpgradePage,
                      onRestorePurchases: widget.onRestorePurchases,
                      onOpenLocalBackup: widget.onOpenLocalBackup,
                      onOpenLocalRestore: widget.onOpenLocalRestore,
                      onOpenSyncInfo: widget.onOpenSyncInfo,
                      onOpenCloudBackup: widget.onOpenCloudBackup,
                      cloudBackupAvailable: widget.cloudBackupAvailable,
                      cloudBackupUnavailableMessage:
                          widget.cloudBackupUnavailableMessage,
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccountCenterContent extends StatelessWidget {
  const _AccountCenterContent({
    required this.loginSession,
    required this.subscription,
    required this.onOpenPhoneLogin,
    required this.onOpenUpgradePage,
    required this.onRestorePurchases,
    required this.onOpenLocalBackup,
    required this.onOpenLocalRestore,
    required this.onOpenSyncInfo,
    required this.onOpenCloudBackup,
    required this.cloudBackupAvailable,
    required this.cloudBackupUnavailableMessage,
  });

  final PhoneLoginSession loginSession;
  final SubscriptionSnapshot subscription;
  final VoidCallback onOpenPhoneLogin;
  final VoidCallback onOpenUpgradePage;
  final Future<void> Function() onRestorePurchases;
  final VoidCallback onOpenLocalBackup;
  final VoidCallback onOpenLocalRestore;
  final VoidCallback onOpenSyncInfo;
  final VoidCallback onOpenCloudBackup;
  final bool cloudBackupAvailable;
  final String cloudBackupUnavailableMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DeviceSectionGroup(
          title: '账号状态',
          children: [
            DeviceActionCard(
              title: accountCenterAuthTitle(loginSession),
              subtitle: accountCenterAuthSubtitle(
                session: loginSession,
                subscription: subscription,
              ),
              leading: const _AccountCenterIcon(Icons.account_circle_outlined),
              trailingIcon: loginSession.isAuthenticated
                  ? null
                  : Icons.chevron_right,
              onTap: loginSession.isAuthenticated ? () {} : onOpenPhoneLogin,
            ),
            if (!loginSession.isAuthenticated)
              DeviceActionCard(
                title: '手机号登录',
                subtitle: '登录后可使用云端备份与购买权益同步',
                leading: const _AccountCenterIcon(Icons.phone_iphone),
                trailingIcon: Icons.chevron_right,
                onTap: onOpenPhoneLogin,
              ),
          ],
        ),
        const SizedBox(height: 20),
        DeviceSectionGroup(
          title: '购买权益',
          children: [
            DeviceActionCard(
              title: '升级 Pro，支持持续维护',
              subtitle: purchaseEntitlementSubtitle(subscription),
              leading: const _UpgradeLeadingIcon(),
              trailingIcon: Icons.chevron_right,
              onTap: onOpenUpgradePage,
            ),
            DeviceActionCard(
              title: '恢复购买',
              subtitle: '从 App Store 恢复已购买权益',
              leading: const _AccountCenterIcon(Icons.restore_page_outlined),
              onTap: onRestorePurchases,
            ),
          ],
        ),
        const SizedBox(height: 20),
        DeviceSectionGroup(
          title: '数据安全',
          children: [
            DeviceActionCard(
              title: '云端备份',
              subtitle: cloudBackupAvailable
                  ? loginSession.isAuthenticated
                        ? '上传当前数据或从云端恢复'
                        : '登录后可保存与恢复云端备份'
                  : cloudBackupUnavailableMessage,
              leading: const _AccountCenterIcon(Icons.cloud_upload_outlined),
              onTap: onOpenCloudBackup,
            ),
            DeviceActionCard(
              title: '手动本地备份',
              subtitle: '导出当前数据，便于保存与迁移',
              leading: const _AccountCenterIcon(Icons.ios_share),
              onTap: onOpenLocalBackup,
            ),
            DeviceActionCard(
              title: '本地恢复',
              subtitle: '从备份文件恢复本机数据',
              leading: const _AccountCenterIcon(Icons.restore),
              onTap: onOpenLocalRestore,
            ),
            DeviceActionCard(
              title: '多端同步说明',
              subtitle: '当前版本暂不支持自动多端同步',
              leading: const _AccountCenterIcon(Icons.cloud_outlined),
              onTap: onOpenSyncInfo,
            ),
          ],
        ),
      ],
    );
  }
}

class _UpgradeLeadingIcon extends StatelessWidget {
  const _UpgradeLeadingIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: DeviceActionCardTokens.premiumBadgeSize,
      height: DeviceActionCardTokens.premiumBadgeSize,
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(
          DeviceActionCardTokens.premiumBadgeRadius,
        ),
      ),
      child: const Icon(
        Icons.workspace_premium,
        color: Colors.white,
        size: DeviceActionCardTokens.premiumBadgeIconSize,
      ),
    );
  }
}

class _AccountCenterIcon extends StatelessWidget {
  const _AccountCenterIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.brand, size: 22),
    );
  }
}
