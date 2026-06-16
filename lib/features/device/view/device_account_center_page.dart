import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../app/phone_login_store.dart';
import '../../../l10n/gen/app_localizations.dart';
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
    this.cloudBackupUnavailableMessage,
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
  final String? cloudBackupUnavailableMessage;

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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          l10n.deviceAccountCenterTitle,
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
                          widget.cloudBackupUnavailableMessage ??
                          l10n.deviceCloudBackupUnavailableTitle,
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DeviceSectionGroup(
          title: l10n.deviceAccountStatusSectionTitle,
          children: [
            DeviceActionCard(
              title: accountCenterAuthTitle(l10n, loginSession),
              subtitle: accountCenterAuthSubtitle(
                l10n: l10n,
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
                title: l10n.devicePhoneLoginAction,
                subtitle: l10n.devicePhoneLoginSubtitle,
                leading: const _AccountCenterIcon(Icons.phone_iphone),
                trailingIcon: Icons.chevron_right,
                onTap: onOpenPhoneLogin,
              ),
          ],
        ),
        const SizedBox(height: 20),
        DeviceSectionGroup(
          title: l10n.devicePurchaseSectionTitle,
          children: [
            DeviceActionCard(
              title: l10n.deviceUpgradeProTitle,
              subtitle: purchaseEntitlementSubtitle(l10n, subscription),
              leading: const _UpgradeLeadingIcon(),
              trailingIcon: Icons.chevron_right,
              onTap: onOpenUpgradePage,
            ),
            DeviceActionCard(
              title: l10n.deviceRestorePurchasesAction,
              subtitle: l10n.deviceRestorePurchasesSubtitle,
              leading: const _AccountCenterIcon(Icons.restore_page_outlined),
              onTap: onRestorePurchases,
            ),
          ],
        ),
        const SizedBox(height: 20),
        DeviceSectionGroup(
          title: l10n.deviceDataSecuritySectionTitle,
          children: [
            DeviceActionCard(
              title: l10n.deviceCloudBackupTitle,
              subtitle: cloudBackupAvailable
                  ? loginSession.isAuthenticated
                        ? l10n.deviceCloudBackupAuthedSubtitle
                        : l10n.deviceCloudBackupLoginSubtitle
                  : cloudBackupUnavailableMessage,
              leading: const _AccountCenterIcon(Icons.cloud_upload_outlined),
              onTap: onOpenCloudBackup,
            ),
            DeviceActionCard(
              title: l10n.deviceManualBackupTitle,
              subtitle: l10n.deviceManualBackupSubtitle,
              leading: const _AccountCenterIcon(Icons.ios_share),
              onTap: onOpenLocalBackup,
            ),
            DeviceActionCard(
              title: l10n.deviceLocalRestoreTitle,
              subtitle: l10n.deviceLocalRestoreSubtitle,
              leading: const _AccountCenterIcon(Icons.restore),
              onTap: onOpenLocalRestore,
            ),
            DeviceActionCard(
              title: l10n.deviceSyncInfoTitle,
              subtitle: l10n.deviceSyncInfoSubtitle,
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
