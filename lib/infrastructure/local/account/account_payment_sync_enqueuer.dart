import 'package:sqflite/sqflite.dart';

import '../../../data/models/account_payment.dart';
import '../../sync/entity_sync_meta.dart';
import '../../sync/sync_repositories.dart';
import '../../sync/sync_status.dart';

/// Writes the row-level account_payment sync contract using the caller's
/// transaction executor.
class AccountPaymentSyncEnqueuer {
  const AccountPaymentSyncEnqueuer({
    SyncOutboxRepository? syncOutboxRepository,
    EntitySyncMetaRepository? entitySyncMetaRepository,
  }) : _syncOutboxRepository =
           syncOutboxRepository ?? const LocalSyncOutboxRepository(),
       _entitySyncMetaRepository =
           entitySyncMetaRepository ?? const LocalEntitySyncMetaRepository();

  final SyncOutboxRepository _syncOutboxRepository;
  final EntitySyncMetaRepository _entitySyncMetaRepository;

  static const String entityType = 'account_payment';
  static const String ownerAppSource = 'owner_app';

  Future<void> enqueue(
    DatabaseExecutor executor, {
    required AccountPayment payment,
    required String operation,
    required SyncStatus status,
    String? transactionGroupId,
    int? localSequence,
  }) async {
    final id = payment.id;
    if (id == null) {
      throw StateError('sync_outbox 入队需要最终落库后的 account_payment id');
    }
    final entityId = id.toString();
    final entry = await _syncOutboxRepository.enqueueWithExecutor(
      executor,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: {
        'entity_type': entityType,
        'entity_id': entityId,
        'operation': operation,
        'record': payment.toMap(),
      },
      transactionGroupId: transactionGroupId,
      localSequence: localSequence,
    );
    await _entitySyncMetaRepository.upsertWithExecutor(
      executor,
      EntitySyncMeta(
        entityType: entityType,
        localId: entityId,
        syncStatus: status,
        version: 0,
        source: ownerAppSource,
        payloadHash: entry.payloadHash,
      ),
    );
  }
}
