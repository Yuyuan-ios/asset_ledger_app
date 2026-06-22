import '../../core/measure/quantity.dart';
import '../../core/money/amount_policy.dart';
import '../../core/date/gregorian_year_range.dart';
import '../../core/date/ymd_date.dart';
import '../../core/utils/format_utils.dart';
import '../models/device.dart';
import '../models/project_device_rate.dart';
import '../models/project_key.dart';
import '../models/project_write_off.dart';
import '../models/timing_record.dart';
import 'account_service.dart';

const double _timingIncomeEpsilon = 0.000001;

/// 计时页收入图表：动态应收摊销视图（按设备连续区间按天均摊到自然月）
///
/// 口径说明：
/// 1) 本算法是“动态视图”，不是落库后的静态月汇总。
/// 2) 统计目标月变化时，显式工时结束日可能延长图表分摊；未显式设置时，
///    最后一条同设备工时只分摊到 startDate 所在月。
/// 3) 仅处理收入分摊，不处理支出逻辑。
/// 4) 工时收入真源是实时重算值 `hours * currentEffectiveRate`；
///    租金收入按 [TimingRecord.incomeFen] 计入记录日期所在月。
class TimingMonthlyIncomeService {
  const TimingMonthlyIncomeService._();

  /// 计算指定统计目标月下的“目标年份 1-12 月收入”（实时单价口径）
  ///
  /// 口径切换说明：
  /// - 工时记录收入不再读取 [TimingRecord.income]；
  /// - 工时记录实时收入统一为：`hours * currentEffectiveRate`；
  /// - 租金记录按 [TimingRecord.incomeFen] 直接计入记录日期所在月；
  /// - effectiveRate 规则复用账户页 `AccountService.buildEffectiveRateMap`。
  ///
  /// 其余分摊规则：
  /// - 按设备分组；同设备按日期/码表排序；
  /// - 同设备同日的合法多项目/多工时记录全部保留；
  /// - cutoffDate = min(asOfDate/今天, targetMonth月末)；
  /// - 有下一条：通常结束日 = min(下一条开始日前一天, cutoffDate)；
  ///   若下一条同日开始，当前记录仍按当天计入，避免合法同日记录被跳过；
  /// - 手动设置结束日时，内部 exclusive cutoff = UI 结束日 + 1 day；
  /// - 无手动结束日且无下一条：内部 exclusive cutoff = startDate 下月 1 日；
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
    List<ProjectWriteOff> projectWriteOffs = const [],
  }) {
    final month = targetMonth.clamp(1, 12);
    final targetMonthEnd = _monthEnd(targetYear, month);
    // 统计截止日：不晚于目标月份月末，同时不晚于业务日(asOfDate/今天)。
    final asOf = _utcDateOnly(asOfDate ?? DateTime.now());
    final cutoffDate = asOf.isBefore(targetMonthEnd) ? asOf : targetMonthEnd;
    final statisticsExclusiveCutoff = cutoffDate.add(const Duration(days: 1));
    final monthly = List<double>.filled(12, 0.0);
    final projectMonthlyIncome = <String, Map<int, double>>{};
    final rateCache = <String, Map<int, double>>{};

    for (final record in records) {
      final rentIncome = record.incomeFen / 100.0;
      if (record.type != TimingType.rent || rentIncome <= 0) continue;
      final start = _utcDateOnly(FormatUtils.dateFromYmd(record.startDate));
      if (!start.isAfter(cutoffDate)) {
        final projectId = record.effectiveProjectId;
        _addProjectMonthIncome(
          projectMonthlyIncome,
          projectId: projectId,
          year: start.year,
          month: start.month,
          amount: rentIncome,
        );
        if (start.year == targetYear) {
          monthly[start.month - 1] += rentIncome;
        }
      }
    }

    final grouped = _groupByDevice(records);

    for (final entry in grouped.entries) {
      final deviceRecords = entry.value;
      final sorted = _sortByDateThenMeter(deviceRecords);
      final safeRecords = _retainAllSortedRecords(sorted);
      if (safeRecords.isEmpty) continue;

      for (var i = 0; i < safeRecords.length; i++) {
        final current = safeRecords[i];
        if (current.type == TimingType.rent) {
          continue;
        }

        final start = _utcDateOnly(FormatUtils.dateFromYmd(current.startDate));
        final rate = _resolveEffectiveRate(
          record: current,
          devices: devices,
          rates: rates,
          cache: rateCache,
        );
        // 工时收入按当前有效单价实时重算，不读取 record.income。
        // S2 读路径切换：工作量改读统一计量权威 quantityScaled（rent 已在
        // 上方 continue，此处恒非 null），hours REAL 退为派生兜底。
        final realtimeIncome = AmountPolicy.calculateAmountForQuantity(
          quantity: Quantity(current.quantityScaled ?? 0),
          unitPrice: UnitPrice.fromYuanPerHour(rate),
        ).yuan;

        // 新口径：收入统一由实时单价重算；<= 0 跳过
        if (realtimeIncome <= 0) {
          continue;
        }

        // 未来记录保留在列表中，但不参与当前 cutoffDate 之前的图表统计。
        if (start.isAfter(cutoffDate)) {
          continue;
        }

        final nextStart = i + 1 < safeRecords.length
            ? _utcDateOnly(
                FormatUtils.dateFromYmd(safeRecords[i + 1].startDate),
              )
            : null;
        final implicitExclusiveCutoff = _resolveImplicitExclusiveCutoff(
          start: start,
          nextStart: nextStart,
          statisticsExclusiveCutoff: statisticsExclusiveCutoff,
        );
        // Stored allocationCutoffDate is an exclusive end kept under the
        // existing allocation_cutoff_date column name for compatibility.
        final allocationCutoffExclusiveYmd = current.allocationCutoffDate;
        final allocationEndExclusive = _resolveAllocationEndExclusive(
          start: start,
          nextStart: nextStart,
          implicitExclusiveCutoff: implicitExclusiveCutoff,
          statisticsExclusiveCutoff: statisticsExclusiveCutoff,
          allocationCutoffExclusiveYmd: allocationCutoffExclusiveYmd,
        );
        final end = allocationEndExclusive.subtract(const Duration(days: 1));

        if (end.isBefore(start)) {
          continue;
        }

        final days = _inclusiveDays(start, end);
        if (days <= 0) {
          continue;
        }

        final dailyIncome = realtimeIncome / days;
        _distributeToMonths(
          monthly: monthly,
          projectMonthlyIncome: projectMonthlyIncome,
          projectId: current.effectiveProjectId,
          targetYear: targetYear,
          start: start,
          end: end,
          dailyIncome: dailyIncome,
        );
      }
    }
    return _applyProjectWriteOffs(
      monthly: monthly,
      projectMonthlyIncome: projectMonthlyIncome,
      targetYear: targetYear,
      writeOffs: projectWriteOffs,
    );
  }

  static Map<int, List<TimingRecord>> _groupByDevice(
    List<TimingRecord> records,
  ) {
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

  /// 保留排序后的全部记录（不做任何按日去重）。
  ///
  /// 旧口径曾按“同设备 + 同日期”只保留最后一条，会误删同日不同项目、
  /// 不同项目身份或不同有效收入记录。当前没有可靠的重复记录定义，
  /// 因此这里不再做粗粒度去重，原样返回已排序列表。
  static List<TimingRecord> _retainAllSortedRecords(List<TimingRecord> sorted) {
    return sorted;
  }

  static DateTime _resolveImplicitExclusiveCutoff({
    required DateTime start,
    required DateTime? nextStart,
    required DateTime statisticsExclusiveCutoff,
  }) {
    if (nextStart == null) {
      return _firstDayOfNextMonth(start);
    }
    if (_isSameDay(start, nextStart)) {
      return start.add(const Duration(days: 1));
    }
    return nextStart;
  }

  // Hours allocation priority:
  // 1. explicit UI inclusive end + 1 day, persisted as exclusive cutoff;
  // 2. otherwise next same-device startDate;
  // 3. otherwise first day of next month.
  // This only affects monthly income chart distribution. Rent, TimingRecord
  // income, project receivable, accounts, payments, and settlements do not
  // consume this allocation rule.
  static DateTime _resolveAllocationEndExclusive({
    required DateTime start,
    required DateTime? nextStart,
    required DateTime implicitExclusiveCutoff,
    required DateTime statisticsExclusiveCutoff,
    required int? allocationCutoffExclusiveYmd,
  }) {
    final explicitExclusiveCutoff = _validExplicitCutoffForCalculation(
      start: start,
      nextStart: nextStart,
      allocationCutoffExclusiveYmd: allocationCutoffExclusiveYmd,
    );
    final allocationEndExclusive = switch (explicitExclusiveCutoff) {
      final DateTime explicit => explicit,
      null => implicitExclusiveCutoff,
    };
    return _minDate(allocationEndExclusive, statisticsExclusiveCutoff);
  }

  static DateTime? _validExplicitCutoffForCalculation({
    required DateTime start,
    required DateTime? nextStart,
    required int? allocationCutoffExclusiveYmd,
  }) {
    if (allocationCutoffExclusiveYmd == null) {
      return null;
    }

    final explicitExclusiveCutoff = _tryDateFromYmd(
      allocationCutoffExclusiveYmd,
    );
    if (explicitExclusiveCutoff == null ||
        !explicitExclusiveCutoff.isAfter(start)) {
      return null;
    }
    if (nextStart != null &&
        explicitExclusiveCutoff.isAfter(
          nextStart.add(const Duration(days: 1)),
        )) {
      return null;
    }
    return explicitExclusiveCutoff;
  }

  static DateTime? _tryDateFromYmd(int ymd) {
    try {
      return _utcDateOnly(FormatUtils.dateFromYmd(ymd));
    } on ArgumentError {
      return null;
    }
  }

  static DateTime _minDate(DateTime a, DateTime b) {
    return a.isBefore(b) ? a : b;
  }

  static DateTime _firstDayOfNextMonth(DateTime date) {
    return DateTime.utc(date.year, date.month + 1, 1);
  }

  static void _distributeToMonths({
    required List<double> monthly,
    required Map<String, Map<int, double>> projectMonthlyIncome,
    required String projectId,
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
      final days = _inclusiveDays(cursor, segmentEnd);
      final amount = dailyIncome * days;

      _addProjectMonthIncome(
        projectMonthlyIncome,
        projectId: projectId,
        year: cursor.year,
        month: cursor.month,
        amount: amount,
      );

      if (cursor.year == targetYear) {
        monthly[cursor.month - 1] += amount;
      }

      cursor = segmentEnd.add(const Duration(days: 1));
    }
  }

  static void _addProjectMonthIncome(
    Map<String, Map<int, double>> projectMonthlyIncome, {
    required String projectId,
    required int year,
    required int month,
    required double amount,
  }) {
    if (projectId.trim().isEmpty || amount <= 0) return;
    final monthKey = year * 100 + month;
    final monthly = projectMonthlyIncome.putIfAbsent(projectId, () => {});
    monthly[monthKey] = (monthly[monthKey] ?? 0.0) + amount;
  }

  static List<double> _applyProjectWriteOffs({
    required List<double> monthly,
    required Map<String, Map<int, double>> projectMonthlyIncome,
    required int targetYear,
    required List<ProjectWriteOff> writeOffs,
  }) {
    if (writeOffs.isEmpty || projectMonthlyIncome.isEmpty) return monthly;

    final yearRange = GregorianYearRange.forYear(targetYear);
    final writeOffByProjectId = <String, double>{};
    for (final writeOff in writeOffs) {
      final projectId = writeOff.projectId.trim();
      if (projectId.isEmpty || writeOff.amount <= 0) continue;
      if (!yearRange.containsDateText(writeOff.writeOffDate)) continue;
      writeOffByProjectId[projectId] =
          (writeOffByProjectId[projectId] ?? 0.0) + writeOff.amount;
    }
    if (writeOffByProjectId.isEmpty) return monthly;

    final adjusted = List<double>.from(monthly);
    for (final entry in writeOffByProjectId.entries) {
      final monthIncome = projectMonthlyIncome[entry.key];
      if (monthIncome == null || monthIncome.isEmpty) continue;

      final projectOriginalIncome = monthIncome.values.fold<double>(
        0.0,
        (sum, amount) => sum + amount,
      );
      if (projectOriginalIncome <= _timingIncomeEpsilon) continue;

      for (final monthEntry in monthIncome.entries) {
        final monthKey = monthEntry.key;
        final year = monthKey ~/ 100;
        if (year != targetYear) continue;

        final month = monthKey % 100;
        if (month < 1 || month > 12) continue;

        final originalIncome = monthEntry.value;
        final allocatedWriteOff =
            entry.value * originalIncome / projectOriginalIncome;
        final cappedWriteOff = allocatedWriteOff > originalIncome
            ? originalIncome
            : allocatedWriteOff;
        final index = month - 1;
        adjusted[index] -= cappedWriteOff;
        if (adjusted[index].abs() <= _timingIncomeEpsilon ||
            adjusted[index] < 0) {
          adjusted[index] = 0.0;
        }
      }
    }
    return adjusted;
  }

  static DateTime _monthEnd(int year, int month) {
    return DateTime.utc(year, month + 1, 0);
  }

  static DateTime _utcDateOnly(DateTime dateTime) {
    return DateTime.utc(dateTime.year, dateTime.month, dateTime.day);
  }

  static int _inclusiveDays(DateTime start, DateTime end) {
    return _ymdFromDate(start).daysBetween(_ymdFromDate(end)) + 1;
  }

  static YmdDate _ymdFromDate(DateTime dateTime) {
    final ymd = dateTime.year * 10000 + dateTime.month * 100 + dateTime.day;
    final parsed = YmdDate.fromInt(ymd);
    if (parsed == null) {
      throw ArgumentError.value(ymd, 'ymd', '非法 YYYYMMDD 日期');
    }
    return parsed;
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
    final cacheKey =
        '${record.effectiveProjectId}#$projectKey#${record.isBreaking ? 1 : 0}';
    final effectiveRateMap = cache.putIfAbsent(
      cacheKey,
      () => AccountService.buildEffectiveRateMap(
        projectId: record.effectiveProjectId,
        projectKey: projectKey,
        devices: devices,
        rates: rates,
        isBreaking: record.isBreaking,
      ),
    );
    return effectiveRateMap[record.deviceId] ?? 0.0;
  }
}
