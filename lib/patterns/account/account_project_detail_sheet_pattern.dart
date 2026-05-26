import 'package:flutter/material.dart';

import '../../data/models/account_payment.dart';
import '../../data/models/device.dart';
import '../../data/models/project_device_rate.dart';
import '../../data/models/project_key.dart';
import '../../data/models/project_write_off.dart';
import '../../data/models/timing_record.dart';
import '../../features/account/domain/services/external_work_detail_rows.dart';
import '../../features/account/model/account_project_payment_display_vm.dart';
import '../../features/account/model/account_view_model.dart';
import '../../features/account/model/project_title_formatter.dart';
import '../../features/timing/state/timing_external_work_store.dart';
import '../../tokens/mapper/core_tokens.dart';
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

const double _detailSheetMoneyEpsilon = 0.000001;

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
    final normalizedProjectId = projectId?.trim() ?? '';
    final hit = computed.projects.where((project) {
      if (normalizedProjectId.isNotEmpty) {
        return project.effectiveProjectId == normalizedProjectId;
      }
      return project.projectKey == projectKey;
    }).toList();

    if (hit.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(SpaceTokens.pagePadding),
        child: Text('项目不存在或已被清理'),
      );
    }

    final project = hit.first;
    final projectTitle = ProjectTitleFormatter.normalize(project.displayName);
    final projectWriteOffs = _writeOffsForProject(project);
    final revokeWriteOff = _revokeWriteOffAction(project, projectWriteOffs);
    final projectIsSettled = _isProjectSettled(project);
    final hasUniqueWriteOffForRevoke = _hasRevokableWriteOffForProject(
      project,
      projectWriteOffs,
    );
    final externalWorkRows = buildAccountProjectExternalWorkDetailRows(
      externalWorkItems: allExternalWorkItems,
      projectIdentityIds: _projectIdentityIds(project),
    );
    if (project.kind == AccountProjectKind.merged) {
      final detailRows = _buildMergedDetailRows(project);
      final paymentDisplayItems = buildMergedPaymentDisplayItems(
        payments: project.payments,
        memberProjectKeys: project.memberProjectKeys,
      );
      return ProjectAccountDetailContent(
        title: projectTitle,
        minYmd: project.minYmd,
        devices: const [],
        deviceRates: const {},
        breakingDeviceRates: const {},
        normalHoursByDevice: const {},
        breakingHoursByDevice: const {},
        receivable: project.receivable,
        writeOff: project.writeOff,
        remaining: project.remaining,
        isProjectSettled: projectIsSettled,
        hasUniqueWriteOffForRevoke: hasUniqueWriteOffForRevoke,
        hasLinkedExternalWork: project.hasLinkedExternalWork,
        payments: project.payments,
        writeOffs: projectWriteOffs,
        paymentDisplayItems: paymentDisplayItems,
        detailRows: detailRows,
        externalWorkRows: externalWorkRows,
        showBatchAction:
            project.mergeGroupId != null && onDissolveMergeGroup != null,
        batchActionText: '解除合并',
        showPaymentActions:
            onEditMergedPaymentBatch != null ||
            onDeleteMergedPaymentBatch != null,
        showRawPaymentActions: false,
        showAddPayment: showInlineAddPayment && onAddMergedPayment != null,
        onBatchEditRate: () => onDissolveMergeGroup?.call(project),
        onEditDeviceRate: (_, _) {},
        onEditRateRow: (row) {
          final memberProject = _memberProjectForRateEdit(project, row);
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

    final usedDevices = allDevices
        .where(
          (device) =>
              device.id != null && project.deviceIds.contains(device.id!),
        )
        .toList();

    final normalHoursByDevice = <int, double>{};
    final breakingHoursByDevice = <int, double>{};
    for (final record in timingRecords) {
      if (record.type != TimingType.hours) continue;
      final key = ProjectKey.buildKey(
        contact: record.contact.trim(),
        site: record.site.trim(),
      );
      if (key != project.projectKey) continue;
      final target = record.isBreaking
          ? breakingHoursByDevice
          : normalHoursByDevice;
      target[record.deviceId] = (target[record.deviceId] ?? 0.0) + record.hours;
    }

    final deviceRates = <int, double>{};
    final breakingDeviceRates = <int, double>{};
    for (final rate in allRates) {
      if (rate.projectKey != project.projectKey) continue;
      if (rate.isBreaking) {
        breakingDeviceRates[rate.deviceId] = rate.rate;
      } else {
        deviceRates[rate.deviceId] = rate.rate;
      }
    }

    return ProjectAccountDetailContent(
      title: projectTitle,
      minYmd: project.minYmd,
      devices: usedDevices,
      deviceRates: deviceRates,
      breakingDeviceRates: breakingDeviceRates,
      normalHoursByDevice: normalHoursByDevice,
      breakingHoursByDevice: breakingHoursByDevice,
      receivable: project.receivable,
      writeOff: project.writeOff,
      remaining: project.remaining,
      isProjectSettled: projectIsSettled,
      hasUniqueWriteOffForRevoke: hasUniqueWriteOffForRevoke,
      hasLinkedExternalWork: project.hasLinkedExternalWork,
      payments: project.payments,
      writeOffs: projectWriteOffs,
      externalWorkRows: externalWorkRows,
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

  VoidCallback? _revokeWriteOffAction(
    AccountProjectVM project,
    List<ProjectWriteOff> projectWriteOffs,
  ) {
    final revokeProject = onRevokeProjectWriteOff;
    if (revokeProject != null) {
      return () => revokeProject(project);
    }
    final deleteWriteOff = onDeleteWriteOff;
    if (deleteWriteOff == null || projectWriteOffs.isEmpty) return null;
    if (project.kind == AccountProjectKind.merged &&
        projectWriteOffs.length != 1) {
      return null;
    }
    return () => deleteWriteOff(projectWriteOffs.first);
  }

  bool _hasRevokableWriteOffForProject(
    AccountProjectVM project,
    List<ProjectWriteOff> projectWriteOffs,
  ) {
    if (project.writeOff <= _detailSheetMoneyEpsilon ||
        projectWriteOffs.isEmpty) {
      return false;
    }
    if (project.kind != AccountProjectKind.merged) {
      return projectWriteOffs.length == 1;
    }

    final mergeGroupId = project.mergeGroupId;
    if (mergeGroupId == null) return projectWriteOffs.length == 1;

    final mergeWriteOffPrefix = 'writeoff-merge-$mergeGroupId-';
    return projectWriteOffs.every(
      (item) => item.id.trim().startsWith(mergeWriteOffPrefix),
    );
  }

  List<ProjectWriteOff> _writeOffsForProject(AccountProjectVM project) {
    final projectIds = _projectIdentityIds(project);
    return allWriteOffs
        .where((item) => projectIds.contains(item.projectId.trim()))
        .toList(growable: false);
  }

  bool _isProjectSettled(AccountProjectVM project) {
    final explicitSettledIds = settledProjectIds;
    if (explicitSettledIds == null) {
      return project.remaining.abs() <= _detailSheetMoneyEpsilon;
    }
    final projectIds = _projectIdentityIds(project);
    return projectIds.any(explicitSettledIds.contains);
  }

  Set<String> _projectIdentityIds(AccountProjectVM project) {
    return {
      project.effectiveProjectId.trim(),
      if (project.kind == AccountProjectKind.merged)
        ...project.memberProjectIds.map((id) => id.trim()),
    }..removeWhere((id) => id.isEmpty);
  }

  List<ProjectAccountDetailRateRow> _buildMergedDetailRows(
    AccountProjectVM project,
  ) {
    final rows = <ProjectAccountDetailRateRow>[];
    final devicesById = <int, Device>{
      for (final device in allDevices)
        if (device.id != null) device.id!: device,
    };

    for (final memberProjectKey in project.memberProjectKeys) {
      final key = ProjectKey.fromKey(memberProjectKey);
      final normalHoursByDevice = <int, double>{};
      final breakingHoursByDevice = <int, double>{};
      for (final record in timingRecords) {
        if (record.type != TimingType.hours) continue;
        final recordKey = ProjectKey.buildKey(
          contact: record.contact.trim(),
          site: record.site.trim(),
        );
        if (recordKey != memberProjectKey) continue;
        final target = record.isBreaking
            ? breakingHoursByDevice
            : normalHoursByDevice;
        target[record.deviceId] =
            (target[record.deviceId] ?? 0.0) + record.hours;
      }

      final deviceIds = <int>{
        ...normalHoursByDevice.keys,
        ...breakingHoursByDevice.keys,
      }.toList()..sort((a, b) => _deviceOrder(a).compareTo(_deviceOrder(b)));

      var hasShownSite = false;
      for (final deviceId in deviceIds) {
        final device = devicesById[deviceId] ?? _fallbackDevice(deviceId);
        final normalHours = normalHoursByDevice[deviceId] ?? 0.0;
        final breakingHours = breakingHoursByDevice[deviceId] ?? 0.0;
        final normalRate =
            _rateFor(memberProjectKey, deviceId, isBreaking: false) ??
            device.defaultUnitPrice;
        final breakingRate =
            _rateFor(memberProjectKey, deviceId, isBreaking: true) ??
            device.breakingUnitPrice ??
            device.defaultUnitPrice;

        if (normalHours > 0) {
          rows.add(
            ProjectAccountDetailRateRow(
              projectKey: memberProjectKey,
              label: hasShownSite ? '' : key.site.trim(),
              deviceId: deviceId,
              deviceLabel: device.name,
              hours: normalHours,
              rate: normalRate,
              showEdit: true,
              isBreaking: false,
            ),
          );
          hasShownSite = true;
        }

        if (breakingHours > 0) {
          rows.add(
            ProjectAccountDetailRateRow(
              projectKey: memberProjectKey,
              label: hasShownSite ? '' : key.site.trim(),
              deviceId: deviceId,
              deviceLabel: '${device.name} · 破碎',
              hours: breakingHours,
              rate: breakingRate,
              showEdit: true,
              isBreaking: true,
            ),
          );
          hasShownSite = true;
        }
      }
    }

    return rows;
  }

  AccountProjectVM _memberProjectForRateEdit(
    AccountProjectVM mergedProject,
    ProjectAccountDetailRateRow row,
  ) {
    final key = ProjectKey.fromKey(row.projectKey);
    return AccountProjectVM(
      projectKey: row.projectKey,
      displayName: ProjectTitleFormatter.project(
        contact: key.contact,
        site: key.site,
      ),
      minYmd: mergedProject.minYmd,
      deviceIds: [row.deviceId],
      hoursByDevice: {row.deviceId: row.hours},
      rentIncomeTotal: 0,
      minRate: row.rate,
      isMultiDevice: false,
      isMultiMode: row.isBreaking,
      receivable: 0,
      received: 0,
      remaining: 0,
      ratio: null,
      payments: const [],
    );
  }

  double? _rateFor(
    String projectKey,
    int deviceId, {
    required bool isBreaking,
  }) {
    for (final rate in allRates) {
      if (rate.projectKey == projectKey &&
          rate.deviceId == deviceId &&
          rate.isBreaking == isBreaking) {
        return rate.rate;
      }
    }
    return null;
  }

  int _deviceOrder(int deviceId) {
    final index = allDevices.indexWhere((device) => device.id == deviceId);
    return index < 0 ? 1 << 20 : index;
  }

  Device _fallbackDevice(int deviceId) {
    return Device(
      id: deviceId,
      name: '设备#$deviceId',
      brand: '',
      defaultUnitPrice: 0,
      baseMeterHours: 0,
      isActive: false,
    );
  }
}
