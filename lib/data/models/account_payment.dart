// =====================================================================
// ============================== AccountPayment（收款记录） ==============================
// =====================================================================
//
// 口径：
// - payment 只能属于一个 projectKey（联系人+工地）
// - 不允许项目不存在于计时记录（由 Store 校验）
//
// 字段：
// - id：DB 自增
// - projectKey："$contact||$site"
// - ymd：YYYYMMDD int
// - amount：金额
// - note：可空
// =====================================================================

class AccountPayment {
  final int? id;
  final String projectKey;
  final int ymd;
  final double amount;
  final String? note;

  const AccountPayment({
    this.id,
    required this.projectKey,
    required this.ymd,
    required this.amount,
    this.note,
  });

  AccountPayment copyWith({
    int? id,
    String? projectKey,
    int? ymd,
    double? amount,
    String? note,
  }) {
    return AccountPayment(
      id: id ?? this.id,
      projectKey: projectKey ?? this.projectKey,
      ymd: ymd ?? this.ymd,
      amount: amount ?? this.amount,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'project_key': projectKey,
      'ymd': ymd,
      'amount': amount,
      'note': note,
    };
  }

  static AccountPayment fromMap(Map<String, Object?> m) {
    return AccountPayment(
      id: m['id'] as int?,
      projectKey: (m['project_key'] as String?) ?? '',
      ymd: (m['ymd'] as int?) ?? 0,
      amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
      note: m['note'] as String?,
    );
  }
}
