import '../../../core/utils/store_feedback.dart';
import '../domain/services/external_work_receivable.dart';
import '../domain/services/project_finance_calculator.dart';
import '../model/account_view_model.dart';
import '../model/project_title_formatter.dart';
import '../state/account_filter_store.dart';
import '../state/account_payment_store.dart';
import '../state/account_store.dart';
import '../state/project_rate_store.dart';
import '../../device/state/device_store.dart';
import '../../fuel/state/fuel_store.dart';
import '../../maintenance/state/maintenance_store.dart';
import '../../timing/state/timing_external_work_store.dart';
import '../../timing/state/timing_store.dart';

/// 账户页构建期所需的衍生数据。
///
/// 说明：
/// - 仅承载页面渲染输入，不持有交互逻辑。
/// - 计算口径与旧 `AccountPage.build` 保持一致。
class AccountPageViewData {
  const AccountPageViewData({
    required this.computed,
    required this.filteredProjects,
    required this.filteredExternalWorkProjects,
    required this.projectSuggestions,
    required this.netCashReceived,
    required this.loading,
    required this.hasActiveFilter,
    required this.error,
  });

  final AccountComputed computed;
  final List<AccountProjectVM> filteredProjects;
  final List<AccountExternalWorkProjectVM> filteredExternalWorkProjects;
  final List<String> projectSuggestions;
  final double netCashReceived;
  final bool loading;
  final bool hasActiveFilter;
  final String? error;
}

AccountPageViewData buildAccountPageViewData({
  required TimingStore timingStore,
  required DeviceStore deviceStore,
  required AccountPaymentStore paymentStore,
  required ProjectRateStore rateStore,
  required AccountStore accountStore,
  required AccountFilterStore filterStore,
  required TimingExternalWorkStore? externalWorkStore,
  FuelStore? fuelStore,
  MaintenanceStore? maintenanceStore,
}) {
  final timing = timingStore.records;
  final devices = deviceStore.allDevices;
  final payments = paymentStore.records;
  final rates = rateStore.rates;

  final rawComputed = accountStore.compute(
    timingRecords: timing,
    devices: devices,
    rates: rates,
    payments: payments,
    summaryYear: DateTime.now().year,
  );
  final externalItems = externalWorkStore?.items ?? const [];
  // 外协设备应收联动：把已关联外协包的设备应收并入对应本地项目卡片，并把
  // 全部外协设备应收（每包只计一次）并入账户页总览总应收；同时把分享包
  // 携带的来源项目累计实收款计入总览已收。
  final rollup = rollupExternalWorkReceivable(externalItems);
  final computed = augmentComputedWithExternalWork(rawComputed, rollup);
  final now = DateTime.now();
  final nowYmd = now.year * 10000 + now.month * 100 + now.day;
  final fuelExpense = fuelStore?.currentYearSummary(nowYmd: nowYmd).cost ?? 0;
  final maintenanceExpense =
      maintenanceStore?.currentYearTotal(nowYmd: nowYmd) ?? 0;
  final netCashReceived = calculateNetCashReceived(
    receivedCash: computed.totalReceived,
    fuelExpense: fuelExpense,
    maintenanceExpense: maintenanceExpense,
    paidExternalWorkFen: rollup.totalPaidExternalWorkFen,
  );
  final filteredProjects = filterStore.filterProjects(computed.projects);
  final externalWorkProjects = buildAccountExternalWorkProjects(externalItems);
  final filteredExternalWorkProjects = _filterExternalWorkProjects(
    externalWorkProjects,
    filterStore.projectFilterKeyword,
  );
  final projectSuggestions = {
    ...timing.map((t) => t.contact.trim()).where((c) => c.isNotEmpty),
    ...externalWorkProjects
        .map((project) => project.sourceDisplayName.trim())
        .where((name) => name.isNotEmpty),
  }.toList()..sort();
  final loading =
      timingStore.loading ||
      deviceStore.loading ||
      paymentStore.loading ||
      rateStore.loading ||
      accountStore.loading ||
      (fuelStore?.loading ?? false) ||
      (maintenanceStore?.loading ?? false) ||
      (externalWorkStore?.loading ?? false);
  final hasActiveFilter =
      filterStore.projectFilterKeyword.isNotEmpty &&
      (filteredProjects.length + filteredExternalWorkProjects.length) <
          (computed.projects.length + externalWorkProjects.length);
  final error = firstStoreErrorMessage([
    timingStore,
    deviceStore,
    paymentStore,
    rateStore,
    accountStore,
    ?fuelStore,
    ?maintenanceStore,
    ?externalWorkStore,
  ], action: '读取');

  return AccountPageViewData(
    computed: computed,
    filteredProjects: filteredProjects,
    filteredExternalWorkProjects: filteredExternalWorkProjects,
    projectSuggestions: projectSuggestions,
    netCashReceived: netCashReceived,
    loading: loading,
    hasActiveFilter: hasActiveFilter,
    error: error,
  );
}

