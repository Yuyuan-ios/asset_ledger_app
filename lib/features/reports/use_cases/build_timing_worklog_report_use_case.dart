import '../../../core/measure/measure_unit.dart';
import '../../../core/measure/quantity.dart';
import '../../../core/money/amount_policy.dart';
import '../../../data/models/device.dart';
import '../../../data/models/external_work_record.dart';
import '../../../data/models/project_device_rate.dart';
import '../../../data/models/timing_record.dart';
import '../../../data/services/account_service.dart';
import '../../timing/state/timing_external_work_store.dart';
import '../models/timing_worklog_report.dart';

class BuildTimingWorklogReportUseCase {
  const BuildTimingWorklogReportUseCase();

  static const String title = '项目对账明细';

  TimingWorklogReport execute({
    required List<TimingRecord> records,
    required List<Device> devices,
    List<ProjectDeviceRate> rates = const [],
    List<TimingExternalWorkRecordItem> externalWorkItems = const [],
  }) {
    final deviceById = <int, Device>{
      for (final device in devices)
        if (device.id != null) device.id!: device,
    };
    final sourceRows = <_TimingWorklogSourceRow>[
      for (var i = 0; i < records.length; i += 1)
        _TimingWorklogSourceRow.local(
          record: records[i],
          device: deviceById[records[i].deviceId],
          devices: devices,
          rates: rates,
          sourceIndex: i,
        ),
      for (var i = 0; i < externalWorkItems.length; i += 1)
        _TimingWorklogSourceRow.external(
          item: externalWorkItems[i],
          sourceIndex: records.length + i,
        ),
    ]..sort(_compareSourceRows);

    final rows = <TimingWorklogReportRow>[];
    for (var i = 0; i < sourceRows.length; i += 1) {
      rows.add(sourceRows[i].toReportRow(i + 1));
    }

    final totalHours = rows.fold<double>(0, (sum, row) => sum + row.hours);
    final totalAmountFen = rows.fold<int>(0, (sum, row) => sum + row.amountFen);
    return TimingWorklogReport(
      title: title,
      rows: rows,
      totalHours: totalHours,
      totalAmountFen: totalAmountFen,
      unitTotals: _unitTotals(rows),
      deviceFileNamePart: _deviceFileNamePart(rows),
      startDate: rows.isEmpty ? 0 : rows.first.date,
      endDate: rows.isEmpty ? 0 : rows.last.date,
    );
  }

  static String _deviceDisplayName(int deviceId, Device? device) {
    final brand = device?.brand.trim() ?? '';
    final model = device?.model?.trim() ?? '';
    if (brand.isNotEmpty || model.isNotEmpty) return '$brand$model';
    final name = device?.name.trim() ?? '';
    if (name.isNotEmpty) return name;
    return '设备$deviceId';
  }

  static String _externalDeviceDisplayName(ExternalWorkRecord record) {
    final brand = record.equipmentBrand?.trim() ?? '';
    final model = record.equipmentModel?.trim() ?? '';
    if (brand.isNotEmpty || model.isNotEmpty) return '$brand$model';
    final type = record.equipmentType?.trim() ?? '';
    if (type.isNotEmpty) return type;
    return '设备未填写';
  }

  static String _projectName(TimingRecord record) {
    final contact = record.contact.trim();
    final site = record.site.trim();
    if (contact.isEmpty) return site;
    if (site.isEmpty) return contact;
    return '$contact · $site';
  }

  static String _deviceFileNamePart(List<TimingWorklogReportRow> rows) {
    final names = rows.map((row) => row.deviceName.trim()).toSet();
    if (names.isEmpty) return '无设备';
    if (names.length == 1) return _sanitizeFileNamePart(names.single);
    return '多设备';
  }

  static String _sanitizeFileNamePart(String raw) {
    final cleaned = raw
        .replaceAll('号', '')
        .replaceAll('#', '号')
        .replaceAll(RegExp(r'''[\\/:*?"<>|\x00-\x1F]'''), '_')
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? '未知设备' : cleaned;
  }

  static List<TimingWorklogUnitTotal> _unitTotals(
    List<TimingWorklogReportRow> rows,
  ) {
    final totals = <MeasureUnit, int>{};
    for (final row in rows) {
      final quantityScaled = row.quantityScaled;
      if (quantityScaled == null || quantityScaled <= 0) continue;
      totals[row.unit] = (totals[row.unit] ?? 0) + quantityScaled;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));
    return [
      for (final entry in entries)
        TimingWorklogUnitTotal(unit: entry.key, quantityScaled: entry.value),
    ];
  }
}

