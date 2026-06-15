// =====================================================================
// ============================== 燃油记录模型 ==============================
// =====================================================================
//
// 设计目标：
// - supplier：必填（后续列表可按供应人快速筛选）
// - deviceId：绑定设备（历史记录靠 device_id 锚定）
// - date：YYYYMMDD（和你 TimingRecord 一致，用 int 存）
// =====================================================================

class FuelLog {
  final int? id;

  // 设备 id（外键逻辑由你业务保证；DB 目前未加 FK 也能跑）
  final int deviceId;

  // 日期：YYYYMMDD
  final int date;

  // ✅ 供应人（必填）：用于筛选
  final String supplier;

  // 加油量（升）
  final double liters;

  // 金额（元）。A3 起读路径以 cost_fen 为权威；REAL 保留到 A4 删除。
  final double cost;

  // 金额（分）。A2c 后 DB 中 NOT NULL；测试/legacy 构造可为 null。
  final int? costFen;

  const FuelLog({
    this.id,
    required this.deviceId,
    required this.date,
    required this.supplier,
    required this.liters,
    required this.cost,
    this.costFen,
  });

  int get effectiveCostFen => costFen ?? (cost * 100).round();

  double get effectiveCost => effectiveCostFen / 100.0;

  // -------------------------------------------------------------------
  // CopyWith
  // -------------------------------------------------------------------
  FuelLog copyWith({
    int? id,
    int? deviceId,
    int? date,
    String? supplier,
    double? liters,
    double? cost,
    int? costFen,
  }) {
    final nextCost = cost ?? this.cost;
    return FuelLog(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      date: date ?? this.date,
      supplier: supplier ?? this.supplier,
      liters: liters ?? this.liters,
      cost: nextCost,
      costFen:
          costFen ?? (cost == null ? this.costFen : (nextCost * 100).round()),
    );
  }

  // -------------------------------------------------------------------
  // Map <-> Object
  // -------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'date': date,
      'supplier': supplier,
      'liters': liters,
      'cost': cost,
      // A1 双写：fen 影子列恒从权威 cost 派生，与迁移回填口径同源。
      'cost_fen': (cost * 100).round(),
    };
  }

  factory FuelLog.fromMap(Map<String, dynamic> map) {
    return FuelLog(
      id: map['id'] as int?,
      deviceId: map['device_id'] as int,
      date: map['date'] as int,
      supplier: (map['supplier'] as String?) ?? '',
      liters: (map['liters'] as num).toDouble(),
      cost: (map['cost'] as num).toDouble(),
      costFen: (map['cost_fen'] as num?)?.toInt(),
    );
  }

  @override
  String toString() {
    return 'FuelLog(id: $id, dev: $deviceId, date: $date, supplier: $supplier, ${liters}L, ¥$cost)';
  }
}