double calculateNetCashReceived({
  required double receivedCash,
  required double fuelExpense,
  required double maintenanceExpense,
  required int paidExternalWorkFen,
}) {
  return receivedCash -
      fuelExpense -
      maintenanceExpense -
      (paidExternalWorkFen / 100);
}

List<AccountExternalWorkProjectVM> buildAccountExternalWorkProjects(
  List<TimingExternalWorkRecordItem> items,
) {
  final batchOrder = <String>[];
  final byBatch = <String, List<TimingExternalWorkRecordItem>>{};

  for (final item in items) {
    final record = item.record;
    if (record.status.name != 'active') continue;
    if (item.batch?.status.name != 'active') continue;

    final batchId = record.importBatchId.trim();
    if (batchId.isEmpty) continue;
    final bucket = byBatch.putIfAbsent(batchId, () {
      batchOrder.add(batchId);
      return <TimingExternalWorkRecordItem>[];
    });
    bucket.add(item);
  }

  final projects = <AccountExternalWorkProjectVM>[];
  for (final batchId in batchOrder) {
    final batchItems = byBatch[batchId]!;
    // 已关联外协包仍显示在"外协的项目"列表（头像带链条角标），方便支付管理。
    final linkedProjectId = batchItems
        .map((item) => item.record.linkedProjectId?.trim() ?? '')
        .firstWhere((id) => id.isNotEmpty, orElse: () => '');
    final linked = linkedProjectId.isNotEmpty;

    final payableFen = batchItems.fold<int>(
      0,
      (sum, item) => sum + item.record.amountFen,
    );
    if (payableFen <= 0) continue;

    final first = batchItems.first;
    final batch = first.batch;
    final sourceDisplayName = _firstNonEmpty([
      batch?.sourceDisplayName,
      first.record.collaboratorName,
      '外协分享记录',
    ]);
    final siteSummary = _siteSummary(batchItems, batch?.siteSummary);

    projects.add(
      AccountExternalWorkProjectVM(
        importBatchId: batchId,
        displayName: _externalWorkDisplayName(sourceDisplayName, siteSummary),
        sourceDisplayName: sourceDisplayName,
        siteSummary: siteSummary,
        minYmd: _minWorkDate(batchItems),
        payableFen: payableFen,
        recordCount: batchItems.length,
        linked: linked,
        linkedProjectId: linked ? linkedProjectId : null,
      ),
    );
  }

  projects.sort((a, b) {
    final byDate = b.minYmd.compareTo(a.minYmd);
    if (byDate != 0) return byDate;
    return a.displayName.compareTo(b.displayName);
  });
  return projects;
}

/// 外协设备应收汇总（账户页联动用）。
class ExternalWorkReceivableRollup {
  const ExternalWorkReceivableRollup({
    required this.totalReceivableFen,
    required this.totalReceivedFen,
    required this.totalPaidExternalWorkFen,
    required this.receivableFenByProjectId,
    required this.hoursByProjectId,
  });

