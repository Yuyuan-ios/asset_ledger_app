class AccountProjectMergeGroup {
  final int? id;
  final String contact;
  final String createdAt;
  final String? updatedAt;
  final bool isActive;
  final String? dissolvedAt;
  final String sourceType;

  const AccountProjectMergeGroup({
    this.id,
    required this.contact,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.dissolvedAt,
    this.sourceType = 'local',
  });

  AccountProjectMergeGroup copyWith({
    int? id,
    String? contact,
    String? createdAt,
    String? updatedAt,
    bool? isActive,
    String? dissolvedAt,
    String? sourceType,
  }) {
    return AccountProjectMergeGroup(
      id: id ?? this.id,
      contact: contact ?? this.contact,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      dissolvedAt: dissolvedAt ?? this.dissolvedAt,
      sourceType: sourceType ?? this.sourceType,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'contact': contact,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_active': isActive ? 1 : 0,
      'dissolved_at': dissolvedAt,
      'source_type': sourceType,
    };
  }

  static AccountProjectMergeGroup fromMap(Map<String, Object?> map) {
    return AccountProjectMergeGroup(
      id: map['id'] as int?,
      contact: (map['contact'] as String?) ?? '',
      createdAt: (map['created_at'] as String?) ?? '',
      updatedAt: map['updated_at'] as String?,
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      dissolvedAt: map['dissolved_at'] as String?,
      sourceType: (map['source_type'] as String?) ?? 'local',
    );
  }
}
