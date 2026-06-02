import '../../../data/models/device.dart';
import '../../../data/models/external_work_record.dart';
import '../../../data/models/timing_record.dart';
import '../../timing/state/timing_external_work_store.dart';
import '../models/timing_worklog_report.dart';

class BuildTimingWorklogReportUseCase {
  const BuildTimingWorklogReportUseCase();

  static const String title = '挖机工时打卡汇总';

  TimingWorklogReport execute({
    required List<TimingRecord> records,
    required List<Device> devices,
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
    return TimingWorklogReport(
      title: title,
      rows: rows,
      totalHours: totalHours,
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
    required this.hours,
    required this.sourceIndex,
    this.startMeter,
    this.endMeter,
    this.localRecordId = 0,
    this.externalCreatedAt = '',
    this.externalRecordId = '',
  });

  factory _TimingWorklogSourceRow.local({
    required TimingRecord record,
    required Device? device,
    required int sourceIndex,
  }) {
    return _TimingWorklogSourceRow._(
      sourceType: TimingWorklogReportSourceType.local,
      date: record.startDate,
      deviceName: BuildTimingWorklogReportUseCase._deviceDisplayName(
        record.deviceId,
        device,
      ),
      startMeter: record.startMeter,
      endMeter: record.endMeter,
      hours: record.hours,
      localRecordId: record.id ?? 0,
      sourceIndex: sourceIndex,
    );
  }

  factory _TimingWorklogSourceRow.external({
    required TimingExternalWorkRecordItem item,
    required int sourceIndex,
  }) {
    final record = item.record;
    return _TimingWorklogSourceRow._(
      sourceType: TimingWorklogReportSourceType.external,
      date: record.workDate,
      deviceName: BuildTimingWorklogReportUseCase._externalDeviceDisplayName(
        record,
      ),
      hours: record.hoursMilli / 1000.0,
      externalCreatedAt: record.createdAt,
      externalRecordId: record.id,
      sourceIndex: sourceIndex,
    );
  }

  final TimingWorklogReportSourceType sourceType;
  final int date;
  final String deviceName;
  final double? startMeter;
  final double? endMeter;
  final double hours;
  final int localRecordId;
  final String externalCreatedAt;
  final String externalRecordId;
  final int sourceIndex;

  TimingWorklogReportRow toReportRow(int sequence) {
    return TimingWorklogReportRow(
      sequence: sequence,
      date: date,
      deviceName: deviceName,
      startMeter: startMeter,
      endMeter: endMeter,
      hours: hours,
    );
  }
}