  const ExternalWorkReceivableRollup.empty()
    : totalReceivableFen = 0,
      totalReceivedFen = 0,
      totalPaidExternalWorkFen = 0,
      receivableFenByProjectId = const {},
      hoursByProjectId = const {};

  /// 所有活跃外协包的设备应收之和（每个 importBatch 只计一次），用于总览。
  final int totalReceivableFen;

  /// 所有活跃外协包携带的来源项目累计实收款之和（每个 importBatch 只计一次），用于总览。
  final int totalReceivedFen;

  /// 已支付外协项目款。当前没有持久化数据源，保持 0，不能用应付金额冒充。
  final int totalPaidExternalWorkFen;

  /// 已关联外协包按 linkedProjectId 汇总的设备应收（分），用于并入项目卡片。
  final Map<String, int> receivableFenByProjectId;

  /// 已关联外协包按 linkedProjectId 汇总的工时，用于项目卡片"总共"展示。
  final Map<String, double> hoursByProjectId;
}

/// 按 importBatch 汇总外协设备应收：总额（每包一次）+ 已关联项目维度分摊。
ExternalWorkReceivableRollup rollupExternalWorkReceivable(
  List<TimingExternalWorkRecordItem> items,
) {
  final byBatch = <String, List<TimingExternalWorkRecordItem>>{};
  for (final item in items) {
    if (item.record.status.name != 'active') continue;
    if (item.batch?.status.name != 'active') continue;
    final batchId = item.record.importBatchId.trim();
    if (batchId.isEmpty) continue;
    byBatch.putIfAbsent(batchId, () => []).add(item);
  }

  var totalFen = 0;
  var totalReceivedFen = 0;
  final byProject = <String, int>{};
  final byHoursProject = <String, double>{};
  for (final batchItems in byBatch.values) {
    final batchReceivableFen = batchItems.fold<int>(
      0,
      (sum, item) => sum + externalWorkRecordReceivableFen(item.record),
    );
    final batchReceivedFen = batchItems.fold<int>(0, (max, item) {
      final receivedFen = item.record.projectReceivedFen;
      return receivedFen > max ? receivedFen : max;
    });
    final batchHours = batchItems.fold<double>(
      0,
      (sum, item) => sum + item.record.hoursMilli / 1000,
    );
    totalFen += batchReceivableFen;
    totalReceivedFen += batchReceivedFen;

    final linkedProjectId = batchItems
        .map((item) => item.record.linkedProjectId?.trim() ?? '')
        .firstWhere((id) => id.isNotEmpty, orElse: () => '');
    if (linkedProjectId.isEmpty) continue;
    byProject[linkedProjectId] =
        (byProject[linkedProjectId] ?? 0) + batchReceivableFen;
    byHoursProject[linkedProjectId] =
        (byHoursProject[linkedProjectId] ?? 0) + batchHours;
  }

  return ExternalWorkReceivableRollup(
    totalReceivableFen: totalFen,
    totalReceivedFen: totalReceivedFen,
    totalPaidExternalWorkFen: 0,
    receivableFenByProjectId: Map.unmodifiable(byProject),
    hoursByProjectId: Map.unmodifiable(byHoursProject),
  );
}

/// 把外协设备应收并入账户页计算结果：
/// - 每个本地项目卡片总应收 += 其已关联外协包设备应收，并标记链条图标状态；
/// - 总览总应收 / 待收 += 全部外协设备应收（每包只计一次，不重复）。
AccountComputed augmentComputedWithExternalWork(
  AccountComputed computed,
  ExternalWorkReceivableRollup rollup,
) {
  if (rollup.totalReceivableFen == 0 &&
      rollup.totalReceivedFen == 0 &&
      rollup.receivableFenByProjectId.isEmpty &&
      rollup.hoursByProjectId.isEmpty) {
    return computed;
  }

  final augmentedProjects = [
    for (final project in computed.projects)
      _augmentProjectWithExternalWork(project, rollup),
  ];

  final externalTotalYuan = rollup.totalReceivableFen / 100;
  final externalReceivedYuan = rollup.totalReceivedFen / 100;
  final newTotalReceivable = computed.totalReceivable + externalTotalYuan;
  final newTotalReceived = computed.totalReceived + externalReceivedYuan;
  final newTotalRemaining =
      computed.totalRemaining + externalTotalYuan - externalReceivedYuan;
  final newTotalRatio = newTotalReceivable <= 0
      ? null
      : newTotalReceived / newTotalReceivable;

  return AccountComputed(
    projects: augmentedProjects,
    totalReceivable: newTotalReceivable,
    totalReceived: newTotalReceived,
    totalWriteOff: computed.totalWriteOff,
    totalRemaining: newTotalRemaining,
    totalRatio: newTotalRatio,
    settlementRate: computed.settlementRate,
    deviceReceivables: computed.deviceReceivables,
  );
}

