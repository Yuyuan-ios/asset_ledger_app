enum ProjectWriteOffReason {
  rounding,
  qualityDeduction,
  underpaid,
  badDebt,
  settlement,
  offset,
  other,
}

extension ProjectWriteOffReasonX on ProjectWriteOffReason {
  String get dbValue {
    switch (this) {
      case ProjectWriteOffReason.rounding:
        return 'rounding';
      case ProjectWriteOffReason.qualityDeduction:
        return 'quality_deduction';
      case ProjectWriteOffReason.underpaid:
        return 'underpaid';
      case ProjectWriteOffReason.badDebt:
        return 'bad_debt';
      case ProjectWriteOffReason.settlement:
        return 'settlement';
      case ProjectWriteOffReason.offset:
        return 'offset';
      case ProjectWriteOffReason.other:
        return 'other';
    }
  }

  static ProjectWriteOffReason fromDbValue(String value) {
    switch (value) {
      case 'rounding':
        return ProjectWriteOffReason.rounding;
      case 'quality_deduction':
        return ProjectWriteOffReason.qualityDeduction;
      case 'underpaid':
        return ProjectWriteOffReason.underpaid;
      case 'bad_debt':
        return ProjectWriteOffReason.badDebt;
      case 'settlement':
        return ProjectWriteOffReason.settlement;
      case 'offset':
        return ProjectWriteOffReason.offset;
      case 'other':
        return ProjectWriteOffReason.other;
      default:
        return ProjectWriteOffReason.other;
    }
  }

  static bool isKnownDbValue(String value) {
    return ProjectWriteOffReason.values.any(
      (reason) => reason.dbValue == value,
    );
  }
}

class ProjectWriteOff {
  const ProjectWriteOff({
    required this.id,
    required this.projectId,
    required this.amount,
    required this.reason,
    this.note,
    required this.writeOffDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final double amount;
  final String reason;
  final String? note;
  final String writeOffDate;
  final String createdAt;
  final String updatedAt;

  ProjectWriteOff copyWith({
    String? id,
    String? projectId,
    double? amount,
    String? reason,
    Object? note = _sentinel,
    String? writeOffDate,
    String? createdAt,
    String? updatedAt,
  }) {
    return ProjectWriteOff(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      note: identical(note, _sentinel) ? this.note : note as String?,
      writeOffDate: writeOffDate ?? this.writeOffDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'amount': amount,
      'amount_fen': amountFen,
      'reason': reason,
      'note': note,
      'write_off_date': writeOffDate,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  static ProjectWriteOff fromMap(Map<String, Object?> map) {
    final amountFen = _readFen(map['amount_fen']);
    return ProjectWriteOff(
      id: (map['id'] as String?) ?? '',
      projectId: (map['project_id'] as String?) ?? '',
      amount: amountFen == null
          ? (map['amount'] as num?)?.toDouble() ?? 0.0
          : _fenToYuan(amountFen),
      reason: (map['reason'] as String?) ?? '',
      note: map['note'] as String?,
      writeOffDate: (map['write_off_date'] as String?) ?? '',
      createdAt: (map['created_at'] as String?) ?? '',
      updatedAt: (map['updated_at'] as String?) ?? '',
    );
  }

  int get amountFen => _yuanToFen(amount);
}

const _sentinel = Object();

int _yuanToFen(num value) => (value * 100).round();

double _fenToYuan(int value) => value / 100.0;

int? _readFen(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}
