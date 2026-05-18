import '../../data/services/account_project_merge_service.dart';
import '../../features/timing/use_cases/timing_merge_dissolve_port.dart';

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
