/// Port owned by the timing domain: saving a timing record may need to
/// dissolve a stale merge group when the resolved project_id changes.
/// Timing depends on this abstraction, not on the concrete account service.
abstract class TimingMergeDissolvePort {
  Future<bool> dissolveMergeGroupIfProjectIdChanged({
    required String oldProjectId,
    required String newProjectId,
  });
}
