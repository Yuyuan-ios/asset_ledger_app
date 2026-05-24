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

  Future<void> deleteById(String recordId) async {
    final normalized = recordId.trim();
    if (normalized.isEmpty) return;
    await writeAndPatchLocalState<int>(
      write: () => _recordRepository.deleteById(normalized),
      patch: (deleted) {
        if (deleted == 0) return;
        _items = _items
            .where((item) => item.record.id != normalized)
            .toList(growable: false);
      },
    );
  }

  /// 把整个外协包关联到本地项目：事务化写库后就地更新内存态（同包记录统一）。
  Future<void> linkBatchToProject(String batchId, String projectId) async {
    final normalizedBatch = batchId.trim();
    final normalizedProject = projectId.trim();
    if (normalizedBatch.isEmpty || normalizedProject.isEmpty) return;
    final updatedAt = DateTime.now().toUtc().toIso8601String();
    await writeAndPatchLocalState<int>(
      write: () => _recordRepository.linkBatchToProject(
        importBatchId: normalizedBatch,
        projectId: normalizedProject,
        updatedAt: updatedAt,
      ),
      patch: (count) {
        if (count == 0) return;
        _items = _patchBatchLink(normalizedBatch, normalizedProject);
      },
    );
  }

  /// 解除外协包关联：清空同包记录的 linkedProjectId，外协记录本身保留。
  Future<void> unlinkBatch(String batchId) async {
    final normalizedBatch = batchId.trim();
    if (normalizedBatch.isEmpty) return;
    final updatedAt = DateTime.now().toUtc().toIso8601String();
    await writeAndPatchLocalState<int>(
      write: () => _recordRepository.unlinkBatch(
        importBatchId: normalizedBatch,
        updatedAt: updatedAt,
      ),
      patch: (count) {
        if (count == 0) return;
        _items = _patchBatchLink(normalizedBatch, null);
      },
    );
  }

  List<TimingExternalWorkRecordItem> _patchBatchLink(
    String batchId,
    String? projectId,
  ) {
    return _items
        .map((item) {
          if (item.record.importBatchId != batchId) return item;
          return TimingExternalWorkRecordItem(
            record: item.record.copyWith(linkedProjectId: projectId),
            batch: item.batch,
          );
        })
        .toList(growable: false);
  }

  Future<void> deleteByBatchId(String batchId) async {
    final normalized = batchId.trim();
    if (normalized.isEmpty) return;
    await writeAndPatchLocalState<int>(
      write: () => _recordRepository.deleteByBatchId(normalized),
      patch: (deleted) {
        if (deleted == 0) return;
        _items = _items
            .where((item) => item.record.importBatchId != normalized)
            .toList(growable: false);
      },
    );
  }

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
