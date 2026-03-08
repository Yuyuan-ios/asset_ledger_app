import 'package:flutter/material.dart';

import '../../../core/utils/store_feedback.dart';
import '../../../data/models/device.dart';
import '../../../data/services/rate_app_service.dart';
import '../../../features/device/state/device_store.dart';
import '../../../components/feedback/app_confirm_dialog.dart';
import 'device_avatar_select_page.dart';
import 'device_editor_dialog.dart';
import 'privacy_page.dart';
import 'terms_page.dart';
import 'upgrade_page.dart';

typedef DevicePageMounted = bool Function();
typedef DevicePageToast = void Function(String message);

class DevicePageActions {
  const DevicePageActions._();

  static Future<void> openDeviceDialog({
    required BuildContext context,
    required DeviceStore store,
    required DevicePageMounted isMounted,
    required DevicePageToast toast,
    Device? device,
    String? initialBrand,
    EquipmentType? initialEquipmentType,
  }) async {
    final edited = await showDialog<Device>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeviceEditorDialog(
        device: device,
        initialBrand: initialBrand,
        initialEquipmentType: initialEquipmentType,
      ),
    );

    if (!isMounted() || edited == null) return;

    Future.microtask(() async {
      if (!isMounted()) return;

      if (device == null) {
        await store.insert(edited);
      } else {
        await store.update(edited);
      }

      final feedback = storeActionFeedback(
        store,
        action: '保存',
        successMessage: device == null ? '已新增设备' : '已更新设备',
      );
      toast(feedback.message);
    });
  }

  static Future<void> openAddDeviceFlow({
    required BuildContext context,
    required DeviceStore store,
    required DevicePageMounted isMounted,
    required DevicePageToast toast,
  }) async {
    final selected = await pushDeviceAvatarSelectPage(context);

    if (!context.mounted || !isMounted() || selected == null) return;
    await openDeviceDialog(
      context: context,
      store: store,
      isMounted: isMounted,
      toast: toast,
      initialBrand: selected.brandValue,
      initialEquipmentType: selected.equipmentType,
    );
  }

  static Future<void> retryLoad(DeviceStore store) async {
    await store.loadAll();
  }

  static Future<void> openRateApp({
    required DevicePageMounted isMounted,
    required DevicePageToast toast,
  }) async {
    final ok = await RateAppService.openSystemRateEntry();
    if (!isMounted()) return;
    toast(ok ? '已打开评分入口' : '评分入口暂不可用');
  }

  static Future<void> openTermsPage(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TermsPage()));
  }

  static Future<void> openPrivacyPage(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PrivacyPage()));
  }

  static Future<bool> openUpgradePage(BuildContext context) async {
    final upgraded = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const UpgradePage()));
    return upgraded == true;
  }

  static Future<void> deactivateDevice({
    required BuildContext context,
    required DeviceStore store,
    required Device device,
    required DevicePageMounted isMounted,
    required DevicePageToast toast,
  }) async {
    if (device.id == null) return;
    final ok = await _confirmDeactivate(context, device);
    if (!ok || !isMounted()) return;

    await store.deactivateById(device.id!);
    final feedback = storeActionFeedback(
      store,
      action: '停用',
      successMessage: '已停用（历史记录不受影响）',
    );
    toast(feedback.message);
  }

  static Future<bool> _confirmDeactivate(BuildContext context, Device d) async {
    return showAppConfirmDialog(
      context: context,
      title: '确认停用设备？',
      content:
          '设备：${d.name}\n\n'
          '✅ 只会停用设备，不会删除任何计时/燃油/收入历史记录。\n'
          '停用后：\n'
          '• 设备页默认不再显示\n'
          '• 计时页下拉框不可再选\n'
          '• 历史记录仍可回显（通过 deviceId 区分新旧设备）',
      confirmText: '停用',
    );
  }
}
