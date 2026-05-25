import '../../../data/models/account_payment.dart';
import '../../../data/models/device.dart';
import '../../../data/models/account_project_merge_group_with_members.dart';
import '../../../data/models/project_device_rate.dart';
import '../../../data/models/project_write_off.dart';
import '../../../data/models/timing_record.dart';
import '../../../data/services/account_service.dart';
import '../../../core/date/gregorian_year_range.dart';
import 'package:asset_ledger/data/models/device_maps.dart';
import '../domain/services/project_finance_calculator.dart';
import '../model/account_view_model.dart';

class ComputeAccountSummaryUseCase {
  const ComputeAccountSummaryUseCase();

  AccountComputed execute({
    required List<TimingRecord> timingRecords,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required List<AccountPayment> payments,
    List<ProjectWriteOff> writeOffs = const [],
    List<AccountProjectMergeGroupWithMembers> activeMergeGroups = const [],
    int? summaryYear,
  }) {
    final summaryRange = _resolveSummaryRange(
      summaryYear: summaryYear,
      timingRecords: timingRecords,
    );
    final projects = AccountService.buildProjects(timingRecords: timingRecords);
    final summaryTimingRecords = timingRecords.where((record) {
      return summaryRange.containsYmd(record.startDate);
    }).toList();
    final receivableByDevice = _calcNetReceivableByDevice(
      timingRecords: summaryTimingRecords,
      devices: devices,
      rates: rates,
      writeOffs: writeOffs,
      summaryRange: summaryRange,
    );

    final keys = projects.keys.toList()
      ..sort((a, b) => projects[b]!.minYmd.compareTo(projects[a]!.minYmd));

    final normalItems = <AccountProjectVM>[];

    for (final key in keys) {
      final agg = projects[key]!;

      final money = AccountService.calcMoney(
        agg: agg,
        devices: devices,
        rates: rates,
        payments: payments,
        writeOffs: writeOffs,
      );
      final finance = ProjectFinanceCalculator.summarizeTotals(
        receivableFen: ProjectFinanceCalculator.yuanToFen(money.receivable),
        receivedFen: ProjectFinanceCalculator.yuanToFen(money.received),
        writeOffFen: ProjectFinanceCalculator.yuanToFen(money.writeOff),
        toleranceFen: 1,
      );

      final rateInfo = AccountService.calcRateInfo(
        agg: agg,
        devices: devices,
        rates: rates,
      );

      normalItems.add(
        AccountProjectVM(
          projectId: agg.projectId,
          projectKey: agg.projectKey,
          displayName: agg.pk.displayName,
          minYmd: agg.minYmd,
          deviceIds: agg.deviceIds,
          hoursByDevice: agg.hoursByDevice,
          rentIncomeTotal: agg.rentIncomeTotal,
          minRate: rateInfo.minRate,
          isMultiDevice: rateInfo.isMultiDevice,
          isMultiMode: rateInfo.isMultiMode,
          receivable: finance.receivable,
          received: finance.received,
          writeOff: finance.writeOff,
          remaining: finance.remaining,
          ratio: finance.cashRate,
          settlementRatio: finance.settlementRate,
          payments: payments.where((payment) {
            return payment.effectiveProjectId == agg.projectId;
          }).toList()..sort((a, b) => b.ymd.compareTo(a.ymd)),
        ),
      );
    }

    final summary = _buildAnnualSummary(
      timingRecords: summaryTimingRecords,
      devices: devices,
      rates: rates,
      payments: payments,
      writeOffs: writeOffs,
      summaryRange: summaryRange,
    );

    final items = _applyMergeGroups(
      normalItems: normalItems,
      activeMergeGroups: activeMergeGroups,
    );

    final deviceById = buildDeviceByIdMap(devices);

    final deviceReceivables =
        receivableByDevice.entries.where((entry) => entry.value > 0).map((
          entry,
        ) {
          final device =
              deviceById[entry.key] ??
              Device(
                id: entry.key,
                name: '设备#${entry.key}',
                brand: '',
                defaultUnitPrice: 0,
                baseMeterHours: 0,
                isActive: false,
              );
          return AccountDeviceReceivable(
            deviceId: entry.key,
            name: device.name,
            amount: entry.value,
          );
        }).toList()..sort((a, b) {
          final byLength = a.name.length.compareTo(b.name.length);
          if (byLength != 0) return byLength;
          return a.name.compareTo(b.name);
        });

    return AccountComputed(
      projects: items,
      totalReceivable: summary.receivable,
      totalReceived: summary.received,
      totalWriteOff: summary.writeOff,
      totalRemaining: summary.remaining,
      totalRatio: summary.cashRate,
      settlementRate: summary.settlementRate,
      deviceReceivables: deviceReceivables,
    );
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

  Map<int, double> _calcNetReceivableByDevice({
    required List<TimingRecord> timingRecords,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required List<ProjectWriteOff> writeOffs,
    required GregorianYearRange summaryRange,
  }) {
    final projects = AccountService.buildProjects(timingRecords: timingRecords);
    if (projects.isEmpty) return const {};

    final projectIds = projects.keys.toSet();
    final writeOffFenByProject = <String, int>{};
    for (final writeOff in writeOffs) {
      final projectId = writeOff.projectId.trim();
      if (!summaryRange.containsDateText(writeOff.writeOffDate) ||
          !projectIds.contains(projectId)) {
        continue;
      }
      writeOffFenByProject[projectId] =
          (writeOffFenByProject[projectId] ?? 0) +
          ProjectFinanceCalculator.yuanToFen(writeOff.amount);
    }

    final rentFenByProjectDevice = <String, Map<int, int>>{};
    for (final record in timingRecords) {
      if (record.type != TimingType.rent || record.income <= 0) continue;
      final byDevice = rentFenByProjectDevice.putIfAbsent(
        record.effectiveProjectId,
        () => <int, int>{},
      );
      byDevice[record.deviceId] =
          (byDevice[record.deviceId] ?? 0) +
          ProjectFinanceCalculator.yuanToFen(record.income);
    }

    final totalsFen = <int, int>{};
    for (final agg in projects.values) {
      final grossByDevice = _projectReceivableFenByDevice(
        agg: agg,
        devices: devices,
        rates: rates,
      );
      final rentByDevice = rentFenByProjectDevice[agg.projectId];
      if (rentByDevice != null) {
        for (final entry in rentByDevice.entries) {
          grossByDevice[entry.key] =
              (grossByDevice[entry.key] ?? 0) + entry.value;
        }
      }

      final netByDevice = _deductWriteOffFenByDevice(
        grossByDevice,
        writeOffFenByProject[agg.projectId] ?? 0,
      );
      for (final entry in netByDevice.entries) {
        if (entry.value <= 0) continue;
        totalsFen[entry.key] = (totalsFen[entry.key] ?? 0) + entry.value;
      }
    }

    return {
      for (final entry in totalsFen.entries)
        entry.key: ProjectFinanceCalculator.fenToYuan(entry.value),
    };
  }

  Map<int, int> _projectReceivableFenByDevice({
    required ProjectAgg agg,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
  }) {
    final totals = <int, int>{};
    final effectiveRate = AccountService.buildEffectiveRateMap(
      projectKey: agg.projectKey,
      projectId: agg.projectId,
      devices: devices,
      rates: rates,
      isBreaking: false,
    );
    final effectiveBreakingRate = AccountService.buildEffectiveRateMap(
      projectKey: agg.projectKey,
      projectId: agg.projectId,
      devices: devices,
      rates: rates,
      isBreaking: true,
    );

    for (final entry in agg.normalHoursByDevice.entries) {
      final amountFen = _hoursAmountFen(
        hours: entry.value,
        rate: effectiveRate[entry.key] ?? 0,
      );
      if (amountFen <= 0) continue;
      totals[entry.key] = (totals[entry.key] ?? 0) + amountFen;
    }
    for (final entry in agg.breakingHoursByDevice.entries) {
      final amountFen = _hoursAmountFen(
        hours: entry.value,
        rate: effectiveBreakingRate[entry.key] ?? 0,
      );
      if (amountFen <= 0) continue;
      totals[entry.key] = (totals[entry.key] ?? 0) + amountFen;
    }
    return totals;
  }

  int _hoursAmountFen({required double hours, required double rate}) {
    if (hours <= 0 || rate <= 0) return 0;
    return ProjectFinanceCalculator.calculateWorkAmountFen(
      hoursMilli: ProjectFinanceCalculator.hoursToMilli(hours),
      unitPriceFenPerHour: ProjectFinanceCalculator.yuanPerHourToFen(rate),
    );
  }

  Map<int, int> _deductWriteOffFenByDevice(
    Map<int, int> grossByDevice,
    int writeOffFen,
  ) {
    if (writeOffFen <= 0 || grossByDevice.isEmpty) {
      return Map<int, int>.from(grossByDevice);
    }

    final entries =
        grossByDevice.entries.where((entry) => entry.value > 0).toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) return const {};

    final grossFen = entries.fold<int>(0, (sum, entry) => sum + entry.value);
    final cappedWriteOffFen = writeOffFen > grossFen ? grossFen : writeOffFen;
    var remainingWriteOff = cappedWriteOffFen;
    final net = <int, int>{};

    for (var index = 0; index < entries.length; index += 1) {
      final entry = entries[index];
      final isLast = index == entries.length - 1;
      var share = isLast
          ? remainingWriteOff
          : ((entry.value * cappedWriteOffFen) / grossFen).round();
      if (share < 0) share = 0;
      if (share > remainingWriteOff) share = remainingWriteOff;
      remainingWriteOff -= share;
      final amount = entry.value - share;
      if (amount > 0) net[entry.key] = amount;
    }
    return net;
  }

