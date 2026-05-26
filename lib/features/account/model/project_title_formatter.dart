import '../../../core/utils/display_text_formatter.dart';
import '../../../data/models/project_key.dart';

/// Centralized user-visible project title formatting.
///
/// Keep project identity strings (`projectKey`, `legacyProjectKey`, ids) out of
/// this helper; it only formats display text.
class ProjectTitleFormatter {
  const ProjectTitleFormatter._();

  static const String separator = DisplayTextFormatter.separator;
  static const String unnamedProject = '未命名项目';

  static String project({required String contact, required String site}) {
    final normalizedContact = contact.trim();
    final normalizedSite = site.trim();
    return DisplayTextFormatter.joinParts([
      normalizedContact,
      normalizedSite,
    ], fallback: unnamedProject);
  }

  static String fromProjectKey(String projectKey) {
    final key = ProjectKey.fromKey(projectKey);
    return project(contact: key.contact, site: key.site);
  }

  static String merged({required String contact, required int count}) {
    final label = mergedLabel(count);
    final normalizedContact = contact.trim();
    return DisplayTextFormatter.joinParts([normalizedContact, label]);
  }

  static String mergedLabel(int count) {
    final safeCount = count < 0 ? 0 : count;
    return '合并$safeCount项目';
  }

  /// Normalizes legacy UI-only titles like `联系人 + 地址`,
  /// `联系人•地址 + 关联`, or `联系人 · 地址 + 关联`.
  static String normalize(String displayName) {
    final stripped = _stripLinkedCopy(displayName.trim());
    if (stripped.isEmpty) return unnamedProject;
    if (stripped.contains(separator)) return stripped;

    final bulletParts = _splitNonEmpty(stripped, '•');
    if (bulletParts.length > 1) return _joinParts(bulletParts);

    final plusParts = _splitNonEmpty(stripped, ' + ');
    if (plusParts.length > 1) return _joinParts(plusParts);

    return stripped;
  }

  static String _joinParts(List<String> parts) {
    if (parts.isEmpty) return unnamedProject;
    if (parts.length == 1) return parts.single;
    return '${parts.first}$separator${parts.skip(1).join('、')}';
  }

  static List<String> _splitNonEmpty(String value, String separator) {
    return value
        .split(separator)
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
  }

  static String _stripLinkedCopy(String value) {
    var next = value;
    const suffixes = [' + 关联', '+关联', '（已关联）', '(已关联)', ' 已关联', ' 关联'];
    for (final suffix in suffixes) {
      if (next.endsWith(suffix)) {
        next = next.substring(0, next.length - suffix.length).trim();
      }
    }
    return next;
  }
}
