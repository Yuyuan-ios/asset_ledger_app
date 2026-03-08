// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/store_feedback.dart';
import '../../../data/models/device.dart';
import '../../../features/device/state/device_store.dart';
import '../../../patterns/device/device_page_header_search_pattern.dart';
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

  void _onPlaceholderTap(String label) {
    _toast('$label 功能下步再接入');
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

  Future<void> _openUpgradePage() async {
    final upgraded = await DevicePageActions.openUpgradePage(context);
    if (!mounted) return;
    if (upgraded == true) {
      setState(() {});
      _toast('升级成功，已解锁自定义头像功能');
    }
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
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: DeviceTokens.pageContentWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DeviceTokens.pageHorizontalPadding,
              ),
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
                      onOpenAddDeviceFlow: _openAddDeviceFlow,
                      onOpenRateApp: _openRateApp,
                      onOpenTermsPage: _openTermsPage,
                      onOpenPrivacyPage: _openPrivacyPage,
                      onOpenContact: () => _onPlaceholderTap('联系开发者'),
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
            ),
          ),
        ),
      ),
    );
  }
}