  _AnnualSummary _buildAnnualSummary({
    required List<TimingRecord> timingRecords,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required List<AccountPayment> payments,
    required List<ProjectWriteOff> writeOffs,
    required GregorianYearRange summaryRange,
  }) {
    final projects = AccountService.buildProjects(timingRecords: timingRecords);
    if (projects.isEmpty) return const _AnnualSummary.empty();

    final projectIds = projects.keys.toSet();
    final annualPayments = payments.where((payment) {
      return summaryRange.containsYmd(payment.ymd) &&
          projectIds.contains(payment.effectiveProjectId);
    }).toList();
    final annualWriteOffs = writeOffs.where((writeOff) {
      return summaryRange.containsDateText(writeOff.writeOffDate) &&
          projectIds.contains(writeOff.projectId.trim());
    }).toList();

    var originalFen = 0;
    var receivedFen = 0;
    var writeOffFen = 0;
    for (final agg in projects.values) {
      final money = AccountService.calcMoney(
        agg: agg,
        devices: devices,
        rates: rates,
        payments: annualPayments,
        writeOffs: annualWriteOffs,
      );
      originalFen += ProjectFinanceCalculator.yuanToFen(money.receivable);
      receivedFen += ProjectFinanceCalculator.yuanToFen(money.received);
      writeOffFen += ProjectFinanceCalculator.yuanToFen(money.writeOff);
    }

    final receivableFen = originalFen > writeOffFen
        ? originalFen - writeOffFen
        : 0;
    final rawRemainingFen = receivableFen - receivedFen;
    final remainingFen = rawRemainingFen.abs() <= 1 ? 0 : rawRemainingFen;
    final cashRate = receivableFen <= 0 ? null : receivedFen / receivableFen;
    final settlementRate = originalFen <= 0
        ? null
        : (receivedFen + writeOffFen) / originalFen;

    return _AnnualSummary(
      receivable: ProjectFinanceCalculator.fenToYuan(receivableFen),
      received: ProjectFinanceCalculator.fenToYuan(receivedFen),
      writeOff: ProjectFinanceCalculator.fenToYuan(writeOffFen),
      remaining: ProjectFinanceCalculator.fenToYuan(remainingFen),
      cashRate: cashRate,
      settlementRate: settlementRate,
    );
  }

