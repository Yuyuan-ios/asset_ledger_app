class MaintenanceRecord {
  final int? id;

  /// 设备 ID
  /// - null 表示“公共支出”
  final int? deviceId;

  /// 日期：YYYYMMDD（公历，统一口径）
  final int ymd;

  /// 事项，例如：换机油 / 年检 / 维修
  final String item;

  /// 金额
  final double amount;

  /// 备注（可空）
  final String? note;

  MaintenanceRecord({
    this.id,
    required this.deviceId,
    required this.ymd,
    required this.item,
    required this.amount,
    this.note,
  });

  MaintenanceRecord copyWith({
    int? id,
    int? deviceId,
    int? ymd,
    String? item,
    double? amount,
    String? note,
  }) {
    return MaintenanceRecord(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      ymd: ymd ?? this.ymd,
      item: item ?? this.item,
      amount: amount ?? this.amount,
      note: note ?? this.note,
    );
  }

  // ---------------- DB 映射 ----------------

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'ymd': ymd,
      'item': item,
      'amount': amount,
      'note': note,
    };
  }

  factory MaintenanceRecord.fromMap(Map<String, dynamic> map) {
    return MaintenanceRecord(
      id: map['id'] as int?,
      deviceId: map['device_id'] as int?,
      ymd: map['ymd'] as int,
      item: map['item'] as String,
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String?,
    );
  }
}