int _compareSourceRows(_TimingWorklogSourceRow a, _TimingWorklogSourceRow b) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) return byDate;

  if (a.sourceType == b.sourceType) {
    switch (a.sourceType) {
      case TimingWorklogReportSourceType.local:
        final byId = a.localRecordId.compareTo(b.localRecordId);
        if (byId != 0) return byId;
      case TimingWorklogReportSourceType.external:
        final byCreated = a.externalCreatedAt.compareTo(b.externalCreatedAt);
        if (byCreated != 0) return byCreated;
        final byExternalId = a.externalRecordId.compareTo(b.externalRecordId);
        if (byExternalId != 0) return byExternalId;
    }
  }

  final byType = a.sourceType.index.compareTo(b.sourceType.index);
  if (byType != 0) return byType;
  return a.sourceIndex.compareTo(b.sourceIndex);
}

class _TimingWorklogSourceRow {
  const _TimingWorklogSourceRow._({
    required this.sourceType,
    required this.date,
    required this.deviceName,
    required this.contactName,
    required this.siteName,
    required this.projectName,
    required this.workContent,
    this.startMeter,
    this.endMeter,
    required this.unit,
    required this.quantityScaled,
    required this.unitPriceFen,
    required this.amountFen,
    required this.sourceIndex,
    this.localRecordId = 0,
    this.externalCreatedAt = '',
    this.externalRecordId = '',
  });

  factory _TimingWorklogSourceRow.local({
    required TimingRecord record,
    required Device? device,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required int sourceIndex,
  }) {
    final rateFen = _unitPriceFenFor(
      record: record,
      devices: devices,
      rates: rates,
    );
    final quantityScaled = record.quantityScaled;
    final amountFen = quantityScaled == null
        ? record.incomeFen
        : AmountPolicy.calculateAmountForQuantity(
            quantity: Quantity(quantityScaled),
            unitPrice: UnitPrice(rateFen),
          ).fen;
    return _TimingWorklogSourceRow._(
      sourceType: TimingWorklogReportSourceType.local,
      date: record.startDate,
      deviceName: BuildTimingWorklogReportUseCase._deviceDisplayName(
        record.deviceId,
        device,
      ),
      contactName: record.contact.trim(),
      siteName: record.site.trim(),
      projectName: BuildTimingWorklogReportUseCase._projectName(record),
      workContent: '',
      startMeter: record.unit == MeasureUnit.hour ? record.startMeter : null,
      endMeter: record.unit == MeasureUnit.hour ? record.endMeter : null,
      unit: record.unit,
      quantityScaled: quantityScaled,
      unitPriceFen: quantityScaled == null ? null : rateFen,
      amountFen: amountFen,
      localRecordId: record.id ?? 0,
      sourceIndex: sourceIndex,
    );
  }

  factory _TimingWorklogSourceRow.external({
    required TimingExternalWorkRecordItem item,
    required int sourceIndex,
  }) {
    final record = item.record;
    final quantityScaled = record.hoursMilli;
    return _TimingWorklogSourceRow._(
      sourceType: TimingWorklogReportSourceType.external,
      date: record.workDate,
      deviceName: BuildTimingWorklogReportUseCase._externalDeviceDisplayName(
        record,
      ),
      contactName: record.contactSnapshot.trim(),
      siteName: record.siteSnapshot.trim(),
      projectName: record.siteSnapshot.trim(),
      workContent: '',
      unit: MeasureUnit.hour,
      quantityScaled: quantityScaled,
      unitPriceFen: quantityScaled <= 0
          ? null
          : ((record.amountFen * 1000) / quantityScaled).round(),
      amountFen: record.amountFen,
      externalCreatedAt: record.createdAt,
      externalRecordId: record.id,
      sourceIndex: sourceIndex,
    );
  }

  final TimingWorklogReportSourceType sourceType;
  final int date;
  final String deviceName;
  final String contactName;
  final String siteName;
  final String projectName;
  final String workContent;
  final double? startMeter;
  final double? endMeter;
  final MeasureUnit unit;
  final int? quantityScaled;
  final int? unitPriceFen;
  final int amountFen;
  final int localRecordId;
  final String externalCreatedAt;
  final String externalRecordId;
  final int sourceIndex;

  TimingWorklogReportRow toReportRow(int sequence) {
    return TimingWorklogReportRow(
      sequence: sequence,
      date: date,
      deviceName: deviceName,
      contactName: contactName,
      siteName: siteName,
      projectName: projectName,
      workContent: workContent,
      startMeter: startMeter,
      endMeter: endMeter,
      unit: unit,
      quantityScaled: quantityScaled,
      unitPriceFen: unitPriceFen,
      amountFen: amountFen,
      sourceType: sourceType,
    );
  }

  static int _unitPriceFenFor({
    required TimingRecord record,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
  }) {
    final effectiveRateFen = AccountService.buildEffectiveRateFenMap(
      projectKey: record.legacyProjectKey,
      projectId: record.effectiveProjectId,
      devices: devices,
      rates: rates,
      isBreaking: record.isBreaking,
    );
    return effectiveRateFen[record.deviceId] ?? 0;
  }
}