  List<AccountProjectVM> _applyMergeGroups({
    required List<AccountProjectVM> normalItems,
    required List<AccountProjectMergeGroupWithMembers> activeMergeGroups,
  }) {
    if (activeMergeGroups.isEmpty || normalItems.isEmpty) return normalItems;

    final normalByProjectId = {
      for (final item in normalItems) item.projectId: item,
    };
    final hiddenKeys = <String>{};
    final mergedItems = <AccountProjectVM>[];

    for (final groupWithMembers in activeMergeGroups) {
      final group = groupWithMembers.group;
      final groupId = group.id;
      if (groupId == null || !group.isActive) continue;

      final activeMembers =
          groupWithMembers.members.where((member) => member.isActive).toList()
            ..sort((a, b) {
              final byOrder = a.sortOrder.compareTo(b.sortOrder);
              if (byOrder != 0) return byOrder;
              return (a.id ?? 0).compareTo(b.id ?? 0);
            });

      final memberItems = <AccountProjectVM>[];
      final memberSites = <String>[];
      final memberKeys = <String>[];
      final memberProjectIds = <String>[];
      for (final member in activeMembers) {
        final item = normalByProjectId[member.effectiveProjectId];
        if (item == null) continue;
        memberItems.add(item);
        memberSites.add(member.site);
        memberKeys.add(member.projectKey);
        memberProjectIds.add(member.effectiveProjectId);
      }

      if (memberItems.length < 2) continue;
      hiddenKeys.addAll(memberProjectIds);
      mergedItems.add(
        _buildMergedProjectVM(
          groupId: groupId,
          contact: group.contact,
          memberItems: memberItems,
          memberProjectKeys: memberKeys,
          memberProjectIds: memberProjectIds,
          includedSites: memberSites,
        ),
      );
    }

    if (mergedItems.isEmpty) return normalItems;

    final visibleNormalItems = normalItems.where((item) {
      return !hiddenKeys.contains(item.projectId);
    });

    return [...visibleNormalItems, ...mergedItems]
      ..sort((a, b) => b.minYmd.compareTo(a.minYmd));
  }

