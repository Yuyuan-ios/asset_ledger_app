import '../../../data/models/account_payment.dart';
import '../../../data/models/device.dart';
import '../../../data/models/account_project_merge_group_with_members.dart';
import '../../../data/models/project_device_rate.dart';
import '../../../data/models/timing_record.dart';
import '../../../data/services/account_service.dart';
import '../../../core/utils/device_maps.dart';
import '../model/account_view_model.dart';

class ComputeAccountSummaryUseCase {
  const ComputeAccountSummaryUseCase();

  AccountComputed execute({
    required List<TimingRecord> timingRecords,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required List<AccountPayment> payments,
    List<AccountProjectMergeGroupWithMembers> activeMergeGroups = const [],
  }) {
    final projects = AccountService.buildProjects(timingRecords: timingRecords);
    final receivableByDevice = AccountService.calcReceivableByDevice(
      timingRecords: timingRecords,
      devices: devices,
      rates: rates,
    );

    final keys = projects.keys.toList()
      ..sort((a, b) => projects[b]!.minYmd.compareTo(projects[a]!.minYmd));

    final normalItems = <AccountProjectVM>[];
    double totalReceivable = 0.0;
    double totalReceived = 0.0;

    for (final key in keys) {
      final agg = projects[key]!;

      final money = AccountService.calcMoney(
        agg: agg,
        devices: devices,
        rates: rates,
        payments: payments,
      );

      totalReceivable += money.receivable;
      totalReceived += money.received;

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
          receivable: money.receivable,
          received: money.received,
          remaining: money.remaining,
          ratio: money.ratio,
          payments: payments.where((payment) {
            return payment.effectiveProjectId == agg.projectId;
          }).toList()..sort((a, b) => b.ymd.compareTo(a.ymd)),
        ),
      );
    }

    final remaining = totalReceivable - totalReceived;
    final ratio = (totalReceivable <= 0.0000001)
        ? null
        : (totalReceived / totalReceivable);

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
      totalReceivable: totalReceivable,
      totalReceived: totalReceived,
      totalRemaining: remaining,
      totalRatio: ratio,
      deviceReceivables: deviceReceivables,
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
      payments.addAll(item.payments);
    }

    payments.sort((a, b) => b.ymd.compareTo(a.ymd));
    final remaining = receivable - received;
    final ratio = receivable <= 0.0000001 ? null : received / receivable;
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
      receivable: receivable,
      received: received,
      remaining: remaining,
      ratio: ratio,
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
