import '../../../core/utils/store_feedback.dart';
import '../domain/services/external_work_receivable.dart';
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
    required this.localComputed,
    required this.computed,
    required this.externalReceivableRollup,
    required this.filteredProjects,
    required this.filteredExternalWorkProjects,
    required this.projectSuggestions,
    required this.netCashReceived,
    required this.loading,
    required this.hasActiveFilter,
    required this.error,
  });

  final AccountComputed localComputed;
  final AccountComputed computed;
  final ExternalWorkReceivableRollup externalReceivableRollup;
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
  final summaryYear = DateTime.now().year;

  final localComputed = accountStore.compute(
    timingRecords: timing,
    devices: devices,
    rates: rates,
    payments: payments,
    summaryYear: summaryYear,
  );
  final externalItems = externalWorkStore?.items ?? const [];
  // 外协联动口径：
  // - 本地项目卡、核销、设备/月度/图表统计继续使用 local-only metrics。
  // - 外协客户侧应收进入账户总览 combined totals。
  // - 外协应付仍作为成本在外协卡片独立展示，不能并入总应收或已收。
  final rollup = rollupExternalWorkReceivable(
    externalItems,
    summaryYear: summaryYear,
  );
  final computed = augmentComputedWithExternalWork(localComputed, rollup);
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
    localComputed: localComputed,
    computed: computed,
    externalReceivableRollup: rollup,
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

    var payableFen = 0;
    var receivableFen = 0;
    for (final item in batchItems) {
      final amounts = externalWorkRecordReceivableAmounts(item.record);
      payableFen += amounts.externalPayableFen;
      receivableFen += amounts.externalCustomerReceivableFen;
    }
    if (payableFen <= 0 && receivableFen <= 0) continue;

    // projectReceivedFen 是来源方累计实收口径，不计入我方已收（见 gate #4），
    // 故外协包“应收剩余” = 应收全额。
    final externalRemainingFen = receivableFen > 0 ? receivableFen : 0;
    final profitFen = receivableFen - payableFen;

    final externalPayableFen = batchItems.fold<int>(
      0,
      (sum, item) => sum + item.record.amountFen,
    );
    assert(externalPayableFen == payableFen);

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
        receivableFen: receivableFen,
        remainingFen: externalRemainingFen,
        profitFen: profitFen,
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

/// 给账户页计算结果附加外协展示信息，并生成总览 combined totals。
///
/// 本地项目卡片的应收/待收/比例仍保持 local-only；总览 totals 额外纳入
/// 外协客户侧应收（客户单价×工时，未设则回退到应付金额）。外协应付（付给
/// 协作方的款项）不并入总应收；外协已收恒 0（projectReceivedFen 是来源方口径，
/// 见 gate #4），故不动已收。
AccountComputed augmentComputedWithExternalWork(
  AccountComputed computed,
  ExternalWorkReceivableRollup rollup,
) {
  if (rollup.externalCustomerReceivableFen == 0 &&
      rollup.externalReceivedFen == 0 &&
      rollup.externalRemainingFen == 0 &&
      rollup.receivableFenByProjectId.isEmpty &&
      rollup.hoursByProjectId.isEmpty) {
    return computed;
  }

  final augmentedProjects = [
    for (final project in computed.projects)
      _augmentProjectWithExternalWork(project, rollup),
  ];

  return AccountComputed(
    projects: augmentedProjects,
    totalReceivable:
        computed.totalReceivable + rollup.externalCustomerReceivableFen / 100,
    totalReceived: computed.totalReceived + rollup.externalReceivedFen / 100,
    totalWriteOff: computed.totalWriteOff,
    totalRemaining: computed.totalRemaining + rollup.externalRemainingFen / 100,
    totalRatio: _combinedRatio(
      localReceivable: computed.totalReceivable,
      localReceived: computed.totalReceived,
      externalReceivableFen: rollup.externalCustomerReceivableFen,
      externalReceivedFen: rollup.externalReceivedFen,
    ),
    settlementRate: computed.settlementRate,
    deviceReceivables: computed.deviceReceivables,
    moneyFenByProjectId: computed.moneyFenByProjectId,
  );
}

double? _combinedRatio({
  required double localReceivable,
  required double localReceived,
  required int externalReceivableFen,
  required int externalReceivedFen,
}) {
  final combinedReceivable = localReceivable + externalReceivableFen / 100;
  if (combinedReceivable <= 0) return null;
  return (localReceived + externalReceivedFen / 100) / combinedReceivable;
}

/// 仅附加展示信息：外协工时 + 链条徽标。我方 receivable/remaining/ratio
/// 等财务数字保持原值（隔离红线，见 [augmentComputedWithExternalWork]）。
AccountProjectVM _augmentProjectWithExternalWork(
  AccountProjectVM project,
  ExternalWorkReceivableRollup rollup,
) {
  final ids = <String>{
    project.effectiveProjectId,
    ...project.memberProjectIds.map((id) => id.trim()),
  }..removeWhere((id) => id.isEmpty);

  var externalHours = 0.0;
  var hasLinked = false;
  for (final id in ids) {
    final fen = rollup.receivableFenByProjectId[id];
    final hours = rollup.hoursByProjectId[id];
    if (fen == null && hours == null) continue;
    hasLinked = true;
    externalHours += hours ?? 0;
  }
  if (!hasLinked) return project;

  return project.copyWith(
    externalWorkHours: project.externalWorkHours + externalHours,
    hasLinkedExternalWork: true,
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
