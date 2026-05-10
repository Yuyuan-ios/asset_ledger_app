// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/store_feedback.dart';
import '../../../data/models/device.dart';
import '../../../data/services/local_backup_export_service.dart';
import '../../../features/device/state/device_store.dart';
import '../../../patterns/device/device_page_header_search_pattern.dart';
import '../../../patterns/layout/phone_page_layout.dart';
import '../../../components/feedback/app_toast.dart';
import '../../../components/feedback/store_error_banner.dart';
import '../../../tokens/mapper/core_tokens.dart';
import 'device_page_actions.dart';
import 'device_page_sections.dart';

// =====================================================================
// ============================== 二、DevicePage：设备页入口 ==============================
// =====================================================================

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

// =====================================================================
// ============================== 三、State：仅做 UI 状态与交互 ==============================
// =====================================================================

class _DevicePageState extends State<DevicePage> {
  // -------------------------------------------------------------------
  // 3.1 通用：提示消息（SnackBar）
  // -------------------------------------------------------------------
  void _toast(String msg) {
    if (!mounted) return;
    AppToast.show(context, msg);
  }

  Future<void> _showAccountSyncPlaceholder({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  // =====================================================================
  // ============================== 四、新增/编辑弹窗（同一套表单复用） ==============================
  // =====================================================================
  Future<void> _openDeviceDialog({
    Device? device,
    String? initialBrand,
    EquipmentType? initialEquipmentType,
  }) async {
    await DevicePageActions.openDeviceDialog(
      context: context,
      store: context.read<DeviceStore>(),
      isMounted: () => mounted,
      toast: _toast,
      device: device,
      initialBrand: initialBrand,
      initialEquipmentType: initialEquipmentType,
    );
  }

  Future<void> _openAddDeviceFlow() async {
    await DevicePageActions.openAddDeviceFlow(
      context: context,
      store: context.read<DeviceStore>(),
      isMounted: () => mounted,
      toast: _toast,
    );
  }

  Future<void> _retryLoad() async {
    await DevicePageActions.retryLoad(context.read<DeviceStore>());
  }

  Future<void> _openRateApp() async {
    await DevicePageActions.openRateApp(
      isMounted: () => mounted,
      toast: _toast,
    );
  }

  Future<void> _openTermsPage() async {
    await DevicePageActions.openTermsPage(context);
  }

  Future<void> _openPrivacyPage() async {
    await DevicePageActions.openPrivacyPage(context);
  }

  Future<void> _openContactSupport() async {
    await DevicePageActions.openSupportPage(
      isMounted: () => mounted,
      toast: _toast,
    );
  }

  Future<void> _openUpgradePage() async {
    await DevicePageActions.openUpgradePage(context);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openAccountCenterPlaceholder() async {
    await _showAccountSyncPlaceholder(
      title: '账号中心',
      message: '当前版本仅提供入口占位。登录与云同步功能将在后续版本上线，现阶段仍以本机数据管理为主。',
    );
  }

  Future<void> _openLocalBackup() async {
    final result = await LocalBackupExportService.exportJsonBackup();
    if (!mounted) return;

    if (result.success) {
      await _showAccountSyncPlaceholder(
        title: '本地备份已导出',
        message:
            '文件名：${result.fileName ?? '未知'}\n\n'
            '保存路径：${result.filePath ?? '未知'}',
      );
      return;
    }

    await _showAccountSyncPlaceholder(
      title: '本地备份失败',
      message: result.errorMessage ?? '导出未完成，请稍后重试。',
    );
  }

  Future<void> _openLocalRestorePlaceholder() async {
    await _showAccountSyncPlaceholder(
      title: '本地恢复',
      message: '当前版本先提供恢复入口占位。后续版本将支持从本地备份文件恢复本机数据，请在完成备份后再进行迁移。',
    );
  }

  Future<void> _openSyncInfoPlaceholder() async {
    await _showAccountSyncPlaceholder(
      title: '云同步说明',
      message: '当前版本暂不支持自动多端同步，也不包含真实账号体系。后续版本会在不影响本地优先体验的前提下逐步接入。',
    );
  }

  // =====================================================================
  // ============================== 五、UI 构建 ==============================
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DeviceStore>();
    final devices = store.activeDevices;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = PhonePageLayout.resolveHorizontalPadding(
              constraints.maxWidth,
              basePadding: DeviceTokens.pageHorizontalPadding,
            );

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: ListView(
                padding: const EdgeInsets.only(
                  top: 0,
                  bottom: DeviceTokens.pageBottomPadding,
                ),
                children: [
                  const DevicePageHeaderSearch(),
                  if (store.failure != null) ...[
                    const SizedBox(height: DeviceTokens.loadErrorTopGap),
                    StoreErrorBanner(
                      message: storeErrorMessage(store, action: '读取')!,
                      onRetry: store.loading ? null : () => _retryLoad(),
                    ),
                  ],
                  ...buildDevicePageSections(
                    devices: devices,
                    handlers: DevicePageSectionHandlers(
                      onOpenUpgradePage: _openUpgradePage,
                      onOpenAccountCenter: _openAccountCenterPlaceholder,
                      onOpenLocalBackup: _openLocalBackup,
                      onOpenLocalRestore: _openLocalRestorePlaceholder,
                      onOpenSyncInfo: _openSyncInfoPlaceholder,
                      onOpenAddDeviceFlow: _openAddDeviceFlow,
                      onOpenRateApp: _openRateApp,
                      onOpenTermsPage: _openTermsPage,
                      onOpenPrivacyPage: _openPrivacyPage,
                      onOpenContact: _openContactSupport,
                      onDeviceTap: (d) => _openDeviceDialog(device: d),
                      onDeviceLongPress: (d) async {
                        await DevicePageActions.deactivateDevice(
                          context: context,
                          store: context.read<DeviceStore>(),
                          device: d,
                          isMounted: () => mounted,
                          toast: _toast,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
