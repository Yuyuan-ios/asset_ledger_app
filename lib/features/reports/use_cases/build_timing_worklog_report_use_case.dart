import '../../../data/models/device.dart';
import '../../../data/models/timing_record.dart';
import '../models/timing_worklog_report.dart';

class BuildTimingWorklogReportUseCase {
  const BuildTimingWorklogReportUseCase();

  static const String title = '挖机工时打卡汇总';

  TimingWorklogReport execute({
    required List<TimingRecord> records,
    required List<Device> devices,
  }) {
    final deviceById = <int, Device>{
      for (final device in devices)
        if (device.id != null) device.id!: device,
    };
    final sortedRows =
        [
          for (final record in records)
            TimingWorklogReportSourceRow(
              record: record,
              device: deviceById[record.deviceId],
            ),
        ]..sort((a, b) {
          final byDate = a.record.startDate.compareTo(b.record.startDate);
          if (byDate != 0) return byDate;
          return (a.record.id ?? 0).compareTo(b.record.id ?? 0);
        });

    final rows = <TimingWorklogReportRow>[];
    for (var i = 0; i < sortedRows.length; i += 1) {
      final source = sortedRows[i];
      rows.add(
        TimingWorklogReportRow(
          sequence: i + 1,
          date: source.record.startDate,
          deviceName: _deviceDisplayName(source.record.deviceId, source.device),
          startMeter: source.record.startMeter,
          endMeter: source.record.endMeter,
          hours: source.record.hours,
        ),
      );
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
