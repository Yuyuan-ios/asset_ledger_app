import '../../../core/utils/base_store.dart';
import '../../../data/models/external_import_batch.dart';
import '../../../data/models/external_work_record.dart';
import '../../../data/repositories/external_import_repository.dart';
import '../../../data/repositories/external_work_record_repository.dart';

class TimingExternalWorkRecordItem {
  const TimingExternalWorkRecordItem({required this.record, this.batch});

  final ExternalWorkRecord record;
  final ExternalImportBatch? batch;

  String get displayName {
    final batchName = batch?.sourceDisplayName.trim();
    if (batchName != null && batchName.isNotEmpty) return batchName;

    final collaborator = record.collaboratorName.trim();
    if (collaborator.isNotEmpty) return collaborator;

    return '外协分享记录';
  }

  bool get isLinked => record.linkedProjectId?.trim().isNotEmpty == true;
}

class TimingExternalWorkStore extends BaseStore {
  TimingExternalWorkStore({
    required ExternalImportRepository importRepository,
    required ExternalWorkRecordRepository recordRepository,
  }) : _importRepository = importRepository,
       _recordRepository = recordRepository;

  final ExternalImportRepository _importRepository;
  final ExternalWorkRecordRepository _recordRepository;

  List<TimingExternalWorkRecordItem> _items = [];

  List<TimingExternalWorkRecordItem> get items => List.unmodifiable(_items);

  Future<void> loadAll() async {
    await run(() async {
      final batches = await _importRepository.listBatches();
      final batchById = <String, ExternalImportBatch>{
        for (final batch in batches) batch.id: batch,
      };
      final items = <TimingExternalWorkRecordItem>[];

      for (final batch in batches) {
        final records = await _recordRepository.listByBatchId(batch.id);
        for (final record in records) {
          items.add(
            TimingExternalWorkRecordItem(
              record: record,
              batch: batchById[record.importBatchId],
            ),
          );
        }
      }

      items.sort((a, b) {
        final byDate = b.record.workDate.compareTo(a.record.workDate);
        if (byDate != 0) return byDate;
        return b.record.createdAt.compareTo(a.record.createdAt);
      });
      _items = items;
    });
  }
}
