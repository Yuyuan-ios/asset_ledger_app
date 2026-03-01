// =====================================================================
// ============================== ProjectKey（项目键） ==============================
// =====================================================================
//
// 口径：项目展示名 = 联系人 + 工地
// - 用一个“稳定 key”做持久化与关联（payment / rates 都用它）
//
// 约定：key = "$contact||$site"
// - 用不常见分隔符，避免用户输入碰撞
// =====================================================================

class ProjectKey {
  final String contact;
  final String site;

  const ProjectKey({required this.contact, required this.site});

  String get key => '${contact.trim()}||${site.trim()}';

  String get displayName => '${contact.trim()} + ${site.trim()}';

  static ProjectKey fromKey(String key) {
    final parts = key.split('||');
    final c = parts.isNotEmpty ? parts[0] : '';
    final s = parts.length >= 2 ? parts[1] : '';
    return ProjectKey(contact: c, site: s);
  }

  static String buildKey({required String contact, required String site}) {
    return ProjectKey(contact: contact, site: site).key;
  }
}
