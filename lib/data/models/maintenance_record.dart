class MaintenanceRecord {
  final int? id;

  /// 设备 ID
  /// - null 表示“公共支出”
  final int? deviceId;

  /// 日期：YYYYMMDD（公历，统一口径）
  final int ymd;

  /// 事项，例如：换机油 / 年检 / 维修
  final String item;

  /// 金额（元）。A3 起读路径以 amount_fen 为权威；REAL 保留到 A4 删除。
  final double amount;

  /// 金额（分）。A2d 后 DB 中 NOT NULL；测试/legacy 构造可为 null。
  final int? amountFen;

  /// 备注（可空）
  final String? note;

  MaintenanceRecord({
    this.id,
    required this.deviceId,
    required this.ymd,
    required this.item,
    required this.amount,
    this.amountFen,
    this.note,
  });

  int get effectiveAmountFen => amountFen ?? (amount * 100).round();

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
    final nextAmount = amount ?? this.amount;
    return MaintenanceRecord(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      ymd: ymd ?? this.ymd,
      item: item ?? this.item,
      amount: nextAmount,
      amountFen:
          amountFen ??
          (amount == null ? this.amountFen : (nextAmount * 100).round()),
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
      // A1 双写：fen 影子列恒从权威 amount 派生，与迁移回填口径同源。
      'amount_fen': (amount * 100).round(),
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
      amountFen: (map['amount_fen'] as num?)?.toInt(),
      note: map['note'] as String?,
    );
  }
}
