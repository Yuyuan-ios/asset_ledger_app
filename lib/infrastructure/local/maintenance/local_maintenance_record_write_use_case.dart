import 'package:sqflite/sqflite.dart';

import '../../../core/operations/operation_access_control.dart';
import '../../../data/db/database.dart';
import '../../../data/models/maintenance_record.dart';
import '../../../data/repositories/maintenance_repository.dart';
import '../../../features/maintenance/use_cases/maintenance_record_write_use_case.dart';
import '../../sync/sync_actor.dart';
import '../../sync/sync_repositories.dart';
import '../../sync/sync_transaction_group.dart';
import 'maintenance_record_sync_enqueuer.dart';

class LocalMaintenanceRecordWriteUseCase
    implements MaintenanceRecordWriteUseCase {
  LocalMaintenanceRecordWriteUseCase({
    required SqfliteMaintenanceRepository maintenanceRepository,
    SyncOutboxRepository? syncOutboxRepository,
    EntitySyncMetaRepository? entitySyncMetaRepository,
    MaintenanceRecordSyncEnqueuer? syncEnqueuer,
    SyncActorProvider? actorProvider,
  }) : _maintenanceRepository = maintenanceRepository,
       _syncEnqueuer =
           syncEnqueuer ??
           MaintenanceRecordSyncEnqueuer(
             syncOutboxRepository: syncOutboxRepository,
             entitySyncMetaRepository: entitySyncMetaRepository,
           ),
       _actorProvider = actorProvider;

  final SqfliteMaintenanceRepository _maintenanceRepository;
  final MaintenanceRecordSyncEnqueuer _syncEnqueuer;
  final SyncActorProvider? _actorProvider;

  @override
  Future<int> create(MaintenanceRecord record) {
    return AppDatabase.inTransaction((txn) async {
      final id = await _maintenanceRepository.insertWithExecutor(txn, record);
      final saved = record.copyWith(id: id);
      await _syncEnqueuer.enqueueCreate(
        txn,
        record: saved,
        actor: _actorProvider?.call(),
      );
      return id;
    });
  }

  @override
  Future<void> update(MaintenanceRecord record) async {
    final id = record.id;
    if (id == null) {
      throw StateError('更新维保记录需要 id');
    }
    await AppDatabase.inTransaction((txn) async {
      final affected = await _maintenanceRepository.updateWithExecutor(
        txn,
        record,
      );
      if (affected == 0) {
        throw StateError('维保记录不存在或已被并发修改，请刷新后再试');
      }
      if (affected > 1) {
        throw StateError(
          'updateWithExecutor 影响 $affected 行（期望 1）：'
          'maintenance_records 主键异常',
        );
      }
      await _syncEnqueuer.enqueueUpdate(
        txn,
        record: record,
        actor: _actorProvider?.call(),
      );
    });
  }

  @override
  Future<void> deleteById(int id) async {
    await AppDatabase.inTransaction((txn) async {
      final existing = await _maintenanceRepository.findByIdWithExecutor(
        txn,
        id,
      );
      final affected = await _maintenanceRepository.deleteByIdWithExecutor(
        txn,
        id,
      );
      if (affected == 0 || existing == null) return;
      await _syncEnqueuer.enqueueDelete(
        txn,
        record: existing,
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
    final existing = await _maintenanceRepository.listByDeviceIdWithExecutor(
      executor,
      deviceId,
    );
    final affected = await _maintenanceRepository.deleteByDeviceIdWithExecutor(
      executor,
      deviceId,
    );
    for (final record in existing) {
      await _syncEnqueuer.enqueueDelete(
        executor,
        record: record,
        transactionGroupId: group?.id,
        localSequence: group?.nextSequence(),
        actor: actor,
      );
    }
    return affected;
  }
}
