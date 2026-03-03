import '../models/fuel_log.dart';
import 'suggest_service.dart';

class FuelSuggestService {
  static List<String> supplierCandidates(List<FuelLog> logs) {
    final raw = <String>[];
    for (final log in logs) {
      raw.add(log.supplier);
    }
    return SuggestService.uniqueHistory(raw);
  }

  static List<String> supplierSuggestions(
    List<FuelLog> logs,
    String query, {
    int limit = 12,
  }) {
    return SuggestService.suggestStrings(
      history: supplierCandidates(logs),
      query: query,
      limit: limit,
    );
  }
}
