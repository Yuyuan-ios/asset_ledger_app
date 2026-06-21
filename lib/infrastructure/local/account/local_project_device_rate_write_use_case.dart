import '../../../data/db/database.dart';
import '../../../data/models/project_device_rate.dart';
import '../../../data/repositories/project_rate_repository.dart';
import '../../../features/account/use_cases/project_device_rate_write_use_case.dart';
import '../../sync/sync_actor.dart';
import '../../sync/sync_repositories.dart';
import 'project_device_rate_sync_enqueuer.dart';

class LocalProjectDeviceRateWriteUseCase
    implements ProjectDeviceRateWriteUseCase {
  LocalProjectDeviceRateWriteUseCase({
    required SqfliteProjectRateRepository projectRateRepository,
    SyncOutboxRepository? syncOutboxRepository,
    EntitySyncMetaRepository? entitySyncMetaRepository,
    ProjectDeviceRateSyncEnqueuer? syncEnqueuer,
    SyncActorProvider? actorProvider,
  }) : _projectRateRepository = projectRateRepository,
       _syncEnqueuer =
           syncEnqueuer ??
           ProjectDeviceRateSyncEnqueuer(
             syncOutboxRepository: syncOutboxRepository,
             entitySyncMetaRepository: entitySyncMetaRepository,
           ),
       _actorProvider = actorProvider;

  final SqfliteProjectRateRepository _projectRateRepository;
  final ProjectDeviceRateSyncEnqueuer _syncEnqueuer;
  final SyncActorProvider? _actorProvider;

  @override
  Future<void> upsert(ProjectDeviceRate rate) async {
    await AppDatabase.inTransaction((txn) async {
      await _projectRateRepository.upsertWithExecutor(txn, rate);
      await _syncEnqueuer.enqueueUpsert(
        txn,
        rate: rate,
        actor: _actorProvider?.call(),
      );
    });
  }

  @override
  Future<int> delete(
    String projectKey,
    int deviceId, {
    String? projectId,
    bool isBreaking = false,
  }) {
    return AppDatabase.inTransaction((txn) async {
      final existing = await _projectRateRepository.findWithExecutor(
        txn,
        projectKey: projectKey,
        deviceId: deviceId,
        projectId: projectId,
        isBreaking: isBreaking,
      );
      final affected = await _projectRateRepository.deleteWithExecutor(
        txn,
        projectKey,
        deviceId,
        projectId: projectId,
        isBreaking: isBreaking,
      );
      if (affected == 0 || existing == null) return affected;
      await _syncEnqueuer.enqueueDelete(
        txn,
        rate: existing,
        actor: _actorProvider?.call(),
      );
      return affected;
    });
  }
}
