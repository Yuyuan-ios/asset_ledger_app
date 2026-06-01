import '../../../data/models/device.dart';
import '../../../data/models/timing_record.dart';

class TimingWorklogReport {
  const TimingWorklogReport({
    required this.title,
    required this.rows,
    required this.totalHours,
    required this.deviceFileNamePart,
    required this.startDate,
    required this.endDate,
  });

  final String title;
  final List<TimingWorklogReportRow> rows;
  final double totalHours;
  final String deviceFileNamePart;
  final int startDate;
  final int endDate;

  bool get isEmpty => rows.isEmpty;
}

class TimingWorklogReportRow {
  const TimingWorklogReportRow({
    required this.sequence,
    required this.date,
    required this.deviceName,
    required this.startMeter,
    required this.endMeter,
    required this.hours,
  });

  final int sequence;
  final int date;
  final String deviceName;
  final double startMeter;
  final double endMeter;
  final double hours;
}

class TimingWorklogReportSourceRow {
  const TimingWorklogReportSourceRow({
    required this.record,
    required this.device,
  });

  final TimingRecord record;
  final Device? device;
}
