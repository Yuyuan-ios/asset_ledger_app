import 'dart:convert';

// =====================================================================
// ============================== ProjectKey（旧项目键） ==============================
// =====================================================================
//
// 口径：项目展示名 = 联系人 + 工地。
// - 仅用于旧数据 / 旧备份 / display fallback 的兼容映射。
// - 新业务身份必须使用 projects.id / project_id。
//
// 约定：key = "$contact||$site"
// - 含分隔符时用带前缀的 base64url 片段转义。
// =====================================================================

class ProjectKey {
  static const String _separator = '||';
  static const String _encodedPrefix = '~b64:';

  final String contact;
  final String site;

  const ProjectKey({required this.contact, required this.site});

  String get key =>
      '${_encodePart(contact.trim())}$_separator${_encodePart(site.trim())}';

  String get displayName => '${contact.trim()} + ${site.trim()}';

  static ProjectKey fromKey(String key) {
    final parts = key.split(_separator);
    final c = parts.isNotEmpty ? _decodePart(parts[0]) : '';
    final s = parts.length >= 2 ? _decodePart(parts[1]) : '';
    return ProjectKey(contact: c, site: s);
  }

  static String buildKey({required String contact, required String site}) {
    return ProjectKey(contact: contact, site: site).key;
  }

  static String _encodePart(String value) {
    if (!value.contains(_separator) && !value.startsWith(_encodedPrefix)) {
      return value;
    }
    return '$_encodedPrefix${base64Url.encode(utf8.encode(value))}';
  }

  static String _decodePart(String value) {
    if (!value.startsWith(_encodedPrefix)) return value;
    try {
      final payload = value.substring(_encodedPrefix.length);
      return utf8.decode(base64Url.decode(payload));
    } on FormatException {
      return value;
    }
  }
}
