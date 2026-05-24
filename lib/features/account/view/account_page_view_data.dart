import '../../../core/utils/store_feedback.dart';
import '../model/account_view_model.dart';
import '../state/account_filter_store.dart';
import '../state/account_payment_store.dart';
import '../state/account_store.dart';
import '../state/project_rate_store.dart';
import '../../device/state/device_store.dart';
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
    required this.loading,
    required this.hasActiveFilter,
    required this.error,
  });

  final AccountComputed computed;
  final List<AccountProjectVM> filteredProjects;
  final List<AccountExternalWorkProjectVM> filteredExternalWorkProjects;
  final List<String> projectSuggestions;
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
}) {
  final timing = timingStore.records;
  final devices = deviceStore.allDevices;
  final payments = paymentStore.records;
  final rates = rateStore.rates;

  final computed = accountStore.compute(
    timingRecords: timing,
    devices: devices,
    rates: rates,
    payments: payments,
    summaryYear: DateTime.now().year,
  );
  final filteredProjects = filterStore.filterProjects(computed.projects);
  final externalWorkProjects = buildAccountExternalWorkProjects(
    externalWorkStore?.items ?? const [],
  );
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
    ?externalWorkStore,
  ], action: '读取');

  return AccountPageViewData(
    computed: computed,
    filteredProjects: filteredProjects,
    filteredExternalWorkProjects: filteredExternalWorkProjects,
    projectSuggestions: projectSuggestions,
    loading: loading,
    hasActiveFilter: hasActiveFilter,
    error: error,
  );
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
    final hasLinkedRecord = batchItems.any((item) {
      return item.record.linkedProjectId?.trim().isNotEmpty == true;
    });
    if (hasLinkedRecord) continue;

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
  final source = sourceDisplayName.trim();
  final sites = siteSummary.trim();
  if (sites.isEmpty) return source;
  return '$source+$sites';
}

String _siteSummary(
  List<TimingExternalWorkRecordItem> items,
  String? batchSummary,
) {
  final batchSites = batchSummary?.trim();
  if (batchSites != null && batchSites.isNotEmpty) return batchSites;

  final sites = <String>[];
  final seen = <String>{};
  for (final item in items) {
    final site = item.record.siteSnapshot.trim();
    if (site.isEmpty || seen.contains(site)) continue;
    seen.add(site);
    sites.add(site);
  }
  return sites.join('+');
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
