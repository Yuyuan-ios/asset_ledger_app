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
import 'project_account_detail_content_pattern.dart';

/// 阶段 C Step 10：项目账户详情 sheet 的展示派生从 [AccountProjectDetailSheet]
/// pattern 上移到此处，让 pattern 只剩"接收 VM + 渲染 UI + 回调"。
///
/// builder 是纯只读映射：不读写数据库、不调用 repository、不执行
/// settlement / writeOff / payment 写操作，只把 [AccountComputed] 等输入折算成
/// pattern 需要展示的 [AccountProjectDetailSheetVm]。
///
/// 位置说明：放在 `patterns/account/` 而非 feature 层 view_models，因为
/// 合并明细行类型 [ProjectAccountDetailRateRow] 定义在
/// [project_account_detail_content_pattern.dart]（patterns 层）。若把 builder
/// 放进 features 反而会让 features import patterns，违反分层方向。builder 仅
/// import data/models 与 features 的 model / domain service（与原 pattern 相同），
/// 不触及 infrastructure / repository / db / use_cases。
class AccountProjectDetailSheetVm {
  const AccountProjectDetailSheetVm({
    required this.project,
    required this.title,
    required this.isMerged,
    required this.isProjectSettled,
    required this.hasUniqueWriteOffForRevoke,
    required this.writeOffs,
    required this.deletableWriteOffTarget,
    required this.externalWorkRows,
    required this.mergedDetailRows,
    required this.mergedPaymentDisplayItems,
    required this.usedDevices,
    required this.deviceRates,
    required this.breakingDeviceRates,
    required this.normalHoursByDevice,
    required this.breakingHoursByDevice,
  });

  /// 命中的项目（普通或合并）。回调透传给上层时使用。
  final AccountProjectVM project;
  final String title;
  final bool isMerged;
  final bool isProjectSettled;
  final bool hasUniqueWriteOffForRevoke;
  final List<ProjectWriteOff> writeOffs;

  /// 删除式撤销（无 onRevokeProjectWriteOff 时）应删除的唯一核销记录；
  /// 不满足条件时为 null。具体走哪条撤销回调由 pattern 结合自身入参决定。
  final ProjectWriteOff? deletableWriteOffTarget;

  final List<AccountProjectExternalWorkDetailRow> externalWorkRows;

  // 合并项目专用。
  final List<ProjectAccountDetailRateRow> mergedDetailRows;
  final List<AccountProjectPaymentDisplayVM> mergedPaymentDisplayItems;

  // 普通项目专用。
  final List<Device> usedDevices;
  final Map<int, double> deviceRates;
  final Map<int, double> breakingDeviceRates;
  final Map<int, double> normalHoursByDevice;
  final Map<int, double> breakingHoursByDevice;
}

class AccountProjectDetailSheetVmBuilder {
  const AccountProjectDetailSheetVmBuilder({
    required this.computed,
    required this.timingRecords,
    required this.allDevices,
    required this.allWriteOffs,
    required this.allRates,
    required this.allExternalWorkItems,
    required this.settledProjectIds,
  });

  final AccountComputed computed;
  final List<TimingRecord> timingRecords;
  final List<Device> allDevices;
  final List<ProjectWriteOff> allWriteOffs;
  final List<ProjectDeviceRate> allRates;
  final List<TimingExternalWorkRecordItem> allExternalWorkItems;
  final Set<String>? settledProjectIds;

  static const double _moneyEpsilon = 0.000001;

