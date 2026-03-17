import '../../core/utils/format_utils.dart';
import '../models/device.dart';
import '../models/project_device_rate.dart';
import '../models/project_key.dart';
import '../models/timing_record.dart';
import 'account_service.dart';

/// 计时页收入图表：动态应收摊销视图（按设备连续区间按天均摊到自然月）
///
/// 口径说明：
/// 1) 本算法是“动态视图”，不是落库后的静态月汇总。
/// 2) 统计目标月变化时，未闭合区间会延长到新目标月月末，因此历史月份允许重算变化。
/// 3) 仅处理收入分摊，不处理支出逻辑。
/// 4) 图表收入真源是实时重算值 `hours * currentEffectiveRate`，
///    不是 [TimingRecord.income]（后者仅作为兼容历史字段保留）。
class TimingMonthlyIncomeService {
  const TimingMonthlyIncomeService._();

  /// 计算指定统计目标月下的“目标年份 1-12 月收入”（实时单价口径）
  ///
  /// 口径切换说明：
  /// - 图表收入真源不再读取 [TimingRecord.income]；
  /// - 每条记录实时收入统一为：`hours * currentEffectiveRate`；
  /// - effectiveRate 规则复用账户页 `AccountService.buildEffectiveRateMap`。
  ///
  /// 其余分摊规则：
  /// - 按设备分组；同设备按日期/码表排序；
  /// - 同设备同日多条，仅保留排序最后一条；
  /// - cutoffDate = min(asOfDate/今天, targetMonth月末)；
  /// - 有下一条：结束日 = min(下一条开始日前一天, cutoffDate)；
  /// - 无下一条：结束日 = cutoffDate；
  /// - 若 startDate > cutoffDate，该记录本次图表统计跳过；
  /// - 未来记录允许存在于列表中，但不进入当前收入图表；
  /// - 按天均摊到自然月。
  static List<double> computeMonthlyIncomeRealtime({
    required List<TimingRecord> records,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required int targetYear,
    required int targetMonth,
    DateTime? asOfDate,
  }) {
    final month = targetMonth.clamp(1, 12);
    final targetMonthEnd = _monthEnd(targetYear, month);
    // 统计截止日：不晚于目标月份月末，同时不晚于业务日(asOfDate/今天)。
    final asOf = _dateOnly(asOfDate ?? DateTime.now());
    final cutoffDate = asOf.isBefore(targetMonthEnd) ? asOf : targetMonthEnd;
    final monthly = List<double>.filled(12, 0.0);
    final rateCache = <String, Map<int, double>>{};

    final grouped = _groupByDevice(records);

    for (final entry in grouped.entries) {
      final deviceRecords = entry.value;
      final sorted = _sortByDateThenMeter(deviceRecords);
      final safeRecords = _keepLastRecordPerDay(sorted);
      if (safeRecords.isEmpty) continue;

      for (var i = 0; i < safeRecords.length; i++) {
        final current = safeRecords[i];
        final rate = _resolveEffectiveRate(
          record: current,
          devices: devices,
          rates: rates,
          cache: rateCache,
        );
        // 图表收入唯一真源：按当前有效单价实时重算，不读取 record.income。
        final realtimeIncome = current.hours * rate;

        // 新口径：收入统一由实时单价重算；<= 0 跳过
        if (realtimeIncome <= 0) {
          continue;
        }

        final start = FormatUtils.dateFromYmd(current.startDate);
        // 未来记录保留在列表中，但不参与当前 cutoffDate 之前的图表统计。
        if (start.isAfter(cutoffDate)) {
          continue;
        }

        DateTime end;
        if (i + 1 < safeRecords.length) {
          final nextStart = FormatUtils.dateFromYmd(safeRecords[i + 1].startDate);
          end = nextStart.subtract(const Duration(days: 1));
        } else {
          end = cutoffDate;
        }

        if (end.isAfter(cutoffDate)) {
          end = cutoffDate;
        }

        if (end.isBefore(start)) {
          continue;
        }

        final days = end.difference(start).inDays + 1;
        if (days <= 0) {
          continue;
        }

        final dailyIncome = realtimeIncome / days;
        _distributeToMonths(
          monthly: monthly,
          targetYear: targetYear,
          start: start,
          end: end,
          dailyIncome: dailyIncome,
        );
      }
    }
    return monthly;
  }

  static Map<int, List<TimingRecord>> _groupByDevice(List<TimingRecord> records) {
    final grouped = <int, List<TimingRecord>>{};
    for (final record in records) {
      grouped.putIfAbsent(record.deviceId, () => []).add(record);
    }
    return grouped;
  }

  static List<TimingRecord> _sortByDateThenMeter(List<TimingRecord> records) {
    final sorted = List<TimingRecord>.from(records);
    sorted.sort((a, b) {
      final byDate = a.startDate.compareTo(b.startDate);
      if (byDate != 0) return byDate;

      final byMeter = a.startMeter.compareTo(b.startMeter);
      if (byMeter != 0) return byMeter;

      return (a.id ?? 1 << 30).compareTo(b.id ?? 1 << 30);
    });
    return sorted;
  }

  /// 同设备同一天仅保留排序后的最后一条。
  ///
  /// - 同日不同 startMeter：保留最大 startMeter 的那条（排序最后）
  /// - 同日同 startMeter 冲突：保留排序最后一条（通常是 id 更大）
  ///
  /// 这条策略用于防止同日多条记录造成同日收入重复分摊。
  static List<TimingRecord> _keepLastRecordPerDay(List<TimingRecord> sorted) {
    final result = <TimingRecord>[];
    for (var i = 0; i < sorted.length; i++) {
      final current = sorted[i];
      final isLastOfDay =
          i == sorted.length - 1 || sorted[i + 1].startDate != current.startDate;
      if (isLastOfDay) {
        result.add(current);
      }
    }
    return result;
  }

  static void _distributeToMonths({
    required List<double> monthly,
    required int targetYear,
    required DateTime start,
    required DateTime end,
    required double dailyIncome,
  }) {
    // 按 segment 逐月分配；由于 end 已截断到 targetMonth 月末，
    // 因此 targetMonth 之后月份保持为 0（图表全年 12 个月固定渲染）。
    var cursor = start;
    while (!cursor.isAfter(end)) {
      final monthEnd = _monthEnd(cursor.year, cursor.month);
      final segmentEnd = monthEnd.isBefore(end) ? monthEnd : end;
      final days = segmentEnd.difference(cursor).inDays + 1;

      if (cursor.year == targetYear) {
        monthly[cursor.month - 1] += dailyIncome * days;
      }

      cursor = segmentEnd.add(const Duration(days: 1));
    }
  }

  static DateTime _monthEnd(int year, int month) {
    return DateTime(year, month + 1, 0);
  }

  static DateTime _dateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  static double _resolveEffectiveRate({
    required TimingRecord record,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required Map<String, Map<int, double>> cache,
  }) {
    // 与账户页保持同一单价口径：
    // ProjectKey(contact, site) + buildEffectiveRateMap(覆写/破碎/默认兜底)。
    final projectKey = ProjectKey.buildKey(
      contact: record.contact.trim(),
      site: record.site.trim(),
    );
    final cacheKey = '$projectKey#${record.isBreaking ? 1 : 0}';
    final effectiveRateMap = cache.putIfAbsent(
      cacheKey,
      () => AccountService.buildEffectiveRateMap(
        projectKey: projectKey,
        devices: devices,
        rates: rates,
        isBreaking: record.isBreaking,
      ),
    );
    return effectiveRateMap[record.deviceId] ?? 0.0;
  }
}
