import '../../../data/models/timing_record.dart';
import '../../../data/repositories/timing_repository.dart';
import '../../../core/utils/base_store.dart';

class TimingStore extends BaseStore {
  TimingStore(this._repository);

  final TimingRepository _repository;

  // -------------------------------------------------------------------
  // 核心数据
  // -------------------------------------------------------------------
  List<TimingRecord> _records = [];

  List<TimingRecord> get records => List.unmodifiable(_records);

  Future<void> _reload() async {
    _records = await _repository.listAll();
  }

  void _sortRecords() {
    _records.sort((a, b) {
      final byDate = b.startDate.compareTo(a.startDate);
      if (byDate != 0) return byDate;
      return (b.id ?? 0).compareTo(a.id ?? 0);
    });
  }

  // =====================================================================
  // 读：loadAll
  // =====================================================================

  Future<void> loadAll() async {
    await run(() async {
      await _reload();
    });
  }

  // =====================================================================
  // 写：save（insert / update）
  // =====================================================================

  Future<void> save(TimingRecord record) async {
    await writeAndPatchLocalState(
      write: () async {
        if (record.id == null) {
          return await _repository.insert(record);
        }
        await _repository.update(record);
        return record.id!;
      },
      patch: (recordId) {
        final next = record.copyWith(id: recordId);
        final index = _records.indexWhere((item) => item.id == recordId);
        if (index == -1) {
          _records = [..._records, next];
        } else {
          final updated = [..._records];
          updated[index] = next;
          _records = updated;
        }
        _sortRecords();
      },
    );
  }

  // =====================================================================
  // 删：按 id
  // =====================================================================

  Future<void> deleteById(int id) async {
    await writeAndPatchLocalState(
      write: () => _repository.deleteById(id),
      patch: (_) {
        _records = _records.where((item) => item.id != id).toList();
      },
    );
  }

  // =====================================================================
  // 删：按 deviceId（设备页级联）
  // =====================================================================

  Future<void> deleteByDeviceId(int deviceId) async {
    await writeAndPatchLocalState(
      write: () => _repository.deleteByDeviceId(deviceId),
      patch: (_) {
        _records = _records.where((item) => item.deviceId != deviceId).toList();
      },
    );
  }
}
