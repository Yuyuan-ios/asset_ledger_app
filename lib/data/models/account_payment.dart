// =====================================================================

import 'project_id.dart';
// ============================== AccountPayment（收款记录） ==============================
// =====================================================================
//
// 口径：
// - payment 归属于一个 project_id
// - projectKey 仅保留为旧备份和展示兜底
//
// 字段：
// - id：DB 自增
// - projectId：稳定项目身份
// - projectKey：legacy 联系人+工地快照
// - ymd：YYYYMMDD int
// - amount：金额
// - note：可空
// - sourceType：manual 普通收款 / merge_allocation 合并收款分摊
// - merge*：合并收款分摊批次快照字段
// - createdAt：创建时间（旧数据可为空）
// =====================================================================

class AccountPayment {
  static const String sourceTypeManual = 'manual';
  static const String sourceTypeMergeAllocation = 'merge_allocation';

  final int? id;
  final String projectId;
  final String projectKey;
  final int ymd;
  final double amount;
  final String? note;
  final String sourceType;
  final int? mergeGroupId;
  final String? mergeBatchId;
  final double? mergeBatchTotalAmount;
  final String? mergeBatchNote;
  final String? createdAt;

  const AccountPayment({
    this.id,
    this.projectId = '',
    required this.projectKey,
    required this.ymd,
    required this.amount,
    this.note,
    this.sourceType = sourceTypeManual,
    this.mergeGroupId,
    this.mergeBatchId,
    this.mergeBatchTotalAmount,
    this.mergeBatchNote,
    this.createdAt,
  });

  AccountPayment copyWith({
    int? id,
    String? projectId,
    String? projectKey,
    int? ymd,
    double? amount,
    String? note,
    String? sourceType,
    int? mergeGroupId,
    String? mergeBatchId,
    double? mergeBatchTotalAmount,
    String? mergeBatchNote,
    String? createdAt,
  }) {
    return AccountPayment(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      projectKey: projectKey ?? this.projectKey,
      ymd: ymd ?? this.ymd,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      sourceType: sourceType ?? this.sourceType,
      mergeGroupId: mergeGroupId ?? this.mergeGroupId,
      mergeBatchId: mergeBatchId ?? this.mergeBatchId,
      mergeBatchTotalAmount:
          mergeBatchTotalAmount ?? this.mergeBatchTotalAmount,
      mergeBatchNote: mergeBatchNote ?? this.mergeBatchNote,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'project_id': effectiveProjectId,
      'project_key': projectKey,
      'ymd': ymd,
      'amount': amount,
      'amount_fen': amountFen,
      'note': note,
      'source_type': sourceType,
      'merge_group_id': mergeGroupId,
      'merge_batch_id': mergeBatchId,
      'merge_batch_total_amount': mergeBatchTotalAmount,
      'merge_batch_total_amount_fen': mergeBatchTotalAmountFen,
      'merge_batch_note': mergeBatchNote,
      'created_at': createdAt,
    };
  }

  static AccountPayment fromMap(Map<String, Object?> m) {
    // 读优先 fen：amount_fen 为权威口径，缺失时才回退 REAL amount。
    // amount REAL 是 legacy / 展示兼容列，保留不移除（NOT NULL 重建 = B1，未做）。
    final amountFen = _readFen(m['amount_fen']);
    final mergeBatchTotalAmountFen = _readFen(
      m['merge_batch_total_amount_fen'],
    );
    return AccountPayment(
      id: m['id'] as int?,
      projectId: (m['project_id'] as String?) ?? '',
      projectKey: (m['project_key'] as String?) ?? '',
      ymd: (m['ymd'] as int?) ?? 0,
      amount: amountFen == null
          ? (m['amount'] as num?)?.toDouble() ?? 0.0
          : _fenToYuan(amountFen),
      note: m['note'] as String?,
      sourceType:
          (m['source_type'] as String?) ?? AccountPayment.sourceTypeManual,
      mergeGroupId: m['merge_group_id'] as int?,
      mergeBatchId: m['merge_batch_id'] as String?,
      mergeBatchTotalAmount: mergeBatchTotalAmountFen == null
          ? (m['merge_batch_total_amount'] as num?)?.toDouble()
          : _fenToYuan(mergeBatchTotalAmountFen),
      mergeBatchNote: m['merge_batch_note'] as String?,
      createdAt: m['created_at'] as String?,
    );
  }

  int get amountFen => _yuanToFen(amount);

  int? get mergeBatchTotalAmountFen {
    final value = mergeBatchTotalAmount;
    return value == null ? null : _yuanToFen(value);
  }

  String get effectiveProjectId {
    return ProjectId.ensure(projectId: projectId, legacyProjectKey: projectKey);
  }
}

int _yuanToFen(num value) => (value * 100).round();

double _fenToYuan(int value) => value / 100.0;

int? _readFen(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}
