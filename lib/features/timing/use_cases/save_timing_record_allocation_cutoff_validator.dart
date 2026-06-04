import '../../../data/models/timing_record.dart';

class SaveTimingRecordAllocationCutoffValidationException implements Exception {
  const SaveTimingRecordAllocationCutoffValidationException({
    required this.code,
    required this.message,
  });

  static const cutoffNotAfterStartDate = 'cutoff_not_after_start_date';
  static const cutoffSameDayNextRecordNotSupported =
      'cutoff_same_day_next_record_not_supported';
  static const cutoffAfterNextSameDeviceStartDate =
      'cutoff_after_next_same_device_start_date';

  final String code;
  final String message;

  @override
  String toString() {
    return 'SaveTimingRecordAllocationCutoffValidationException'
        '($code: $message)';
  }
}

class SaveTimingRecordAllocationCutoffValidator {
  const SaveTimingRecordAllocationCutoffValidator._();

  static void validate({
    required TimingRecord record,
    required Iterable<TimingRecord> sameDeviceRecords,
    int? editingRecordId,
  }) {
    final cutoff = record.allocationCutoffDate;
    if (cutoff == null) return;

    if (cutoff <= record.startDate) {
      throw const SaveTimingRecordAllocationCutoffValidationException(
        code: SaveTimingRecordAllocationCutoffValidationException
            .cutoffNotAfterStartDate,
        message: '分摊截止日期必须晚于计时日期',
      );
    }

    final selfId = editingRecordId ?? record.id;
    final peers =
        sameDeviceRecords
            .where((candidate) {
              if (candidate.deviceId != record.deviceId) return false;
              if (selfId != null && candidate.id == selfId) return false;
              return candidate.startDate >= record.startDate;
            })
            .toList(growable: false)
          ..sort(_compareByDateThenMeterThenId);

    final hasSameDayPeer = peers.any(
      (candidate) => candidate.startDate == record.startDate,
    );
    if (hasSameDayPeer) {
      throw const SaveTimingRecordAllocationCutoffValidationException(
        code: SaveTimingRecordAllocationCutoffValidationException
            .cutoffSameDayNextRecordNotSupported,
        message: '同设备同日存在后续记录时，第一版暂不支持显式分摊截止日期',
      );
    }

    int? nextStartDate;
    for (final candidate in peers) {
      if (candidate.startDate > record.startDate) {
        nextStartDate = candidate.startDate;
        break;
      }
    }
    if (nextStartDate != null && cutoff > nextStartDate) {
      throw SaveTimingRecordAllocationCutoffValidationException(
        code: SaveTimingRecordAllocationCutoffValidationException
            .cutoffAfterNextSameDeviceStartDate,
        message: '分摊截止日期不能晚于下一条同设备记录的计时日期',
      );
    }
  }

  static int _compareByDateThenMeterThenId(TimingRecord a, TimingRecord b) {
    final byDate = a.startDate.compareTo(b.startDate);
    if (byDate != 0) return byDate;

    final byMeter = a.startMeter.compareTo(b.startMeter);
    if (byMeter != 0) return byMeter;

    return (a.id ?? 1 << 30).compareTo(b.id ?? 1 << 30);
  }
}
