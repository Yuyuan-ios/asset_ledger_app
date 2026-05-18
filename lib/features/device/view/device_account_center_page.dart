import 'package:flutter/material.dart';

import '../../../patterns/device/device_action_card_pattern.dart';
import '../../../patterns/device/device_section_group_pattern.dart';
import '../../../patterns/layout/phone_page_layout.dart';
import '../../../tokens/mapper/core_tokens.dart';

class AccountCenterPage extends StatelessWidget {
  const AccountCenterPage({
    super.key,
    required this.onOpenUpgradePage,
    required this.onOpenLocalBackup,
    required this.onOpenLocalRestore,
    required this.onOpenSyncInfo,
    required this.onOpenLoginSyncInfo,
  });

  final VoidCallback onOpenUpgradePage;
  final VoidCallback onOpenLocalBackup;
  final VoidCallback onOpenLocalRestore;
  final VoidCallback onOpenSyncInfo;
  final VoidCallback onOpenLoginSyncInfo;

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
                _AccountCenterContent(
                  onOpenUpgradePage: onOpenUpgradePage,
                  onOpenLocalBackup: onOpenLocalBackup,
                  onOpenLocalRestore: onOpenLocalRestore,
                  onOpenSyncInfo: onOpenSyncInfo,
                  onOpenLoginSyncInfo: onOpenLoginSyncInfo,
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
    required this.onOpenUpgradePage,
    required this.onOpenLocalBackup,
    required this.onOpenLocalRestore,
    required this.onOpenSyncInfo,
    required this.onOpenLoginSyncInfo,
  });

  final VoidCallback onOpenUpgradePage;
  final VoidCallback onOpenLocalBackup;
  final VoidCallback onOpenLocalRestore;
  final VoidCallback onOpenSyncInfo;
  final VoidCallback onOpenLoginSyncInfo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DeviceSectionGroup(
          title: '个人资料',
          children: [
            DeviceActionCard(
              title: '升级 Pro，支持持续维护',
              leading: const _UpgradeLeadingIcon(),
              trailingIcon: Icons.chevron_right,
              onTap: onOpenUpgradePage,
            ),
          ],
        ),
        const SizedBox(height: 20),
        DeviceSectionGroup(
          title: '数据安全',
          children: [
            DeviceActionCard(
              title: '云端备份与协作记录',
              subtitle: 'Pro 功能，即将上线',
              leading: const _AccountCenterIcon(Icons.account_circle_outlined),
              onTap: onOpenLoginSyncInfo,
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
