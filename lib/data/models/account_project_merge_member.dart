class AccountProjectMergeMember {
  final int? id;
  final int groupId;
  final String projectKey;
  final String contact;
  final String site;
  final int sortOrder;
  final String createdAt;
  final bool isActive;

  const AccountProjectMergeMember({
    this.id,
    required this.groupId,
    required this.projectKey,
    required this.contact,
    required this.site,
    required this.sortOrder,
    required this.createdAt,
    this.isActive = true,
  });

  AccountProjectMergeMember copyWith({
    int? id,
    int? groupId,
    String? projectKey,
    String? contact,
    String? site,
    int? sortOrder,
    String? createdAt,
    bool? isActive,
  }) {
    return AccountProjectMergeMember(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      projectKey: projectKey ?? this.projectKey,
      contact: contact ?? this.contact,
      site: site ?? this.site,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'project_key': projectKey,
      'contact': contact,
      'site': site,
      'sort_order': sortOrder,
      'created_at': createdAt,
      'is_active': isActive ? 1 : 0,
    };
  }

  static AccountProjectMergeMember fromMap(Map<String, Object?> map) {
    return AccountProjectMergeMember(
      id: map['id'] as int?,
      groupId: (map['group_id'] as int?) ?? 0,
      projectKey: (map['project_key'] as String?) ?? '',
      contact: (map['contact'] as String?) ?? '',
      site: (map['site'] as String?) ?? '',
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: (map['created_at'] as String?) ?? '',
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
    );
  }
}
