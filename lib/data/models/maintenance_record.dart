class MaintenanceRecord {
  final int? id;

  /// 设备 ID
  /// - null 表示“公共支出”
  final int? deviceId;

  /// 日期：YYYYMMDD（公历，统一口径）
  final int ymd;

  /// 事项，例如：换机油 / 年检 / 维修
  final String item;

  /// 金额（分）。A4 起为唯一存储权威。
  final int amountFen;

  /// 备注（可空）
  final String? note;

  MaintenanceRecord({
    this.id,
    required this.deviceId,
    required this.ymd,
    required this.item,
    required double amount,
    int? amountFen,
    this.note,
  }) : amountFen = amountFen ?? (amount * 100).round();

  double get amount => amountFen / 100.0;

  int get effectiveAmountFen => amountFen;

  double get effectiveAmount => effectiveAmountFen / 100.0;

  MaintenanceRecord copyWith({
    int? id,
    int? deviceId,
    int? ymd,
    String? item,
    double? amount,
    int? amountFen,
    String? note,
  }) {
    return MaintenanceRecord(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      ymd: ymd ?? this.ymd,
      item: item ?? this.item,
      amount: amount ?? this.amount,
      amountFen: amountFen ?? (amount == null ? this.amountFen : null),
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
      'amount_fen': amountFen,
      'note': note,
    };
  }

  factory MaintenanceRecord.fromMap(Map<String, dynamic> map) {
    final rawFen = map['amount_fen'] as num?;
    if (rawFen == null) {
      throw StateError('maintenance_records.amount_fen is required');
    }
    return MaintenanceRecord(
      id: map['id'] as int?,
      deviceId: map['device_id'] as int?,
      ymd: map['ymd'] as int,
      item: map['item'] as String,
      amount: rawFen.toInt() / 100.0,
      amountFen: rawFen.toInt(),
      note: map['note'] as String?,
    );
  }
}
