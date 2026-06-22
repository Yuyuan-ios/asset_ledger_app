import 'package:flutter/foundation.dart';

import '../../infrastructure/sync/remote_change_applier.dart';
import '../../infrastructure/sync/sync_conflict_repository.dart';
import '../../infrastructure/sync/sync_conflict_resolution_use_case.dart';

class SyncConflictReviewItem {
  const SyncConflictReviewItem({
    required this.conflict,
    required this.remote,
    required this.local,
  });

  final SyncConflict conflict;
  final TimingConflictSummary remote;
  final TimingConflictSummary? local;
}

class TimingConflictSummary {
  const TimingConflictSummary({
    required this.deviceId,
    required this.startDate,
    required this.hours,
    required this.incomeFen,
    this.deleted = false,
  });

  final int deviceId;
  final int startDate;
  final double hours;
  final int incomeFen;
  final bool deleted;

  String get dateLabel {
    final raw = startDate.toString().padLeft(8, '0');
    return '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)}';
  }

  String get hoursLabel {
    final fixed = hours.toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String get amountLabel => (incomeFen / 100).toStringAsFixed(2);
}

abstract class TimingConflictSummaryReader {
  Future<TimingConflictSummary?> localSummary(SyncConflict conflict);

  TimingConflictSummary remoteSummary(SyncConflict conflict);
}

class SyncConflictReviewController extends ChangeNotifier {
  SyncConflictReviewController({
    SyncConflictRepository conflictRepository =
        const LocalSyncConflictRepository(),
    required TimingConflictSummaryReader summaryReader,
    SyncConflictResolver? conflictResolver,
  }) : _conflictRepository = conflictRepository,
       _summaryReader = summaryReader,
       _conflictResolver = conflictResolver ?? SyncConflictResolutionUseCase();

  final SyncConflictRepository _conflictRepository;
  final TimingConflictSummaryReader _summaryReader;
  final SyncConflictResolver _conflictResolver;

  var _isLoading = false;
  String? _error;
  List<SyncConflictReviewItem> _items = const [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<SyncConflictReviewItem> get items => List.unmodifiable(_items);

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final conflicts = await _conflictRepository.listPending();
      final items = <SyncConflictReviewItem>[];
      for (final conflict in conflicts) {
        if (conflict.entityType != TimingRecordRemoteChangeApplier.entityType) {
          continue;
        }
        items.add(
          SyncConflictReviewItem(
            conflict: conflict,
            local: await _summaryReader.localSummary(conflict),
            remote: _summaryReader.remoteSummary(conflict),
          ),
        );
      }
      _items = List.unmodifiable(items);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> useRemote(SyncConflictReviewItem item) async {
    await _conflictResolver.useRemote(item.conflict);
    _remove(item.conflict.id);
  }

  Future<void> useLocal(SyncConflictReviewItem item) async {
    await _conflictResolver.useLocal(item.conflict);
    _remove(item.conflict.id);
  }

  void _remove(String conflictId) {
    _items = List.unmodifiable(
      _items.where((item) => item.conflict.id != conflictId),
    );
    notifyListeners();
  }
}
