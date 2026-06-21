import 'package:sqflite/sqflite.dart';

import '../../../core/operations/operation_access_control.dart';
import '../../../data/db/database.dart';
import '../../../data/models/fuel_log.dart';
import '../../../data/repositories/fuel_repository.dart';
import '../../../features/fuel/use_cases/fuel_log_write_use_case.dart';
import '../../sync/sync_actor.dart';
import '../../sync/sync_repositories.dart';
import '../../sync/sync_transaction_group.dart';
import 'fuel_log_sync_enqueuer.dart';

class LocalFuelLogWriteUseCase implements FuelLogWriteUseCase {
  LocalFuelLogWriteUseCase({
    required SqfliteFuelRepository fuelRepository,
    SyncOutboxRepository? syncOutboxRepository,
    EntitySyncMetaRepository? entitySyncMetaRepository,
    FuelLogSyncEnqueuer? syncEnqueuer,
    SyncActorProvider? actorProvider,
  }) : _fuelRepository = fuelRepository,
       _syncEnqueuer =
           syncEnqueuer ??
           FuelLogSyncEnqueuer(
             syncOutboxRepository: syncOutboxRepository,
             entitySyncMetaRepository: entitySyncMetaRepository,
           ),
       _actorProvider = actorProvider;

  final SqfliteFuelRepository _fuelRepository;
  final FuelLogSyncEnqueuer _syncEnqueuer;
  final SyncActorProvider? _actorProvider;

  @override
  Future<int> create(FuelLog log) {
    return AppDatabase.inTransaction((txn) async {
      final id = await _fuelRepository.insertWithExecutor(txn, log);
      final saved = log.copyWith(id: id);
      await _syncEnqueuer.enqueueCreate(
        txn,
        log: saved,
        actor: _actorProvider?.call(),
      );
      return id;
    });
  }

  @override
  Future<void> update(FuelLog log) async {
    final id = log.id;
    if (id == null) {
      throw StateError('更新燃油记录需要 id');
    }
    await AppDatabase.inTransaction((txn) async {
      final affected = await _fuelRepository.updateWithExecutor(txn, log);
      if (affected == 0) {
        throw StateError('燃油记录不存在或已被并发修改，请刷新后再试');
      }
      if (affected > 1) {
        throw StateError(
          'updateWithExecutor 影响 $affected 行（期望 1）：fuel_logs 主键异常',
        );
      }
      await _syncEnqueuer.enqueueUpdate(
        txn,
        log: log,
        actor: _actorProvider?.call(),
      );
    });
  }

  @override
  Future<void> deleteById(int id) async {
    await AppDatabase.inTransaction((txn) async {
      final existing = await _fuelRepository.findByIdWithExecutor(txn, id);
      final affected = await _fuelRepository.deleteByIdWithExecutor(txn, id);
      if (affected == 0 || existing == null) return;
      await _syncEnqueuer.enqueueDelete(
        txn,
        log: existing,
        actor: _actorProvider?.call(),
      );
    });
  }

  Future<int> deleteByDeviceIdWithExecutor(
    DatabaseExecutor executor,
    int deviceId, {
    SyncTransactionGroup? group,
    ActorContext? actor,
  }) async {
    final existing = await _fuelRepository.listByDeviceIdWithExecutor(
      executor,
      deviceId,
    );
    final affected = await _fuelRepository.deleteByDeviceIdWithExecutor(
      executor,
      deviceId,
    );
    for (final log in existing) {
      await _syncEnqueuer.enqueueDelete(
        executor,
        log: log,
        transactionGroupId: group?.id,
        localSequence: group?.nextSequence(),
        actor: actor,
      );
    }
    return affected;
  }
}
