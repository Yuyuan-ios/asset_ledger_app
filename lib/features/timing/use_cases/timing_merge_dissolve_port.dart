import '../../../data/services/account_project_merge_service.dart';

/// Port owned by the timing domain: saving a timing record may need to
/// dissolve a stale merge group when the resolved project_id changes.
/// Timing depends on this abstraction, not on the concrete account service.
abstract class TimingMergeDissolvePort {
  Future<bool> dissolveMergeGroupIfProjectIdChanged({
    required String oldProjectId,
    required String newProjectId,
  });
}

/// Composition-boundary adapter that satisfies [TimingMergeDissolvePort]
/// by delegating to the concrete account merge service.
class AccountMergeDissolveAdapter implements TimingMergeDissolvePort {
  const AccountMergeDissolveAdapter(this._mergeService);

  final AccountProjectMergeService _mergeService;

  @override
  Future<bool> dissolveMergeGroupIfProjectIdChanged({
    required String oldProjectId,
    required String newProjectId,
  }) {
    return _mergeService.dissolveMergeGroupIfProjectIdChanged(
      oldProjectId: oldProjectId,
      newProjectId: newProjectId,
    );
  }
}
