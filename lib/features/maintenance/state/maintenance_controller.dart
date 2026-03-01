// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import '../../../data/models/maintenance_record.dart';
import '../../../data/repositories/maintenance_repository.dart';
import '../../../core/utils/base_store.dart';

// =====================================================================
// ============================== 二、MaintenanceStore（维保状态） ==============================
// =====================================================================
//
// 设计目标：
// - records：维保记录列表（DB 全量，默认按 ymd DESC）
// - loading / error：统一由 BaseStore 承担
// - save/delete：对外只暴露流程，不在 UI 层写 DB
//
// 业务约定：
// - deviceId == null：表示“公共支出”（不属于任何设备）
// - 统计块口径：当年（当前先用“公历年”占位；后续你要切农历年时再统一收口）
// =====================================================================

class MaintenanceStore extends BaseStore {
  // -------------------------------------------------------------------
  // 2.1 核心数据：维保记录
  // -------------------------------------------------------------------
  List<MaintenanceRecord> _records = [];

  // -------------------------------------------------------------------
  // 2.2 对外只读暴露
  // -------------------------------------------------------------------
  List<MaintenanceRecord> get records => List.unmodifiable(_records);

  // =====================================================================
  // ============================== 三、读：loadAll ==============================
  // =====================================================================

  Future<void> loadAll() async {
    await run(() async {
      _records = await MaintenanceRepo.listAll();
    });
  }

  // =====================================================================
  // ============================== 四、写：save（insert/update） ==============================
  // =====================================================================

  Future<void> save(MaintenanceRecord record) async {
    await run(() async {
      if (record.id == null) {
        await MaintenanceRepo.insert(record);
      } else {
        await MaintenanceRepo.update(record);
      }
      _records = await MaintenanceRepo.listAll();
    });
  }

  // =====================================================================
  // ============================== 五、删：deleteById ==============================
  // =====================================================================

  Future<void> deleteById(int id) async {
    await run(() async {
      await MaintenanceRepo.deleteById(id);
      _records = await MaintenanceRepo.listAll();
    });
  }

  // =====================================================================
  // ============================== 六、统计：当年按设备 & 公共 ==============================
  // =====================================================================
  //
  // 返回：
  // - key = deviceId（null 表示公共支出）
  // - value = 总金额
  // -------------------------------------------------------------------

  Map<int?, double> currentYearSummary({required int nowYmd}) {
    final range = _currentYearRange(nowYmd);

    final Map<int?, double> out = {};
    for (final r in _records) {
      if (r.ymd < range.start || r.ymd > range.end) continue;
      final k = r.deviceId; // ✅ null=公共
      out[k] = (out[k] ?? 0) + r.amount;
    }
    return out;
  }

  double currentYearTotal({required int nowYmd}) {
    final m = currentYearSummary(nowYmd: nowYmd);
    double sum = 0;
    for (final v in m.values) {
      sum += v;
    }
    return sum;
  }

  // -------------------------------------------------------------------
  // 当前占位：公历年范围（后续你要切“农历年”时，再统一替换这里）
  // -------------------------------------------------------------------
  _YmdRange _currentYearRange(int nowYmd) {
    final y = nowYmd ~/ 10000;
    return _YmdRange(start: y * 10000 + 101, end: y * 10000 + 1231);
  }
}

class _YmdRange {
  final int start;
  final int end;
  const _YmdRange({required this.start, required this.end});
}
