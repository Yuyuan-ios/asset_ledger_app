import '../../../data/models/timing_record.dart';
import '../../../data/repositories/timing_repository.dart';
import '../../../data/services/suggest_service.dart';
import '../../../core/utils/base_store.dart';

class TimingStore extends BaseStore {
  // -------------------------------------------------------------------
  // 核心数据
  // -------------------------------------------------------------------
  List<TimingRecord> _records = [];

  List<TimingRecord> get records => List.unmodifiable(_records);

  // =====================================================================
  // 读：loadAll
  // =====================================================================

  Future<void> loadAll() async {
    await run(() async {
      _records = await TimingRepo.listAll();
    });
  }

  // =====================================================================
  // 写：save（insert / update）
  // =====================================================================

  Future<void> save(TimingRecord record) async {
    await run(() async {
      if (record.id == null) {
        await TimingRepo.insert(record);
      } else {
        await TimingRepo.update(record);
      }
      _records = await TimingRepo.listAll();
    });
  }

  // =====================================================================
  // 删：按 id
  // =====================================================================

  Future<void> deleteById(int id) async {
    await run(() async {
      await TimingRepo.deleteById(id);
      _records = await TimingRepo.listAll();
    });
  }

  // =====================================================================
  // 删：按 deviceId（设备页级联）
  // =====================================================================

  Future<void> deleteByDeviceId(int deviceId) async {
    await run(() async {
      await TimingRepo.deleteByDeviceId(deviceId);
      _records = await TimingRepo.listAll();
    });
  }

  // =====================================================================
  // 联想候选（联系人 / 工地）
  // =====================================================================

  List<String> contactCandidates() {
    final raw = <String>[];
    for (final x in _records) {
      raw.add(x.contact);
    }
    return SuggestService.uniqueHistory(raw);
  }

  List<String> contactSuggestions(String query) {
    return SuggestService.suggestStrings(
      history: contactCandidates(),
      query: query,
      limit: 12,
    );
  }

  List<String> siteCandidates() {
    final raw = <String>[];
    for (final x in _records) {
      raw.add(x.site);
    }
    return SuggestService.uniqueHistory(raw);
  }

  List<String> siteSuggestions(String query) {
    return SuggestService.suggestStrings(
      history: siteCandidates(),
      query: query,
      limit: 12,
    );
  }
}
