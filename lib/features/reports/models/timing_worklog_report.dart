import '../../../core/measure/measure_unit.dart';
import '../../../data/models/device.dart';
import '../../../data/models/timing_record.dart';

class TimingWorklogReport {
  const TimingWorklogReport({
    required this.title,
    required this.rows,
    required this.totalHours,
    required this.totalAmountFen,
    required this.unitTotals,
    required this.deviceFileNamePart,
    required this.startDate,
    required this.endDate,
  });

  final String title;
  final List<TimingWorklogReportRow> rows;
  final double totalHours;
  final int totalAmountFen;
  final List<TimingWorklogUnitTotal> unitTotals;
  final String deviceFileNamePart;
  final int startDate;
  final int endDate;

  bool get isEmpty => rows.isEmpty;
}

class TimingWorklogUnitTotal {
  const TimingWorklogUnitTotal({
    required this.unit,
    required this.quantityScaled,
  });

  final MeasureUnit unit;
  final int quantityScaled;

  double get quantity => quantityScaled / 1000.0;
}

class TimingWorklogReportRow {
  const TimingWorklogReportRow({
    required this.sequence,
    required this.date,
    required this.deviceName,
    required this.contactName,
    required this.siteName,
    required this.projectName,
    required this.workContent,
    required this.startMeter,
    required this.endMeter,
    required this.unit,
    required this.quantityScaled,
    required this.unitPriceFen,
    required this.amountFen,
    required this.sourceType,
  });

  final int sequence;
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
  final TimingWorklogReportSourceType sourceType;

  double get quantity => (quantityScaled ?? 0) / 1000.0;

  double get hours => unit == MeasureUnit.hour ? quantity : 0;

  double? get unitPriceYuan =>
      unitPriceFen == null ? null : unitPriceFen! / 100.0;

  double get amountYuan => amountFen / 100.0;
}

class TimingWorklogReportSourceRow {
  const TimingWorklogReportSourceRow({
    required this.record,
    required this.device,
  });

  final TimingRecord record;
  final Device? device;
}

enum TimingWorklogReportSourceType { local, external }
