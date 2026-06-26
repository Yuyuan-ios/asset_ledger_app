import '../../../data/models/timing_record.dart';
import '../../../data/repositories/timing_repository.dart';
import '../../../data/services/subscription_service.dart';
import '../../../core/utils/base_store.dart';
import '../use_cases/save_timing_record_with_impact_use_case.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';

class TimingStore extends BaseStore {
  TimingStore(
    this._repository, {
    bool Function(int currentCount)? canCreateMoreTimingRecords,
  }) : _canCreateMoreTimingRecords =
           canCreateMoreTimingRecords ??
           SubscriptionService.canCreateMoreTimingRecords;

  final TimingRepository _repository;
  final bool Function(int currentCount) _canCreateMoreTimingRecords;

  // -------------------------------------------------------------------
  // 核心数据
  // -------------------------------------------------------------------
  List<TimingRecord> _records = [];
  var _hasLoaded = false;

  List<TimingRecord> get records => List.unmodifiable(_records);

  Future<void> _reload() async {
    _records = await _repository.listAll();
    _hasLoaded = true;
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

  /// Legacy internal write helper.
  ///
  /// Production UI saves should use SaveTimingRecordWithImpactUseCase so
  /// project impact, sync outbox, and the Free timing-record limit stay in one
  /// transaction. This fallback still fail-closes ordinary creates at the Free
  /// 30-record limit so old tests/internal callers cannot bypass entitlement.
  Future<void> save(
    TimingRecord record, {
    List<TimingCalculationHistory> calculationHistories = const [],
  }) async {
    await _ensureCanCreateTimingRecord(record);
    await writeAndPatchLocalState<TimingRecord>(
      write: () async {
        return _repository.saveWithCalculationHistories(
          record,
          calculationHistories: calculationHistories,
        );
      },
      patch: (savedRecord) {
        final recordId = savedRecord.id;
        final index = _records.indexWhere((item) => item.id == recordId);
        if (index == -1) {
          _records = [..._records, savedRecord];
        } else {
          final updated = [..._records];
          updated[index] = savedRecord;
          _records = updated;
        }
        _sortRecords();
      },
    );
  }

  Future<void> _ensureCanCreateTimingRecord(TimingRecord record) async {
    if (record.id != null) return;
    final currentCount = _hasLoaded
        ? _records.length
        : (await _repository.listAll()).length;
    if (_canCreateMoreTimingRecords(currentCount)) return;
    throw TimingRecordLimitExceededException(currentCount: currentCount);
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

  Future<void> deleteByIds(Iterable<int> ids) async {
    final uniqueIds = ids.toSet();
    if (uniqueIds.isEmpty) return;

    await writeAndPatchLocalState(
      write: () => _repository.deleteByIds(uniqueIds),
      patch: (_) {
        _records = _records
            .where((item) => item.id == null || !uniqueIds.contains(item.id))
            .toList();
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
