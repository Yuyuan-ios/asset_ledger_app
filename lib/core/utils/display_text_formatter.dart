/// Shared helpers for compact, user-visible display text.
class DisplayTextFormatter {
  const DisplayTextFormatter._();

  static const String separator = ' · ';

  static String joinParts(Iterable<String?> parts, {String fallback = ''}) {
    final normalized = parts
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (normalized.isEmpty) return fallback;
    return normalized.join(separator);
  }
}
