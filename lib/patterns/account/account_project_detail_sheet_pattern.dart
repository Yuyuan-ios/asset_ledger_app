import 'package:flutter/material.dart';

import '../../data/models/account_payment.dart';
import '../../data/models/device.dart';
import '../../data/models/project_device_rate.dart';
import '../../data/models/project_write_off.dart';
import '../../data/models/timing_record.dart';
import '../../features/account/model/account_project_payment_display_vm.dart';
import '../../features/account/model/account_view_model.dart';
import '../../features/timing/state/timing_external_work_store.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../tokens/mapper/core_tokens.dart';
import 'account_project_detail_sheet_vm.dart';
import 'project_account_detail_content_pattern.dart';

typedef AccountOpenBatchRateEditor =
    Future<void> Function(
      AccountProjectVM project,
      List<Device> devices,
      List<ProjectDeviceRate> rates,
    );

typedef AccountOpenSingleRateEditor =
    Future<void> Function(
      AccountProjectVM project,
      int deviceId,
      bool isBreaking,
      List<Device> devices,
      List<ProjectDeviceRate> rates,
    );

typedef AccountOpenPaymentEditor =
    Future<void> Function({
      required AccountProjectVM project,
      required List<AccountPayment> allPayments,
      AccountPayment? editing,
    });

typedef AccountDeletePayment = Future<void> Function(AccountPayment payment);

typedef AccountDeleteProjectWriteOff =
    Future<void> Function(ProjectWriteOff writeOff);

typedef AccountOpenProjectSettlement =
    Future<void> Function(AccountProjectVM project);

typedef AccountRevokeProjectWriteOff =
    Future<void> Function(AccountProjectVM project);

typedef AccountDissolveMergeGroup =
    Future<void> Function(AccountProjectVM project);

typedef AccountOpenMergedPaymentEditor =
    Future<void> Function(AccountProjectVM project);

typedef AccountOpenMergedPaymentBatchEditor =
    Future<void> Function(
      AccountProjectVM project,
      AccountProjectPaymentDisplayVM payment,
    );

class AccountProjectDetailSheet extends StatelessWidget {
  const AccountProjectDetailSheet({
    super.key,
    this.projectId,
    required this.projectKey,
    required this.timingRecords,
    required this.allDevices,
    required this.allPayments,
    this.allWriteOffs = const [],
    required this.allRates,
    this.allExternalWorkItems = const [],
    required this.computed,
    this.settledProjectIds,
    required this.onBatchEditRate,
    required this.onEditDeviceRate,
    required this.onAddPayment,
    required this.onEditPayment,
    required this.onDeletePayment,
    this.onDeleteWriteOff,
    this.onRevokeProjectWriteOff,
    this.onSettleProject,
    this.onDissolveMergeGroup,
    this.onAddMergedPayment,
    this.onEditMergedPaymentBatch,
    this.onDeleteMergedPaymentBatch,
    this.showInlineAddPayment = true,
  });

  final String? projectId;
  final String projectKey;
  final List<TimingRecord> timingRecords;
  final List<Device> allDevices;
  final List<AccountPayment> allPayments;
  final List<ProjectWriteOff> allWriteOffs;
  final List<ProjectDeviceRate> allRates;
  final List<TimingExternalWorkRecordItem> allExternalWorkItems;
  final AccountComputed computed;
  final Set<String>? settledProjectIds;
  final AccountOpenBatchRateEditor onBatchEditRate;
  final AccountOpenSingleRateEditor onEditDeviceRate;
  final AccountOpenPaymentEditor onAddPayment;
  final AccountOpenPaymentEditor onEditPayment;
  final AccountDeletePayment onDeletePayment;
  final AccountDeleteProjectWriteOff? onDeleteWriteOff;
  final AccountRevokeProjectWriteOff? onRevokeProjectWriteOff;
  final AccountOpenProjectSettlement? onSettleProject;
  final AccountDissolveMergeGroup? onDissolveMergeGroup;
  final AccountOpenMergedPaymentEditor? onAddMergedPayment;
  final AccountOpenMergedPaymentBatchEditor? onEditMergedPaymentBatch;
  final AccountOpenMergedPaymentBatchEditor? onDeleteMergedPaymentBatch;
  final bool showInlineAddPayment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vm = AccountProjectDetailSheetVmBuilder(
      computed: computed,
      timingRecords: timingRecords,
      allDevices: allDevices,
      allWriteOffs: allWriteOffs,
      allRates: allRates,
      allExternalWorkItems: allExternalWorkItems,
      settledProjectIds: settledProjectIds,
    ).build(projectId: projectId, projectKey: projectKey);

    if (vm == null) {
      return Padding(
        padding: const EdgeInsets.all(SpaceTokens.pagePadding),
        child: Text(l10n.accountProjectMissing),
      );
    }

