import 'package:flutter/material.dart';

import '../../../components/feedback/store_action_feedback_l10n.dart';
import '../../../core/config/support_feedback_config.dart';
import '../../../core/utils/store_feedback.dart';
import '../application/controllers/device_action_controller.dart';
import '../domain/entities/device.dart';
import '../../../features/device/state/device_store.dart';
import '../../../components/feedback/app_confirm_dialog.dart';
import '../../../l10n/gen/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
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
        action: StoreActionKind.save,
        successOverrideText: device == null
            ? l10n.deviceSaveCreated
            : l10n.deviceSaveUpdated,
      );
      toast(localizeStoreActionFeedback(l10n, feedback));
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
    required AppLocalizations l10n,
    required DevicePageMounted isMounted,
    required DevicePageToast toast,
  }) async {
    final opened = await const DeviceActionController().openRateApp();
    if (!isMounted()) return;
    toast(
      opened ? l10n.deviceRateEntryOpened : l10n.deviceRateEntryUnavailable,
    );
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

  static Future<void> openSupportPage({
    required AppLocalizations l10n,
    required DevicePageMounted isMounted,
    required DevicePageToast toast,
  }) async {
    final result = await const DeviceActionController().openSupportEntry();
    if (!isMounted()) return;
    toast(_supportEntryMessage(l10n, result));
  }

  static String _supportEntryMessage(
    AppLocalizations l10n,
    SupportEntryOutcome outcome,
  ) {
    switch (outcome) {
      case SupportEntryOutcome.siteOpened:
        return l10n.deviceSupportSiteOpened;
      case SupportEntryOutcome.emailFallback:
        return l10n.deviceSupportEmailFallback;
      case SupportEntryOutcome.unavailable:
        return l10n.deviceSupportUnavailable(SupportFeedbackConfig.supportEmail);
    }
  }

  static Future<void> openUpgradePage(BuildContext context) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const UpgradePage()));
  }

  static Future<void> deactivateDevice({
    required BuildContext context,
    required DeviceStore store,
    required Device device,
    required DevicePageMounted isMounted,
    required DevicePageToast toast,
  }) async {
    if (device.id == null) return;
    final l10n = AppLocalizations.of(context);
    final ok = await _confirmDeactivate(context, device);
    if (!ok || !isMounted()) return;

    await store.deactivateById(device.id!);
    final feedback = storeActionFeedback(
      store,
      action: StoreActionKind.deactivate,
      successOverrideText: l10n.deviceDeactivateSuccess,
    );
    toast(localizeStoreActionFeedback(l10n, feedback));
  }

  static Future<bool> _confirmDeactivate(BuildContext context, Device d) async {
    final l10n = AppLocalizations.of(context);
    return showAppConfirmDialog(
      context: context,
      title: l10n.deviceDeactivateTitle,
      content: l10n.deviceDeactivateContent(d.name),
      cancelText: l10n.deviceCancelAction,
      confirmText: l10n.deviceDeactivateAction,
    );
  }
}
