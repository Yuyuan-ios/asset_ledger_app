import 'package:asset_ledger/infrastructure/sync/conflict_resolver.dart';
import 'package:asset_ledger/infrastructure/sync/entity_sync_meta.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConflictResolver', () {
    test('marks matching payloads as synced', () {
      const meta = EntitySyncMeta(
        entityType: 'work_record',
        localId: 'local-1',
        syncStatus: SyncStatus.synced,
        version: 1,
        source: 'owner_app',
        payloadHash: 'same',
      );

      final decision = const ConflictResolver().resolve(
        local: meta,
        remote: meta,
      );

      expect(decision.status, SyncStatus.synced);
      expect(decision.reason, isNull);
    });

    test(
      'does not silently overwrite dirty local data with newer remote data',
      () {
        const local = EntitySyncMeta(
          entityType: 'work_record',
          localId: 'local-1',
          syncStatus: SyncStatus.pendingUpdate,
          version: 1,
          source: 'owner_app',
          payloadHash: 'local',
        );
        const remote = EntitySyncMeta(
          entityType: 'work_record',
          localId: 'local-1',
          syncStatus: SyncStatus.synced,
          version: 2,
          source: 'mini_program',
          payloadHash: 'remote',
        );

        final decision = const ConflictResolver().resolve(
          local: local,
          remote: remote,
        );

        expect(decision.status, SyncStatus.conflict);
        expect(decision.reason, 'remote_newer_local_dirty');
      },
    );

    test('accepts newer remote data when local metadata is clean', () {
      const local = EntitySyncMeta(
        entityType: 'timing_record',
        localId: '1',
        syncStatus: SyncStatus.synced,
        version: 1,
        source: 'owner_app',
        payloadHash: 'local-old',
      );
      const remote = EntitySyncMeta(
        entityType: 'timing_record',
        localId: '1',
        syncStatus: SyncStatus.synced,
        version: 2,
        source: 'cloud_sync',
        payloadHash: 'remote-new',
      );

      final decision = const ConflictResolver().resolve(
        local: local,
        remote: remote,
      );

      expect(decision.status, SyncStatus.synced);
      expect(decision.reason, isNull);
    });

    test('matching payload hash stays synced even when local is dirty', () {
      const local = EntitySyncMeta(
        entityType: 'timing_record',
        localId: '1',
        syncStatus: SyncStatus.pendingUpdate,
        version: 1,
        source: 'owner_app',
        payloadHash: 'same',
      );
      const remote = EntitySyncMeta(
        entityType: 'timing_record',
        localId: '1',
        syncStatus: SyncStatus.synced,
        version: 2,
        source: 'cloud_sync',
        payloadHash: 'same',
      );

      final decision = const ConflictResolver().resolve(
        local: local,
        remote: remote,
      );

      expect(decision.status, SyncStatus.synced);
      expect(decision.reason, isNull);
    });
  });
}