    final project = vm.project;
    final revokeWriteOff = _revokeWriteOff(project, vm.deletableWriteOffTarget);

    if (vm.isMerged) {
      return ProjectAccountDetailContent(
        title: vm.title,
        minYmd: project.minYmd,
        devices: const [],
        deviceRates: const {},
        breakingDeviceRates: const {},
        normalHoursByDevice: const {},
        breakingHoursByDevice: const {},
        receivable: project.receivable,
        writeOff: project.writeOff,
        remaining: project.remaining,
        isProjectSettled: vm.isProjectSettled,
        hasUniqueWriteOffForRevoke: vm.hasUniqueWriteOffForRevoke,
        hasLinkedExternalWork: project.hasLinkedExternalWork,
        payments: project.payments,
        writeOffs: vm.writeOffs,
        paymentDisplayItems: vm.mergedPaymentDisplayItems,
        detailRows: vm.mergedDetailRows,
        externalWorkRows: vm.externalWorkRows,
        showBatchAction:
            project.mergeGroupId != null && onDissolveMergeGroup != null,
        batchActionText: l10n.accountDissolveMergeAction,
        showPaymentActions:
            onEditMergedPaymentBatch != null ||
            onDeleteMergedPaymentBatch != null,
        showRawPaymentActions: false,
        showAddPayment: showInlineAddPayment && onAddMergedPayment != null,
        canEditRates: !vm.isProjectSettled,
        onBatchEditRate: () => onDissolveMergeGroup?.call(project),
        onEditDeviceRate: (_, _) {},
        onEditRateRow: (row) {
          final memberProject =
              AccountProjectDetailSheetVmBuilder.memberProjectForRateEdit(
                minYmd: project.minYmd,
                row: row,
              );
          onEditDeviceRate(
            memberProject,
            row.deviceId,
            row.isBreaking,
            allDevices,
            allRates,
          );
        },
        onAddPayment: () => onAddMergedPayment?.call(project),
        onSettleProject: onSettleProject == null
            ? null
            : () => onSettleProject?.call(project),
        onEditPayment: (_) {},
        onDeletePayment: (_) {},
        onDeleteWriteOff: onDeleteWriteOff,
        onRevokeWriteOff: revokeWriteOff,
        onEditPaymentDisplayItem: (payment) =>
            onEditMergedPaymentBatch?.call(project, payment),
        onDeletePaymentDisplayItem: (payment) =>
            onDeleteMergedPaymentBatch?.call(project, payment),
      );
    }

    return ProjectAccountDetailContent(
      title: vm.title,
      minYmd: project.minYmd,
      devices: vm.usedDevices,
      deviceRates: vm.deviceRates,
      breakingDeviceRates: vm.breakingDeviceRates,
      normalHoursByDevice: vm.normalHoursByDevice,
      breakingHoursByDevice: vm.breakingHoursByDevice,
      receivable: project.receivable,
      writeOff: project.writeOff,
      remaining: project.remaining,
      isProjectSettled: vm.isProjectSettled,
      hasUniqueWriteOffForRevoke: vm.hasUniqueWriteOffForRevoke,
      hasLinkedExternalWork: project.hasLinkedExternalWork,
      payments: project.payments,
      writeOffs: vm.writeOffs,
      externalWorkRows: vm.externalWorkRows,
      canEditRates: !vm.isProjectSettled,
      onBatchEditRate: () => onBatchEditRate(project, allDevices, allRates),
      onEditDeviceRate: (deviceId, isBreaking) =>
          onEditDeviceRate(project, deviceId, isBreaking, allDevices, allRates),
      showAddPayment: showInlineAddPayment,
      onAddPayment: () =>
          onAddPayment(project: project, allPayments: allPayments),
      onSettleProject: onSettleProject == null
          ? null
          : () => onSettleProject?.call(project),
      onEditPayment: (payment) => onEditPayment(
        project: project,
        allPayments: allPayments,
        editing: payment,
      ),
      onDeletePayment: onDeletePayment,
      onDeleteWriteOff: onDeleteWriteOff,
      onRevokeWriteOff: revokeWriteOff,
    );
  }

  /// 把"撤销核销"决策（来自 VM 的纯只读判定）映射到本 widget 的回调上。
  /// 决策本身不在这里做：VM 已给出可删除的唯一核销目标，pattern 只负责接线。
  VoidCallback? _revokeWriteOff(
    AccountProjectVM project,
    ProjectWriteOff? deletableWriteOffTarget,
  ) {
    final revokeProject = onRevokeProjectWriteOff;
    if (revokeProject != null) {
      return () => revokeProject(project);
    }
    final deleteWriteOff = onDeleteWriteOff;
    final target = deletableWriteOffTarget;
    if (deleteWriteOff == null || target == null) return null;
    return () => deleteWriteOff(target);
  }
}