  /// 解析出目标项目并折算展示 VM；未命中时返回 null（pattern 渲染空态）。
  AccountProjectDetailSheetVm? build({
    String? projectId,
    required String projectKey,
  }) {
    final normalizedProjectId = projectId?.trim() ?? '';
    final hit = computed.projects.where((project) {
      if (normalizedProjectId.isNotEmpty) {
        return project.effectiveProjectId == normalizedProjectId;
      }
      return project.projectKey == projectKey;
    }).toList();

    if (hit.isEmpty) return null;

    final project = hit.first;
    final isMerged = project.kind == AccountProjectKind.merged;
    final writeOffs = _writeOffsForProject(project);
    final externalWorkRows = buildAccountProjectExternalWorkDetailRows(
      externalWorkItems: allExternalWorkItems,
      projectIdentityIds: _externalWorkTargetProjectIds(project),
    );

    if (isMerged) {
      return AccountProjectDetailSheetVm(
        project: project,
        title: ProjectTitleFormatter.normalize(project.displayName),
        isMerged: true,
        isProjectSettled: _isProjectSettled(project),
        hasUniqueWriteOffForRevoke: _hasRevokableWriteOffForProject(
          project,
          writeOffs,
        ),
        writeOffs: writeOffs,
        deletableWriteOffTarget: _deletableWriteOffTarget(project, writeOffs),
        externalWorkRows: externalWorkRows,
        mergedDetailRows: _buildMergedDetailRows(project),
        mergedPaymentDisplayItems: buildMergedPaymentDisplayItems(
          payments: project.payments,
          memberProjectKeys: project.memberProjectKeys,
        ),
        usedDevices: const [],
        deviceRates: const {},
        breakingDeviceRates: const {},
        normalHoursByDevice: const {},
        breakingHoursByDevice: const {},
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

    return AccountProjectDetailSheetVm(
      project: project,
      title: ProjectTitleFormatter.normalize(project.displayName),
      isMerged: false,
      isProjectSettled: _isProjectSettled(project),
      hasUniqueWriteOffForRevoke: _hasRevokableWriteOffForProject(
        project,
        writeOffs,
      ),
      writeOffs: writeOffs,
      deletableWriteOffTarget: _deletableWriteOffTarget(project, writeOffs),
      externalWorkRows: externalWorkRows,
      mergedDetailRows: const [],
      mergedPaymentDisplayItems: const [],
      usedDevices: usedDevices,
      deviceRates: deviceRates,
      breakingDeviceRates: breakingDeviceRates,
      normalHoursByDevice: normalHoursByDevice,
      breakingHoursByDevice: breakingHoursByDevice,
    );
  }

  /// 合并项目修改单价时，把被点击的明细行还原为对应成员项目的最小 VM。
  /// 纯转换，行为与原 pattern 内联逻辑一致。
  static AccountProjectVM memberProjectForRateEdit({
    required int minYmd,
    required ProjectAccountDetailRateRow row,
  }) {
    final key = ProjectKey.fromKey(row.projectKey);
    return AccountProjectVM(
      projectKey: row.projectKey,
      displayName: ProjectTitleFormatter.project(
        contact: key.contact,
        site: key.site,
      ),
      minYmd: minYmd,
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

  bool _hasRevokableWriteOffForProject(
    AccountProjectVM project,
    List<ProjectWriteOff> projectWriteOffs,
  ) {
    if (project.writeOff <= _moneyEpsilon || projectWriteOffs.isEmpty) {
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

  ProjectWriteOff? _deletableWriteOffTarget(
    AccountProjectVM project,
    List<ProjectWriteOff> projectWriteOffs,
  ) {
    if (projectWriteOffs.isEmpty) return null;
    if (project.kind == AccountProjectKind.merged &&
        projectWriteOffs.length != 1) {
      return null;
    }
    return projectWriteOffs.first;
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
      return project.remaining.abs() <= _moneyEpsilon;
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

  /// 外协设备明细的目标 projectId 集合。
  ///
  /// 合并项目只使用真实的 [AccountProjectVM.memberProjectIds]，绝不能匹配合成
  /// 的 `merge:<groupId>`（这种 id 不会出现在 [ExternalWorkRecord.linkedProjectId]
  /// 上）。普通项目用 [AccountProjectVM.effectiveProjectId]。
  Set<String> _externalWorkTargetProjectIds(AccountProjectVM project) {
    if (project.kind == AccountProjectKind.merged) {
      return project.memberProjectIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
    }
    final normalized = project.effectiveProjectId.trim();
    return normalized.isEmpty ? const <String>{} : {normalized};
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

  double? _rateFor(String projectKey, int deviceId, {required bool isBreaking}) {
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
