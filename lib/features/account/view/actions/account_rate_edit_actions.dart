import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/interaction_feedback.dart';
import '../../../../core/utils/store_feedback.dart';
import '../../../../data/models/device.dart';
import '../../../../data/models/project_device_rate.dart';
import '../../model/account_view_model.dart';
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
    for (final r in rates) {
      if (r.projectKey != project.projectKey || r.deviceId != firstId) continue;
      if (r.isBreaking) {
        initBreakingOverride = r.rate;
      } else {
        initDiggingOverride = r.rate;
      }
    }
    final initDigging = (initDiggingOverride ?? first.defaultUnitPrice).round();
    final initBreaking =
        (initBreakingOverride ??
                first.breakingUnitPrice ??
                first.defaultUnitPrice)
            .round();

    final newRate = await showDialog<AccountBatchRateUpdate>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AccountRateBatchDialog(
        title: '批量修改单价：${project.displayName}',
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
        const eps = 0.05;
        final defaultDigging = d.defaultUnitPrice;
        final defaultBreaking = d.breakingUnitPrice ?? d.defaultUnitPrice;

        if ((newRate.diggingRate - defaultDigging).abs() <= eps) {
          await rateStore.delete(project.projectKey, id, isBreaking: false);
        } else {
          await rateStore.upsert(
            ProjectDeviceRate(
              projectKey: project.projectKey,
              deviceId: id,
              isBreaking: false,
              rate: newRate.diggingRate,
            ),
          );
        }

        if ((newRate.breakingRate - defaultBreaking).abs() <= eps) {
          await rateStore.delete(project.projectKey, id, isBreaking: true);
        } else {
          await rateStore.upsert(
            ProjectDeviceRate(
              projectKey: project.projectKey,
              deviceId: id,
              isBreaking: true,
              rate: newRate.breakingRate,
            ),
          );
        }

        final error = storeErrorMessage(rateStore, action: '保存');
        if (error != null) {
          toast(error);
          return;
        }
      }

      toast(storeActionFeedback(rateStore, action: '更新').message);
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

    double? currentOverride;
    for (final r in rates) {
      if (r.projectKey == project.projectKey &&
          r.deviceId == deviceId &&
          r.isBreaking == isBreaking) {
        currentOverride = r.rate;
        break;
      }
    }

    final modeDefaultRate = isBreaking
        ? (device.breakingUnitPrice ?? device.defaultUnitPrice)
        : device.defaultUnitPrice;
    final current = (currentOverride ?? modeDefaultRate).round();

    final newRate = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AccountRateSingleDialog(
        title: isBreaking ? '编辑破碎单价：${project.displayName}' : '编辑单价：${project.displayName}',
        deviceName: isBreaking ? '${device.name} · 破碎' : device.name,
        initialRateInt: current,
      ),
    );

    if (!isMounted() || newRate == null) return;

    Future.microtask(() async {
      if (!isMounted()) return;

      const eps = 0.05;
      if ((newRate - modeDefaultRate).abs() <= eps) {
        await rateStore.delete(project.projectKey, deviceId, isBreaking: isBreaking);
      } else {
        await rateStore.upsert(
          ProjectDeviceRate(
            projectKey: project.projectKey,
            deviceId: deviceId,
            isBreaking: isBreaking,
            rate: newRate,
          ),
        );
      }

      final feedback = storeActionFeedback(
        rateStore,
        action: '保存',
        successMessage: '已更新',
      );
      toast(feedback.message);
    });
  }
}