AccountProjectVM _augmentProjectWithExternalWork(
  AccountProjectVM project,
  ExternalWorkReceivableRollup rollup,
) {
  final ids = <String>{
    project.effectiveProjectId,
    ...project.memberProjectIds.map((id) => id.trim()),
  }..removeWhere((id) => id.isEmpty);

  var externalFen = 0;
  var externalHours = 0.0;
  var hasLinked = false;
  for (final id in ids) {
    final fen = rollup.receivableFenByProjectId[id];
    final hours = rollup.hoursByProjectId[id];
    if (fen == null && hours == null) continue;
    hasLinked = true;
    externalFen += fen ?? 0;
    externalHours += hours ?? 0;
  }
  if (!hasLinked) return project;

  final externalYuan = externalFen / 100;
  final newReceivable = project.receivable + externalYuan;
  final finance = ProjectFinanceCalculator.summarizeTotals(
    receivableFen: ProjectFinanceCalculator.yuanToFen(newReceivable),
    receivedFen: ProjectFinanceCalculator.yuanToFen(project.received),
    writeOffFen: ProjectFinanceCalculator.yuanToFen(project.writeOff),
    toleranceFen: 1,
  );
  return project.copyWith(
    receivable: newReceivable,
    remaining: finance.remaining,
    externalWorkHours: project.externalWorkHours + externalHours,
    hasLinkedExternalWork: true,
    isSettledForDisplay: project.isSettled || finance.isSettled,
    ratio: finance.cashRate,
    settlementRatio: finance.settlementRate,
  );
}

List<AccountExternalWorkProjectVM> _filterExternalWorkProjects(
  List<AccountExternalWorkProjectVM> projects,
  String keyword,
) {
  final query = keyword.trim().toLowerCase();
  if (query.isEmpty) return projects;

  return projects
      .where((project) {
        return project.displayName.toLowerCase().contains(query) ||
            project.sourceDisplayName.toLowerCase().contains(query) ||
            project.siteSummary.toLowerCase().contains(query);
      })
      .toList(growable: false);
}

String _externalWorkDisplayName(String sourceDisplayName, String siteSummary) {
  return ProjectTitleFormatter.project(
    contact: sourceDisplayName,
    site: siteSummary,
  );
}

String _siteSummary(
  List<TimingExternalWorkRecordItem> items,
  String? batchSummary,
) {
  final batchSites = batchSummary?.trim();
  if (batchSites != null && batchSites.isNotEmpty) {
    return _displaySiteSummary(batchSites);
  }

  final sites = <String>[];
  final seen = <String>{};
  for (final item in items) {
    final site = item.record.siteSnapshot.trim();
    if (site.isEmpty || seen.contains(site)) continue;
    seen.add(site);
    sites.add(site);
  }
  return sites.join('、');
}

String _displaySiteSummary(String value) {
  return value.trim().replaceAll('+', '、').replaceAll('•', '、');
}

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) return normalized;
  }
  return '';
}

int _minWorkDate(List<TimingExternalWorkRecordItem> items) {
  return items.fold<int>(99991231, (minDate, item) {
    final date = item.record.workDate;
    return date < minDate ? date : minDate;
  });
}
