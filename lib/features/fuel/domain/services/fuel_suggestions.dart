import '../entities/fuel_entities.dart';

class FuelSuggestions {
  const FuelSuggestions._();

  static List<String> supplierCandidates(List<FuelLog> logs) {
    final seen = <String>{};
    final results = <String>[];
    for (final log in logs) {
      final supplier = log.supplier.trim();
      if (supplier.isEmpty) continue;
      final key = supplier.toLowerCase();
      if (!seen.add(key)) continue;
      results.add(supplier);
    }
    return results;
  }

  static List<String> supplierSuggestions(
    List<FuelLog> logs,
    String query, {
    int limit = 12,
  }) {
    final normalized = query.trim().toLowerCase();
    final candidates = supplierCandidates(logs);
    if (normalized.isEmpty) {
      return candidates.take(limit).toList(growable: false);
    }

    final prefix = <String>[];
    final contains = <String>[];
    for (final item in candidates) {
      final key = item.toLowerCase();
      if (key.startsWith(normalized)) {
        prefix.add(item);
      } else if (key.contains(normalized)) {
        contains.add(item);
      }
    }
    return [...prefix, ...contains].take(limit).toList(growable: false);
  }
}
