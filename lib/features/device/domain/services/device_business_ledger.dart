import '../../../../core/date/gregorian_year_range.dart';
import '../../../../core/measure/measure_unit.dart';
import '../../../../data/models/account_payment.dart';
import '../../../../data/models/account_project_merge_group_with_members.dart';
import '../../../../data/models/device.dart';
import '../../../../data/models/project_device_rate.dart';
import '../../../../data/models/project_write_off.dart';
import '../../../../data/models/timing_record.dart';
import '../../../account/model/account_view_model.dart';
import '../../../account/use_cases/compute_account_summary_use_case.dart';
import '../../../account/domain/services/project_finance_calculator.dart';

enum DeviceBusinessPaymentStatus { unpaid, partial, paid, settled }

class DeviceBusinessUnitTotal {
  const DeviceBusinessUnitTotal({
    required this.unit,
    required this.quantityScaled,
  });

  final MeasureUnit unit;
  final int quantityScaled;

  double get quantity => quantityScaled / 1000.0;
}

class DeviceBusinessProjectHistory {
  const DeviceBusinessProjectHistory({
    required this.projectId,
    required this.projectName,
    required this.minYmd,
    required this.receivableFen,
    required this.receivedFen,
    required this.writeOffFen,
    required this.remainingFen,
    required this.paymentStatus,
    required this.unitTotals,
  });

  final String projectId;
  final String projectName;
  final int minYmd;
  final int receivableFen;
  final int receivedFen;
  final int writeOffFen;
  final int remainingFen;
  final DeviceBusinessPaymentStatus paymentStatus;
  final List<DeviceBusinessUnitTotal> unitTotals;
}

class DeviceBusinessLedger {
  const DeviceBusinessLedger({
    required this.deviceId,
    required this.deviceName,
    required this.incomeFen,
    required this.unitTotals,
    required this.projects,
  });

  final int deviceId;
  final String deviceName;
  final int incomeFen;
  final List<DeviceBusinessUnitTotal> unitTotals;
  final List<DeviceBusinessProjectHistory> projects;
}

class DeviceBusinessLedgerUseCase {
  const DeviceBusinessLedgerUseCase({
    ComputeAccountSummaryUseCase accountSummaryUseCase =
        const ComputeAccountSummaryUseCase(),
  }) : _accountSummaryUseCase = accountSummaryUseCase;

  final ComputeAccountSummaryUseCase _accountSummaryUseCase;

  List<DeviceBusinessLedger> execute({
    required List<TimingRecord> timingRecords,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required List<AccountPayment> payments,
    List<ProjectWriteOff> writeOffs = const [],
    List<AccountProjectMergeGroupWithMembers> activeMergeGroups = const [],
    Set<String> settledProjectIds = const {},
    int? summaryYear,
  }) {
    final visibleDevices = devices.where((device) => device.id != null).toList()
      ..sort((a, b) => a.id!.compareTo(b.id!));
    if (visibleDevices.isEmpty) return const [];

    final summaryRange = _resolveSummaryRange(
      summaryYear: summaryYear,
      timingRecords: timingRecords,
    );
    final summaryRecords = timingRecords
        .where((record) {
          return summaryRange.containsYmd(record.startDate);
        })
        .toList(growable: false);

    final accountComputed = _accountSummaryUseCase.execute(
      timingRecords: timingRecords,
      devices: devices,
      rates: rates,
      payments: payments,
      writeOffs: writeOffs,
      activeMergeGroups: activeMergeGroups,
      settledProjectIds: settledProjectIds,
      summaryYear: summaryYear,
    );
    final incomeFenByDevice = {
      for (final item in accountComputed.deviceReceivables)
        item.deviceId: item.amountFen!,
    };
    final projectsById = <String, AccountProjectVM>{};
    for (final project in accountComputed.projects) {
      for (final projectId in _projectIdsFor(project)) {
        projectsById[projectId] = project;
      }
    }

    return [
      for (final device in visibleDevices)
        DeviceBusinessLedger(
          deviceId: device.id!,
          deviceName: device.name,
          incomeFen: incomeFenByDevice[device.id!] ?? 0,
          unitTotals: _unitTotalsForDevice(
            records: summaryRecords,
            deviceId: device.id!,
          ),
          projects: _projectsForDevice(
            records: summaryRecords,
            deviceId: device.id!,
            accountProjects: accountComputed.projects,
            projectsById: projectsById,
            moneyFenByProjectId: accountComputed.moneyFenByProjectId,
          ),
        ),
    ];
  }

