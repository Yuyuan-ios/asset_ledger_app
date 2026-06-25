import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../components/feedback/store_action_feedback_l10n.dart';
import '../../../../core/utils/interaction_feedback.dart';
import '../../../../core/utils/store_feedback.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/entities/account_entities.dart';
import '../../model/account_view_model.dart';
import '../../model/project_title_formatter.dart';
import '../../state/project_rate_store.dart';
import '../dialogs/account_rate_dialogs.dart';

/// 账户页单价编辑流程（批量/单台）动作封装。
///
/// 说明：
/// - 仅收口 action orchestration（弹窗 -> 校验 -> store 写入 -> 反馈）；
/// - 不改变原有业务口径与交互时序（含 microtask 写入）。
class AccountRateEditActions {
  AccountRateEditActions({
    required this.context,
    required this.isMounted,
    required this.toast,
  });

  final BuildContext context;
  final bool Function() isMounted;
  final void Function(String message) toast;

  Future<void> openBatchRateEditor(
    AccountProjectVM project,
    List<Device> devices,
    List<ProjectDeviceRate> rates,
  ) async {
    final rateStore = context.read<ProjectRateStore>();
    final usedDevices = devices
        .where((d) => d.id != null && project.deviceIds.contains(d.id!))
        .toList();

    if (usedDevices.isEmpty) {
      toast(noEditableDevicesMessage());
      return;
    }

    final first = usedDevices.first;
    final firstId = first.id!;
    double? initDiggingOverride;
    double? initBreakingOverride;
    final projectId = project.effectiveProjectId;
    for (final r in rates) {
      if (r.effectiveProjectId != projectId || r.deviceId != firstId) continue;
      if (r.isBreaking) {
        initBreakingOverride = r.effectiveRate;
      } else {
        initDiggingOverride = r.effectiveRate;
      }
    }
    final initDigging = (initDiggingOverride ?? first.effectiveDefaultUnitPrice)
        .round();
    final initBreaking =
        (initBreakingOverride ??
                first.effectiveBreakingUnitPrice ??
                first.effectiveDefaultUnitPrice)
            .round();

    final l10n = AppLocalizations.of(context);
    final projectTitle = ProjectTitleFormatter.normalize(project.displayName);
    final newRate = await showDialog<AccountBatchRateUpdate>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AccountRateBatchDialog(
        title: l10n.accountBatchRateTitle(projectTitle),
        deviceCount: usedDevices.length,
        initialDiggingRateInt: initDigging,
        initialBreakingRateInt: initBreaking,
      ),
    );

    if (!isMounted() || newRate == null) return;

    Future.microtask(() async {
      if (!isMounted()) return;

      for (final d in usedDevices) {
        final id = d.id!;
        await rateStore.upsert(
          ProjectDeviceRate(
            projectId: projectId,
            projectKey: project.projectKey,
            deviceId: id,
            isBreaking: false,
            rate: newRate.diggingRate,
          ),
        );

        await rateStore.upsert(
          ProjectDeviceRate(
            projectId: projectId,
            projectKey: project.projectKey,
            deviceId: id,
            isBreaking: true,
            rate: newRate.breakingRate,
          ),
        );

        final saveFeedback = storeActionFeedback(
          rateStore,
          action: StoreActionKind.save,
        );
        if (!saveFeedback.isSuccess) {
          toast(localizeStoreActionFeedback(l10n, saveFeedback));
          return;
        }
      }

      toast(
        localizeStoreActionFeedback(
          l10n,
          storeActionFeedback(rateStore, action: StoreActionKind.update),
        ),
      );
    });
  }

  Future<void> openSingleRateEditor(
    AccountProjectVM project,
    int deviceId,
    bool isBreaking,
    List<Device> devices,
    List<ProjectDeviceRate> rates,
  ) async {
    final rateStore = context.read<ProjectRateStore>();
    final hit = devices.where((e) => e.id == deviceId).toList();
    if (hit.isEmpty) {
      toast(missingEntityMessage('设备'));
      return;
    }
    final device = hit.first;
    final l10n = AppLocalizations.of(context);

    double? currentOverride;
    final projectId = project.effectiveProjectId;
    for (final r in rates) {
      if (r.effectiveProjectId == projectId &&
          r.deviceId == deviceId &&
          r.isBreaking == isBreaking) {
        currentOverride = r.effectiveRate;
        break;
      }
    }

    final modeDefaultRate = isBreaking
        ? (device.effectiveBreakingUnitPrice ??
              device.effectiveDefaultUnitPrice)
        : device.effectiveDefaultUnitPrice;
    final current = (currentOverride ?? modeDefaultRate).round();

    final projectTitle = ProjectTitleFormatter.normalize(project.displayName);
    final newRate = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AccountRateSingleDialog(
        title: isBreaking
            ? l10n.accountBreakingRateTitle(projectTitle)
            : l10n.accountSingleRateTitle(projectTitle),
        deviceName: isBreaking
            ? l10n.accountBreakingDeviceLabel(device.name)
            : device.name,
        initialRateInt: current,
      ),
    );

    if (!isMounted() || newRate == null) return;

    Future.microtask(() async {
      if (!isMounted()) return;

      await rateStore.upsert(
        ProjectDeviceRate(
          projectId: projectId,
          projectKey: project.projectKey,
          deviceId: deviceId,
          isBreaking: isBreaking,
          rate: newRate,
        ),
      );

      final feedback = storeActionFeedback(
        rateStore,
        action: StoreActionKind.save,
        successOverrideText: l10n.accountUpdated,
      );
      toast(localizeStoreActionFeedback(l10n, feedback));
    });
  }
}
