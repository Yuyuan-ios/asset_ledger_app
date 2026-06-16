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

  // 金额（分）。A4 起为唯一存储权威。
  final int costFen;

  FuelLog({
    this.id,
    required this.deviceId,
    required this.date,
    required this.supplier,
    required this.liters,
    required double cost,
    int? costFen,
  }) : costFen = costFen ?? (cost * 100).round();

  double get cost => costFen / 100.0;

  int get effectiveCostFen => costFen;

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
    return FuelLog(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      date: date ?? this.date,
      supplier: supplier ?? this.supplier,
      liters: liters ?? this.liters,
      cost: cost ?? this.cost,
      costFen: costFen ?? (cost == null ? this.costFen : null),
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
      'cost_fen': costFen,
    };
  }

  factory FuelLog.fromMap(Map<String, dynamic> map) {
    final rawFen = map['cost_fen'] as num?;
    if (rawFen == null) {
      throw StateError('fuel_logs.cost_fen is required');
    }
    return FuelLog(
      id: map['id'] as int?,
      deviceId: map['device_id'] as int,
      date: map['date'] as int,
      supplier: (map['supplier'] as String?) ?? '',
      liters: (map['liters'] as num).toDouble(),
      cost: rawFen.toInt() / 100.0,
      costFen: rawFen.toInt(),
    );
  }

  @override
  String toString() {
    return 'FuelLog(id: $id, dev: $deviceId, date: $date, supplier: $supplier, ${liters}L, ¥$cost)';
  }
}
