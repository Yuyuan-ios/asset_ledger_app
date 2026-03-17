import '../../../core/utils/store_feedback.dart';
import '../model/account_view_model.dart';
import '../state/account_filter_store.dart';
import '../state/account_payment_store.dart';
import '../state/account_store.dart';
import '../state/project_rate_store.dart';
import '../../device/state/device_store.dart';
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
    required this.projectSuggestions,
    required this.loading,
    required this.hasActiveFilter,
    required this.error,
  });

  final AccountComputed computed;
  final List<AccountProjectVM> filteredProjects;
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
  );
  final filteredProjects = filterStore.filterProjects(computed.projects);
  final projectSuggestions =
      timing
          .map((t) => t.contact.trim())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  final loading =
      timingStore.loading ||
      deviceStore.loading ||
      paymentStore.loading ||
      rateStore.loading;
  final hasActiveFilter =
      filterStore.projectFilterKeyword.isNotEmpty &&
      filteredProjects.length < computed.projects.length;
  final error = firstStoreErrorMessage([
    timingStore,
    deviceStore,
    paymentStore,
    rateStore,
  ], action: '读取');

  return AccountPageViewData(
    computed: computed,
    filteredProjects: filteredProjects,
    projectSuggestions: projectSuggestions,
    loading: loading,
    hasActiveFilter: hasActiveFilter,
    error: error,
  );
}
