// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import '../../../data/models/maintenance_record.dart';
import '../../../data/repositories/maintenance_repository.dart';
import '../../../core/date/gregorian_year_range.dart';
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
// - 统计块口径：公历当年
// =====================================================================

class MaintenanceStore extends BaseStore {
  MaintenanceStore(this._repository);

  final MaintenanceRepository _repository;

  // -------------------------------------------------------------------
  // 2.1 核心数据：维保记录
  // -------------------------------------------------------------------
  List<MaintenanceRecord> _records = [];

  Future<void> _reload() async {
    _records = await _repository.listAll();
  }

  void _sortRecords() {
    _records = [..._records]
      ..sort((a, b) {
        final byDate = b.ymd.compareTo(a.ymd);
        if (byDate != 0) return byDate;
        return (b.id ?? 0).compareTo(a.id ?? 0);
      });
  }

  // -------------------------------------------------------------------
  // 2.2 对外只读暴露
  // -------------------------------------------------------------------
  List<MaintenanceRecord> get records => List.unmodifiable(_records);

  // =====================================================================
  // ============================== 三、读：loadAll ==============================
  // =====================================================================

  Future<void> loadAll() async {
    await run(() async {
      await _reload();
    });
  }

  // =====================================================================
  // ============================== 四、写：save（insert/update） ==============================
  // =====================================================================

  Future<void> save(MaintenanceRecord record) async {
    await writeAndPatchLocalState(
      write: () async {
        if (record.id == null) {
          return await _repository.insert(record);
        }
        await _repository.update(record);
        return record.id!;
      },
      patch: (recordId) {
        final next = record.copyWith(id: recordId);
        final index = _records.indexWhere((item) => item.id == recordId);
        if (index == -1) {
          _records = [..._records, next];
        } else {
          final updated = [..._records];
          updated[index] = next;
          _records = updated;
        }
        _sortRecords();
      },
    );
  }

  // =====================================================================
  // ============================== 五、删：deleteById ==============================
  // =====================================================================

  Future<void> deleteById(int id) async {
    await writeAndPatchLocalState(
      write: () async {
        await _repository.deleteById(id);
        return id;
      },
      patch: (_) {
        _records = _records.where((item) => item.id != id).toList();
      },
    );
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
    final range = GregorianYearRange.containingYmd(nowYmd);

    final Map<int?, double> out = {};
    for (final r in _records) {
      if (!range.containsYmd(r.ymd)) continue;
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
}
