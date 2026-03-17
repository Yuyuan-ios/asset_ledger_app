import '../../../core/utils/format_utils.dart';
import '../../../core/utils/store_feedback.dart';
import '../../../data/models/maintenance_record.dart';
import '../../device/state/device_store.dart';
import '../state/maintenance_store.dart';

class MaintenanceDeviceSummaryVM {
  const MaintenanceDeviceSummaryVM({
    required this.deviceId,
    required this.deviceName,
    required this.amount,
  });

  final int deviceId;
  final String deviceName;
  final double amount;
}

class MaintenanceSummaryViewData {
  const MaintenanceSummaryViewData({
    required this.hasData,
    required this.deviceSummaries,
    required this.publicTotal,
    required this.allTotal,
  });

  final bool hasData;
  final List<MaintenanceDeviceSummaryVM> deviceSummaries;
  final double publicTotal;
  final double allTotal;
}

class MaintenanceRecordRowVM {
  const MaintenanceRecordRowVM({
    required this.record,
    required this.title,
    required this.subtitle,
    required this.dateText,
    required this.amountText,
  });

  final MaintenanceRecord record;
  final String title;
  final String subtitle;
  final String dateText;
  final String amountText;
}

class MaintenancePageViewData {
  const MaintenancePageViewData({
    required this.loading,
    required this.error,
    required this.recordsCount,
    required this.isEmpty,
    required this.summary,
    required this.rows,
  });

  final bool loading;
  final String? error;
  final int recordsCount;
  final bool isEmpty;
  final MaintenanceSummaryViewData summary;
  final List<MaintenanceRecordRowVM> rows;
}

MaintenancePageViewData buildMaintenancePageViewData({
  required MaintenanceStore maintenanceStore,
  required DeviceStore deviceStore,
}) {
  final loading = maintenanceStore.loading || deviceStore.loading;
  final error = firstStoreErrorMessage([
    maintenanceStore,
    deviceStore,
  ], action: '读取');

  final nowYmd = FormatUtils.ymdFromDate(DateTime.now());
  final summaryMap = maintenanceStore.currentYearSummary(nowYmd: nowYmd);

  final publicTotal = summaryMap[null] ?? 0.0;
  final deviceIds = summaryMap.keys.whereType<int>().toList()..sort();
  final deviceSummaries = deviceIds
      .map(
        (id) => MaintenanceDeviceSummaryVM(
          deviceId: id,
          deviceName: deviceStore.tryFindById(id)?.name ?? '设备$id（已停用/不存在）',
          amount: summaryMap[id] ?? 0.0,
        ),
      )
      .toList();
  var allTotal = publicTotal;
  for (final summary in deviceSummaries) {
    allTotal += summary.amount;
  }

  final summary = MaintenanceSummaryViewData(
    hasData: summaryMap.isNotEmpty,
    deviceSummaries: deviceSummaries,
    publicTotal: publicTotal,
    allTotal: allTotal,
  );

  final rows = maintenanceStore.records.map((record) {
    final title = record.deviceId == null
        ? '公共支出'
        : (deviceStore.tryFindById(record.deviceId!)?.name ??
              '设备#${record.deviceId}（已停用/不存在）');
    final note = record.note?.trim();
    final subtitle = (note == null || note.isEmpty)
        ? record.item
        : '${record.item} · $note';
    return MaintenanceRecordRowVM(
      record: record,
      title: title,
      subtitle: subtitle,
      dateText: FormatUtils.date(record.ymd),
      amountText: FormatUtils.money(record.amount),
    );
  }).toList();

  return MaintenancePageViewData(
    loading: loading,
    error: error,
    recordsCount: rows.length,
    isEmpty: rows.isEmpty,
    summary: summary,
    rows: rows,
  );
}
