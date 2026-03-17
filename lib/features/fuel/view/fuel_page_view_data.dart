import '../../../core/utils/device_label.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/store_feedback.dart';
import '../../../data/models/fuel_log.dart';
import '../../../data/services/fuel_stats_service.dart';
import '../../device/state/device_store.dart';
import '../../fuel/model/fuel_efficiency_agg.dart';
import '../../fuel/state/fuel_store.dart';
import '../../timing/state/timing_store.dart';

/// Fuel 页面 build 期衍生输入，避免在 Widget 树里混入过多计算。
class FuelPageViewData {
  const FuelPageViewData({
    required this.loading,
    required this.error,
    required this.yearSummary,
    required this.yearSummaryTitle,
    required this.byDevice,
    required this.filteredLogs,
    required this.deviceIndexById,
  });

  final bool loading;
  final String? error;
  final FuelYearSummary yearSummary;
  final String yearSummaryTitle;
  final Map<int, FuelEfficiencyAgg> byDevice;
  final List<FuelLog> filteredLogs;
  final Map<int, String> deviceIndexById;
}

FuelPageViewData buildFuelPageViewData({
  required FuelStore fuelStore,
  required DeviceStore deviceStore,
  required TimingStore timingStore,
  required String supplierFilter,
}) {
  final loading =
      fuelStore.loading || deviceStore.loading || timingStore.loading;
  final error = firstStoreErrorMessage([
    fuelStore,
    deviceStore,
    timingStore,
  ], action: '读取');

  final normalizedSupplierFilter = supplierFilter.trim();
  final nowYmd = FormatUtils.ymdFromDate(DateTime.now());
  final supplier = normalizedSupplierFilter.isEmpty
      ? null
      : normalizedSupplierFilter;
  final yearSummary = fuelStore.currentYearSummary(
    nowYmd: nowYmd,
    supplier: supplier,
  );
  final yearSummaryTitle = supplier == null ? '本年度总消耗' : '本年度（$supplier）';

  final byDevice = fuelStore.efficiencyByDeviceAllTime(timingStore.records);
  final filteredLogs = normalizedSupplierFilter.isEmpty
      ? fuelStore.logs
      : fuelStore.logs
            .where((e) => e.supplier.contains(normalizedSupplierFilter))
            .toList();
  final deviceIndexById = DeviceLabel.indexMapById(deviceStore.allDevices);

  return FuelPageViewData(
    loading: loading,
    error: error,
    yearSummary: yearSummary,
    yearSummaryTitle: yearSummaryTitle,
    byDevice: byDevice,
    filteredLogs: filteredLogs,
    deviceIndexById: deviceIndexById,
  );
}
