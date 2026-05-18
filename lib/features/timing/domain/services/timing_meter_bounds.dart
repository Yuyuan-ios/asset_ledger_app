import '../entities/timing_entities.dart';

class TimingMeterBounds {
  const TimingMeterBounds._();

  static double lowerBound({
    required List<TimingRecord> records,
    required int deviceId,
    required int startDate,
    int? excludeId,
  }) {
    double maxEnd = 0.0;
    for (final record in records) {
      if (record.deviceId != deviceId) continue;
      if (excludeId != null && record.id == excludeId) continue;
      if (record.startDate >= startDate) continue;
      if (record.endMeter > maxEnd) maxEnd = record.endMeter;
    }
    return maxEnd;
  }

  static double upperBound({
    required List<TimingRecord> records,
    required int deviceId,
    required int startDate,
    int? excludeId,
  }) {
    double minEnd = double.infinity;
    for (final record in records) {
      if (record.deviceId != deviceId) continue;
      if (excludeId != null && record.id == excludeId) continue;
      if (record.startDate <= startDate) continue;
      if (record.endMeter < minEnd) minEnd = record.endMeter;
    }
    return minEnd;
  }
}
