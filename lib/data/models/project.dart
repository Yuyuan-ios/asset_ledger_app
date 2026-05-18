import 'project_id.dart';
import 'project_key.dart';

enum ProjectStatus { active, settled, archived, voided }

class Project {
  final String id;
  final String contact;
  final String site;
  final ProjectStatus status;
  final String? settledAt;
  final String? settledSnapshot;
  final String createdAt;
  final String updatedAt;
  final String? legacyProjectKey;

  const Project({
    required this.id,
    required this.contact,
    required this.site,
    this.status = ProjectStatus.active,
    this.settledAt,
    this.settledSnapshot,
    required this.createdAt,
    required this.updatedAt,
    this.legacyProjectKey,
  });

  factory Project.legacy({
    required String contact,
    required String site,
    required String timestamp,
  }) {
    final key = ProjectKey.buildKey(contact: contact, site: site);
    return Project(
      id: ProjectId.legacyFromKey(key),
      contact: contact.trim(),
      site: site.trim(),
      status: ProjectStatus.active,
      createdAt: timestamp,
      updatedAt: timestamp,
      legacyProjectKey: key,
    );
  }

  Project copyWith({
    String? id,
    String? contact,
    String? site,
    ProjectStatus? status,
    Object? settledAt = _sentinel,
    Object? settledSnapshot = _sentinel,
    String? createdAt,
    String? updatedAt,
    Object? legacyProjectKey = _sentinel,
  }) {
    return Project(
      id: id ?? this.id,
      contact: contact ?? this.contact,
      site: site ?? this.site,
      status: status ?? this.status,
      settledAt: identical(settledAt, _sentinel)
          ? this.settledAt
          : settledAt as String?,
      settledSnapshot: identical(settledSnapshot, _sentinel)
          ? this.settledSnapshot
          : settledSnapshot as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      legacyProjectKey: identical(legacyProjectKey, _sentinel)
          ? this.legacyProjectKey
          : legacyProjectKey as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'contact': contact,
      'site': site,
      'status': status.name,
      'settled_at': settledAt,
      'settled_snapshot': settledSnapshot,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'legacy_project_key': legacyProjectKey,
    };
  }

  static Project fromMap(Map<String, Object?> map) {
    final contact = (map['contact'] as String?) ?? '';
    final site = (map['site'] as String?) ?? '';
    final legacyKey =
        map['legacy_project_key'] as String? ??
        ProjectKey.buildKey(contact: contact, site: site);
    final timestamp =
        (map['created_at'] as String?) ??
        DateTime(1970).toUtc().toIso8601String();
    return Project(
      id: (map['id'] as String?) ?? ProjectId.legacyFromKey(legacyKey),
      contact: contact,
      site: site,
      status: _parseStatus(map['status']),
      settledAt: map['settled_at'] as String?,
      settledSnapshot: map['settled_snapshot'] as String?,
      createdAt: timestamp,
      updatedAt: (map['updated_at'] as String?) ?? timestamp,
      legacyProjectKey: legacyKey,
    );
  }

  static ProjectStatus _parseStatus(Object? value) {
    if (value is String) {
      for (final status in ProjectStatus.values) {
        if (status.name == value) return status;
      }
    }
    return ProjectStatus.active;
  }
}

const _sentinel = Object();
