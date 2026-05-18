import 'dart:convert';
import 'dart:math';

import 'project_key.dart';

class ProjectId {
  static const String legacyPrefix = 'legacy:';
  static final Random _secureRandom = Random.secure();

  const ProjectId._();

  static String create() {
    final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
    final token = base64Url.encode(bytes).replaceAll('=', '');
    return 'project:$token';
  }

  static String legacyFromKey(String projectKey) {
    final normalized = projectKey.trim();
    if (normalized.isEmpty) return '$legacyPrefix${base64Url.encode(const [])}';
    return '$legacyPrefix${base64Url.encode(utf8.encode(normalized))}';
  }

  static String legacyFromParts({
    required String contact,
    required String site,
  }) {
    return legacyFromKey(ProjectKey.buildKey(contact: contact, site: site));
  }

  static String ensure({String? projectId, required String legacyProjectKey}) {
    final normalized = projectId?.trim() ?? '';
    if (normalized.isNotEmpty) return normalized;
    return legacyFromKey(legacyProjectKey);
  }
}
