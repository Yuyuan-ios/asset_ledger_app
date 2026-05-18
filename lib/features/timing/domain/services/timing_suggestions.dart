import '../entities/timing_entities.dart';

class TimingSuggestions {
  const TimingSuggestions._();

  static List<String> contactSuggestions(
    List<TimingRecord> records,
    String query,
  ) {
    return _suggest(records.map((record) => record.contact), query, limit: 12);
  }

  static List<String> siteSuggestions(
    List<TimingRecord> records,
    String query,
  ) {
    return _suggest(records.map((record) => record.site), query, limit: 12);
  }

  static List<String> _suggest(
    Iterable<String> raw,
    String query, {
    required int limit,
  }) {
    final seen = <String>{};
    final candidates = <String>[];
    for (final value in raw) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      if (!seen.add(trimmed.toLowerCase())) continue;
      candidates.add(trimmed);
    }

    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return candidates.take(limit).toList(growable: false);
    }

    final prefix = <String>[];
    final contains = <String>[];
    for (final value in candidates) {
      final key = value.toLowerCase();
      if (key.startsWith(normalized)) {
        prefix.add(value);
      } else if (key.contains(normalized)) {
        contains.add(value);
      }
    }
    return [...prefix, ...contains].take(limit).toList(growable: false);
  }
}
