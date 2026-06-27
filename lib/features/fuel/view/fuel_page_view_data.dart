import '../../../core/utils/format_utils.dart';
import '../../../core/utils/store_feedback.dart';
import '../../account/state/account_payment_store.dart';
import '../../account/state/account_store.dart';
import '../../account/state/project_rate_store.dart';
import '../../device/domain/services/device_business_ledger.dart';
import '../../device/domain/services/device_label.dart';
import '../../device/domain/services/lifecycle_payback_calculator.dart';
import '../domain/entities/fuel_entities.dart';
import '../domain/entities/fuel_summary.dart';
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
    required this.lifecyclePaybackByDeviceId,
    required this.filteredLogs,
    required this.deviceIndexById,
    required this.deviceDisplayNameById,
  });

  final bool loading;
  final StoreActionFeedback? error;
  final FuelYearSummary yearSummary;
  final String yearSummaryTitle;
  final Map<int, FuelEfficiencyAgg> byDevice;
  final Map<int, LifecyclePaybackResult> lifecyclePaybackByDeviceId;
  final List<FuelLog> filteredLogs;
  final Map<int, String> deviceIndexById;
  final Map<int, String> deviceDisplayNameById;
}

FuelPageViewData buildFuelPageViewData({
  required FuelStore fuelStore,
  required DeviceStore deviceStore,
  required TimingStore timingStore,
  required AccountPaymentStore paymentStore,
  required ProjectRateStore rateStore,
  required AccountStore accountStore,
  required String supplierFilter,
  required String inactiveDeviceIndexLabel,
  DeviceBusinessLedgerUseCase deviceBusinessLedgerUseCase =
      const DeviceBusinessLedgerUseCase(),
}) {
  final loading =
      fuelStore.loading ||
      deviceStore.loading ||
      timingStore.loading ||
      paymentStore.loading ||
      rateStore.loading ||
      accountStore.loading;
  final error = firstStoreActionFailure([
    fuelStore,
    deviceStore,
    timingStore,
    paymentStore,
    rateStore,
    accountStore,
  ], action: StoreActionKind.read);

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
  final businessLedgers = deviceBusinessLedgerUseCase.execute(
    timingRecords: timingStore.records,
    devices: deviceStore.allDevices,
    rates: rateStore.rates,
    payments: paymentStore.records,
    writeOffs: accountStore.writeOffs,
    activeMergeGroups: accountStore.activeMergeGroups,
    settledProjectIds: accountStore.settledProjectIds,
  );
  final devicesById = {
    for (final device in deviceStore.allDevices)
      if (device.id != null) device.id!: device,
  };
  final lifecyclePaybackByDeviceId = <int, LifecyclePaybackResult>{
    for (final ledger in businessLedgers)
      if ((devicesById[ledger.deviceId]?.lifecycleInitialCostFen ?? 0) > 0)
        ledger.deviceId: calculateLifecyclePayback(
          LifecyclePaybackInput(
            initialCostFen:
                devicesById[ledger.deviceId]?.lifecycleInitialCostFen,
            netReceivedFen: lifecyclePaybackNetReceivedFen(ledger),
            estimatedResidualFen:
                devicesById[ledger.deviceId]?.lifecycleEstimatedResidualFen,
          ),
        ),
  };
  final filteredLogs = normalizedSupplierFilter.isEmpty
      ? fuelStore.logs
      : fuelStore.logs
            .where((e) => e.supplier.contains(normalizedSupplierFilter))
            .toList();
  final deviceIndexById = DeviceLabel.indexMapById(
    deviceStore.allDevices,
    inactiveLabel: inactiveDeviceIndexLabel,
  );
  final deviceDisplayNameById = DeviceLabel.displayNameMapById(
    deviceStore.allDevices,
    inactiveLabel: inactiveDeviceIndexLabel,
  );

  return FuelPageViewData(
    loading: loading,
    error: error,
    yearSummary: yearSummary,
    yearSummaryTitle: yearSummaryTitle,
    byDevice: byDevice,
    lifecyclePaybackByDeviceId: lifecyclePaybackByDeviceId,
    filteredLogs: filteredLogs,
    deviceIndexById: deviceIndexById,
    deviceDisplayNameById: deviceDisplayNameById,
  );
}
