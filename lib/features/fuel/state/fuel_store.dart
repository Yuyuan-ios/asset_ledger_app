// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import '../../../data/models/fuel_log.dart';
import '../../../data/models/timing_record.dart';

import '../../../data/repositories/fuel_repository.dart';
import '../../../data/services/fuel_stats_service.dart';
import '../model/fuel_efficiency_agg.dart';

import '../../../core/utils/base_store.dart';

// =====================================================================
// ============================== 二、FuelStore（燃油状态） ==============================
// =====================================================================
//
// 设计目标：
// 1) logs：燃油记录（DB 全量，默认 date DESC）
// 2) loading / error：统一 UI 状态
// 3) insert/update/delete：只暴露流程，UI 不碰 DB
//
// 分层原则：
// - Store：流程 + 轻量纯计算（聚合 / 去重 / 联想）
// - Service：统计口径（年度/区间等）
// - UI：只做输入/展示/筛选
//
// ✅ 效率口径（All time，按设备聚合）：
// - litersPerHour = 总升数 / 总工时小时
// - costPerHour   = 总金额 / 总工时小时
//
// ✅ 计时分母规则（你已确认 + 本次新增）：
// - TimingType.rent：不计入燃油效率（忽略其 hours）
// - excludeFromFuelEfficiency=true（包油/包电等）：不计入燃油效率（忽略其 hours）
// =====================================================================

class FuelStore extends BaseStore {
  FuelStore(this._repository);

  final FuelRepository _repository;

  // -------------------------------------------------------------------
  // 2.1 核心数据：燃油记录（默认 date DESC）
  // -------------------------------------------------------------------
  List<FuelLog> _logs = [];

  Future<void> _reload() async {
    _logs = await _repository.listAll();
  }

  void _sortLogs() {
    _logs.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return (b.id ?? 0).compareTo(a.id ?? 0);
    });
  }

  // -------------------------------------------------------------------
  // 2.2 对外只读暴露（避免外部直接改列表）
  // -------------------------------------------------------------------
  List<FuelLog> get logs => List.unmodifiable(_logs);

  // =====================================================================
  // ============================== 三、读：加载列表 ==============================
  // =====================================================================

  Future<void> loadAll() async {
    await run(() async {
      await _reload();
    });
  }

  // =====================================================================
  // ============================== 四、写：新增 / 更新 / 删除 ==============================
  // =====================================================================

  Future<void> insert(FuelLog log) async {
    await writeAndPatchLocalState(
      write: () => _repository.insert(log),
      patch: (newId) {
        _logs = [..._logs, log.copyWith(id: newId)];
        _sortLogs();
      },
    );
  }

  Future<void> update(FuelLog log) async {
    await writeAndPatchLocalState(
      write: () => _repository.update(log),
      patch: (_) {
        _logs = _logs.map((item) => item.id == log.id ? log : item).toList();
        _sortLogs();
      },
    );
  }

  Future<void> deleteById(int id) async {
    await writeAndPatchLocalState(
      write: () => _repository.deleteById(id),
      patch: (_) {
        _logs = _logs.where((item) => item.id != id).toList();
      },
    );
  }

  // =====================================================================
  // ============================== 五、查：便捷方法 ==============================
  // =====================================================================

  FuelLog? findById(int id) {
    for (final x in _logs) {
      if (x.id == id) return x;
    }
    return null;
  }

  // =====================================================================
  // ============================== 六、统计：年度汇总（Service 收口） ==============================
  // =====================================================================

  FuelYearSummary currentYearSummary({required int nowYmd, String? supplier}) {
    return FuelStatsService.summarizeCurrentYear(
      logs: _logs,
      nowYmd: nowYmd,
      supplier: supplier,
    );
  }

  // =====================================================================
  // ============================== 七、效率聚合（All time） ==============================
  // =====================================================================
  //
  // 说明：
  // 1) 这里是“纯计算”：不查 DB，不改状态，不 notify
  // 2) UI（FuelPage）把 TimingStore.records 传进来即可
  //
  // ✅ 未来扩展兜底（关键设计点）：
  // - “哪些计时参与燃油效率分母”的规则必须只存在一处
  // - 不要让判断散落在多个 for-loop 里
  // - 以后你新增：包电/特殊结算/更多 TimingType，只改这里
  // =====================================================================

  /// 【核心口径】某条计时记录是否计入燃油效率的“工时分母”
  ///
  /// 当前规则：
  /// 1) 只允许 TimingType.hours 参与
  /// 2) excludeFromFuelEfficiency=true（包油/包电等）不参与
  static bool _countsTowardFuelEfficiency(TimingRecord t) {
    // 1) 租金/其它计费类型：不参与效率
    if (t.type != TimingType.hours) return false;

    // 2) 包油/包电/明确排除：不参与效率
    if (t.excludeFromFuelEfficiency) return false;

    return true;
  }

  /// 单设备汇总结果（All time）
  /// - totalHours=0 时：lph / cph 为 null（UI 显示 "--"）
  static Map<int, FuelEfficiencyAgg> buildEfficiencyByDevice({
    required List<FuelLog> fuelLogs,
    required List<TimingRecord> timingRecords,
  }) {
    // 7.1 聚合：燃油（升、金额）按设备累加
    final Map<int, FuelEfficiencyAgg> m = {};

    for (final f in fuelLogs) {
      final id = f.deviceId;
      final agg = m.putIfAbsent(id, () => FuelEfficiencyAgg(deviceId: id));
      agg.totalLiters += f.liters;
      agg.totalCost += f.cost;
    }

    // 7.2 聚合：工时（只计入“参与燃油效率”的工时）
    for (final t in timingRecords) {
      if (!_countsTowardFuelEfficiency(t)) continue;

      final id = t.deviceId;
      final agg = m.putIfAbsent(id, () => FuelEfficiencyAgg(deviceId: id));
      agg.totalHours += t.hours;
    }

    return m;
  }

  /// 便捷：用当前 Store 内存中的燃油 logs 来聚合（All time）
  Map<int, FuelEfficiencyAgg> efficiencyByDeviceAllTime(
    List<TimingRecord> timingRecords,
  ) {
    return buildEfficiencyByDevice(
      fuelLogs: _logs,
      timingRecords: timingRecords,
    );
  }

  /// 全部口径（All time）总汇（所有设备加总）
  FuelEfficiencyAgg efficiencyAllTimeTotal(List<TimingRecord> timingRecords) {
    final byDev = efficiencyByDeviceAllTime(timingRecords);

    final total = FuelEfficiencyAgg(deviceId: -1); // -1 表示“汇总”
    for (final a in byDev.values) {
      total.totalLiters += a.totalLiters;
      total.totalCost += a.totalCost;
      total.totalHours += a.totalHours;
    }
    return total;
  }
}