  GregorianYearRange _resolveSummaryRange({
    required int? summaryYear,
    required List<TimingRecord> timingRecords,
  }) {
    if (summaryYear != null) return GregorianYearRange.forYear(summaryYear);
    if (timingRecords.isEmpty) {
      return GregorianYearRange.forYear(DateTime.now().year);
    }

    var latestYear = timingRecords.first.startDate ~/ 10000;
    for (final record in timingRecords.skip(1)) {
      final year = record.startDate ~/ 10000;
      if (year > latestYear) latestYear = year;
    }
    return GregorianYearRange.forYear(latestYear);
  }

  List<DeviceBusinessUnitTotal> _unitTotalsForDevice({
    required List<TimingRecord> records,
    required int deviceId,
    Set<String>? projectIds,
  }) {
    final totals = <MeasureUnit, int>{};
    for (final record in records) {
      if (record.deviceId != deviceId) continue;
      if (projectIds != null &&
          !projectIds.contains(record.effectiveProjectId)) {
        continue;
      }
      final quantityScaled = record.quantityScaled;
      if (quantityScaled == null || quantityScaled <= 0) continue;
      totals[record.unit] = (totals[record.unit] ?? 0) + quantityScaled;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));
    return [
      for (final entry in entries)
        DeviceBusinessUnitTotal(unit: entry.key, quantityScaled: entry.value),
    ];
  }

  List<DeviceBusinessProjectHistory> _projectsForDevice({
    required List<TimingRecord> records,
    required int deviceId,
    required List<AccountProjectVM> accountProjects,
    required Map<String, AccountProjectVM> projectsById,
    Map<String, AccountProjectMoneyFenVM> moneyFenByProjectId = const {},
  }) {
    final projectIds = <String>{};
    for (final record in records) {
      if (record.deviceId == deviceId) {
        projectIds.add(record.effectiveProjectId);
      }
    }
    if (projectIds.isEmpty) return const [];

    final projects = <AccountProjectVM>{};
    for (final projectId in projectIds) {
      final project = projectsById[projectId];
      if (project != null) projects.add(project);
    }
    final orderedProjects = projects.toList()
      ..sort((a, b) {
        final byDate = b.minYmd.compareTo(a.minYmd);
        if (byDate != 0) return byDate;
        return a.displayName.compareTo(b.displayName);
      });

    return [
      for (final project in orderedProjects)
        _projectHistoryFor(
          project: project,
          records: records,
          deviceId: deviceId,
          moneyFenByProjectId: moneyFenByProjectId,
        ),
    ];
  }

  /// 项目历史金额消费整数分权威快照（calcMoneyFen 直出,合并卡按成员求和）。
  DeviceBusinessProjectHistory _projectHistoryFor({
    required AccountProjectVM project,
    required List<TimingRecord> records,
    required int deviceId,
    required Map<String, AccountProjectMoneyFenVM> moneyFenByProjectId,
  }) {
    final realIds = _projectIdsFor(project);
    var receivableFen = 0;
    var receivedFen = 0;
    var writeOffFen = 0;
    for (final id in realIds) {
      final fen = moneyFenByProjectId[id];
      if (fen == null) continue;
      receivableFen += fen.receivableFen;
      receivedFen += fen.receivedFen;
      writeOffFen += fen.writeOffFen;
    }
    final finance = ProjectFinanceCalculator.summarizeTotals(
      receivableFen: receivableFen,
      receivedFen: receivedFen,
      writeOffFen: writeOffFen,
      toleranceFen: 1,
    );

    return DeviceBusinessProjectHistory(
      projectId: project.projectId,
      projectName: project.displayName,
      minYmd: project.minYmd,
      receivableFen: receivableFen,
      receivedFen: receivedFen,
      writeOffFen: writeOffFen,
      remainingFen: finance.remainingFen,
      paymentStatus: _paymentStatusFor(project),
      unitTotals: _unitTotalsForDevice(
        records: records,
        deviceId: deviceId,
        projectIds: realIds,
      ),
    );
  }

  Set<String> _projectIdsFor(AccountProjectVM project) {
    final ids = <String>{};
    final projectId = project.projectId.trim();
    if (projectId.isNotEmpty && !projectId.startsWith('merge:')) {
      ids.add(projectId);
    }
    ids.addAll(
      project.memberProjectIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty),
    );
    if (ids.isEmpty) ids.add(project.effectiveProjectId);
    return ids;
  }

  DeviceBusinessPaymentStatus _paymentStatusFor(AccountProjectVM project) {
    if (project.isSettledForDisplay || project.remaining <= 0) {
      return DeviceBusinessPaymentStatus.settled;
    }
    if (project.received <= 0 && project.writeOff <= 0) {
      return DeviceBusinessPaymentStatus.unpaid;
    }
    if (project.remaining > 0) return DeviceBusinessPaymentStatus.partial;
    return DeviceBusinessPaymentStatus.paid;
  }
}