  AccountProjectVM _buildMergedProjectVM({
    required int groupId,
    required String contact,
    required List<AccountProjectVM> memberItems,
    required List<String> memberProjectKeys,
    required List<String> memberProjectIds,
    required List<String> includedSites,
  }) {
    final deviceIds = <int>{};
    final hoursByDevice = <int, double>{};
    final payments = <AccountPayment>[];

    var minYmd = 99991231;
    var rentIncomeTotal = 0.0;
    double? minRate;
    var isMultiMode = false;
    var receivable = 0.0;
    var received = 0.0;
    var writeOff = 0.0;

    for (final item in memberItems) {
      if (item.minYmd < minYmd) minYmd = item.minYmd;
      deviceIds.addAll(item.deviceIds);
      for (final entry in item.hoursByDevice.entries) {
        hoursByDevice[entry.key] =
            (hoursByDevice[entry.key] ?? 0) + entry.value;
      }
      rentIncomeTotal += item.rentIncomeTotal;
      final rate = item.minRate;
      if (rate != null) {
        minRate = minRate == null ? rate : (rate < minRate ? rate : minRate);
      }
      isMultiMode = isMultiMode || item.isMultiMode;
      receivable += item.receivable;
      received += item.received;
      writeOff += item.writeOff;
      payments.addAll(item.payments);
    }

    payments.sort((a, b) => b.ymd.compareTo(a.ymd));
    final finance = ProjectFinanceCalculator.summarizeTotals(
      receivableFen: ProjectFinanceCalculator.yuanToFen(receivable),
      receivedFen: ProjectFinanceCalculator.yuanToFen(received),
      writeOffFen: ProjectFinanceCalculator.yuanToFen(writeOff),
      toleranceFen: 1,
    );
    final sortedDeviceIds = deviceIds.toList()..sort();

    return AccountProjectVM(
      projectId: 'merge:$groupId',
      projectKey: 'merge:$groupId',
      displayName: '${contact.trim()} + 合并${memberItems.length}项目',
      kind: AccountProjectKind.merged,
      mergeGroupId: groupId,
      memberProjectKeys: List.unmodifiable(memberProjectKeys),
      memberProjectIds: List.unmodifiable(memberProjectIds),
      includedSites: List.unmodifiable(includedSites),
      includedSitesText: _includedSitesText(includedSites),
      minYmd: minYmd,
      deviceIds: sortedDeviceIds,
      hoursByDevice: Map.unmodifiable(hoursByDevice),
      rentIncomeTotal: rentIncomeTotal,
      minRate: minRate,
      isMultiDevice: sortedDeviceIds.length > 1,
      isMultiMode: isMultiMode,
      receivable: finance.receivable,
      received: finance.received,
      writeOff: finance.writeOff,
      remaining: finance.remaining,
      ratio: finance.cashRate,
      settlementRatio: finance.settlementRate,
      payments: payments,
    );
  }

  String _includedSitesText(List<String> sites) {
    final cleanSites = sites.map((site) => site.trim()).where((site) {
      return site.isNotEmpty;
    }).toList();
    if (cleanSites.length <= 2) {
      return '含：${cleanSites.join('、')}';
    }
    return '含：${cleanSites.take(2).join('、')}等${cleanSites.length}项';
  }
}

class _AnnualSummary {
  const _AnnualSummary({
    required this.receivable,
    required this.received,
    required this.writeOff,
    required this.remaining,
    required this.cashRate,
    required this.settlementRate,
  });

  const _AnnualSummary.empty()
    : receivable = 0,
      received = 0,
      writeOff = 0,
      remaining = 0,
      cashRate = null,
      settlementRate = null;

  final double receivable;
  final double received;
  final double writeOff;
  final double remaining;
  final double? cashRate;
  final double? settlementRate;
}
