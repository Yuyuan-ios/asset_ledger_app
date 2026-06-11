import 'dart:convert';

/// 结清确认快照（《机账通商业与实现纲要》§6.3）。
///
/// 在项目状态置为 settled 的同一确认动作中持久化到
/// projects.settled_snapshot,记录结清那一刻的 fen 口径结果——之后上游
/// 记录/单价/收款再变化,这份数字不漂移,可供审计对照。
/// revoke（撤销结清）时整列清 null,重新结清时重建新快照（作废重建,
/// 不原地改写）。
class ProjectSettledSnapshot {
  /// 快照自身的口径版本。字段语义变化时 bump,解析端按版本兼容。
  static const int schemaVersion = 1;

  /// 结清判定所用的项目应收（整数分）。
  final int receivableFen;

  /// 结清时点的累计已收（整数分）。
  final int receivedFen;

  /// 结清时点的累计核销/抵扣（整数分,含本次结清动作写入的核销）。
  final int writeOffFen;

  /// 结清时点的剩余待收（整数分,结清语义下恒 <= 0）。
  final int remainingFen;

  /// 结清时间（ISO-8601,与 projects.settled_at 同值）。
  final String settledAt;

  const ProjectSettledSnapshot({
    required this.receivableFen,
    required this.receivedFen,
    required this.writeOffFen,
    required this.remainingFen,
    required this.settledAt,
  });

  /// 序列化为 settled_snapshot 列的 JSON 文本。
  String encode() {
    return jsonEncode({
      'snapshot_schema_version': schemaVersion,
      'receivable_fen': receivableFen,
      'received_fen': receivedFen,
      'write_off_fen': writeOffFen,
      'remaining_fen': remainingFen,
      'settled_at': settledAt,
    });
  }

  /// 防御式解析:非 JSON / 字段缺失 / 类型不符一律返回 null,由调用方
  /// 决定回退口径(legacy 结清行本就无快照),不抛异常。
  static ProjectSettledSnapshot? tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;
    final receivableFen = decoded['receivable_fen'];
    final receivedFen = decoded['received_fen'];
    final writeOffFen = decoded['write_off_fen'];
    final remainingFen = decoded['remaining_fen'];
    final settledAt = decoded['settled_at'];
    if (receivableFen is! int ||
        receivedFen is! int ||
        writeOffFen is! int ||
        remainingFen is! int ||
        settledAt is! String) {
      return null;
    }
    return ProjectSettledSnapshot(
      receivableFen: receivableFen,
      receivedFen: receivedFen,
      writeOffFen: writeOffFen,
      remainingFen: remainingFen,
      settledAt: settledAt,
    );
  }
}
