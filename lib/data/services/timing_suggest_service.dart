import '../models/timing_record.dart';
import 'suggest_service.dart';

class TimingSuggestService {
  static List<String> contactCandidates(List<TimingRecord> records) {
    final raw = <String>[];
    for (final record in records) {
      raw.add(record.contact);
    }
    return SuggestService.uniqueHistory(raw);
  }

  static List<String> contactSuggestions(
    List<TimingRecord> records,
    String query,
  ) {
    return SuggestService.suggestStrings(
      history: contactCandidates(records),
      query: query,
      limit: 12,
    );
  }

  static List<String> siteCandidates(List<TimingRecord> records) {
    final raw = <String>[];
    for (final record in records) {
      raw.add(record.site);
    }
    return SuggestService.uniqueHistory(raw);
  }

  static List<String> siteSuggestions(List<TimingRecord> records, String query) {
    return SuggestService.suggestStrings(
      history: siteCandidates(records),
      query: query,
      limit: 12,
    );
  }
}
