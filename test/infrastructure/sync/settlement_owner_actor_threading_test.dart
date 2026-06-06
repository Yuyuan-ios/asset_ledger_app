import 'dart:convert';

import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/repositories/project_write_off_repository.dart';
import 'package:asset_ledger/features/account/domain/repositories/project_settlement_repository.dart';
import 'package:asset_ledger/features/account/use_cases/project_settlement_use_case.dart';
import 'package:asset_ledger/infrastructure/local/account/account_payment_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/local/account/local_project_settlement_repository.dart';
import 'package:asset_ledger/infrastructure/local/account/project_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/local/account/project_write_off_sync_enqueuer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

/// R5.25-Hardening-followup: runtime coverage of the persisted-owner actor
/// across every settlement cluster entry point.
///
/// Confirms that when the composition root threads a SyncActorProvider into
/// [LocalProjectSettlementRepository]:
/// - every outbox row in the cluster carries `payload.actor.id` equal to the
///   injected owner id;
/// - the `actor` object always includes the `session_id` key (null or value);
/// - the matching `entity_sync_meta.updated_by` mirrors the same id;
/// - all rows in one cluster share the same `transaction_group_id` and have a
///   dense `local_sequence` (R5.22-A invariant);
/// - the business `record` stays free of `actor` / `payload_schema_version`.
///
/// The covered entry points are `settle`, `settleMerged`, `deleteWriteOff` and
/// `revokeSettlementStatus`. They span: single payment+writeOff+project,
/// multi-member write-off + status updates, single write-off delete + restore,
/// and project-only status mutation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
    AppDatabase.debugInitDbOverride = () {
      return openDatabase(
        inMemoryDatabasePath,
        version: AppDatabase.schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, _) => DbSchema.create(db),
      );
    };
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  ActorContext owner({String id = 'owner-settle-1', String? sessionId}) =>
      ActorContext(
        actorType: OperationActorType.owner,
        actorId: id,
        sessionId: sessionId,
      );

  group('settle (single project)', () {
    test(
      'every outbox row in the payment+writeOff+project cluster carries the '
      'injected owner actor; meta.updated_by mirrors; group/sequence intact; '
      'record is untouched',
      () async {
        final db = await AppDatabase.database;
        await _seedProject(db);

        final injected = owner(sessionId: 'session-settle');
        final useCase = ProjectSettlementUseCase(
          repository: LocalProjectSettlementRepository(
            actorProvider: () => injected,
          ),
          now: () => DateTime.utc(2026, 5, 18, 1, 2, 3),
          writeOffIdFactory: (_, _) => 'write-off-1',
        );

        final result = await useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 20000,
          paymentAmount: 5000,
          writeOffAmount: 15000,
          writeOffReason: ProjectWriteOffReason.settlement,
          ymd: 20260518,
        );
        expect(result.settled, isTrue);

        final rows = await db.query(
          'sync_outbox',
          orderBy: 'local_sequence ASC',
        );
        expect(rows, hasLength(3));

        // R5.22-A invariants kept intact.
        final groupIds = rows.map((r) => r['transaction_group_id']).toSet();
        expect(groupIds, hasLength(1));
        expect(groupIds.single as String?, startsWith('txn-'));
        expect(rows.map((r) => r['local_sequence']).toList(), <int>[1, 2, 3]);
        expect(rows[0]['entity_type'], AccountPaymentSyncEnqueuer.entityType);
        expect(rows[1]['entity_type'], ProjectWriteOffSyncEnqueuer.entityType);
        expect(rows[2]['entity_type'], ProjectSyncEnqueuer.entityType);

        // Every payload carries the same injected owner actor.
        for (final row in rows) {
          final payload = (jsonDecode(row['payload_json'] as String) as Map)
              .cast<String, Object?>();
          expect(payload['payload_schema_version'], 1);
          final actor = payload['actor'] as Map<String, Object?>;
          expect(actor['type'], 'owner');
          expect(actor['id'], 'owner-settle-1');
          expect(actor.containsKey('session_id'), isTrue);
          expect(actor['session_id'], 'session-settle');
          // The business record stays a plain snapshot.
          final record = payload['record'] as Map<String, Object?>;
          expect(record.containsKey('actor'), isFalse);
          expect(record.containsKey('payload_schema_version'), isFalse);
        }

        // entity_sync_meta.updated_by mirrors the payload actor on every row.
        final meta = await db.query('entity_sync_meta');
        expect(meta, hasLength(3));
        expect(
          meta.map((r) => r['updated_by']).toSet(),
          {'owner-settle-1'},
          reason: 'every meta row must mirror payload.actor.id',
        );
      },
    );
  });

  group('settleMerged (multi-member writeOff + project updates)', () {
    test(
      'every writeOff create + project update in the cluster carries the same '
      'injected actor; meta.updated_by mirrors; group/sequence dense',
      () async {
        final db = await AppDatabase.database;
        await _seedProjectWithId(db, id: 'project:1', site: '一号');
        await _seedProjectWithId(db, id: 'project:2', site: '二号');

        final injected = owner(id: 'owner-merged-1');
        final repository = LocalProjectSettlementRepository(
          actorProvider: () => injected,
        );

        await repository.settleMerged(
          MergedProjectSettlementRequest(
            mergedProjectId: 'merge:9',
            mergeGroupId: 9,
            receivable: 200,
            writeOffAmount: 200,
            writeOffReasonDbValue: ProjectWriteOffReason.settlement.dbValue,
            ymd: 20260518,
            createdAtIso: '2026-05-18T01:02:03.000Z',
            writeOffDate: '2026-05-18',
            members: const [
              MergedProjectSettlementMemberRequest(
                projectId: 'project:1',
                projectKey: '甲方||一号',
                receivable: 100,
              ),
              MergedProjectSettlementMemberRequest(
                projectId: 'project:2',
                projectKey: '甲方||二号',
                receivable: 100,
              ),
            ],
            allocations: const [
              MergedProjectSettlementAllocationRequest(
                projectId: 'project:1',
                projectKey: '甲方||一号',
                receivable: 100,
                writeOffAmount: 100,
                writeOffId: 'writeoff-merge-9-1',
              ),
              MergedProjectSettlementAllocationRequest(
                projectId: 'project:2',
                projectKey: '甲方||二号',
                receivable: 100,
                writeOffAmount: 100,
                writeOffId: 'writeoff-merge-9-2',
              ),
            ],
          ),
        );

        final rows = await db.query(
          'sync_outbox',
          orderBy: 'local_sequence ASC',
        );
        // 2 writeOff creates (one per member) interleaved with 2 project
        // updates (each member becomes settled inside its allocation loop).
        expect(rows, hasLength(4));

        // Single shared group, dense sequence.
        final groupIds = rows.map((r) => r['transaction_group_id']).toSet();
        expect(groupIds, hasLength(1));
        expect(groupIds.single as String?, startsWith('txn-'));
        expect(
          rows.map((r) => r['local_sequence']).toList(),
          <int>[1, 2, 3, 4],
        );

        // Every payload + meta row carries the same injected actor id.
        final actorIds = <String?>{};
        for (final row in rows) {
          final payload = (jsonDecode(row['payload_json'] as String) as Map)
              .cast<String, Object?>();
          final actor = payload['actor'] as Map<String, Object?>;
          expect(actor['type'], 'owner');
          expect(actor.containsKey('session_id'), isTrue);
          expect(actor['session_id'], isNull);
          actorIds.add(actor['id'] as String?);
        }
        expect(
          actorIds,
          {'owner-merged-1'},
          reason: 'all outbox rows in one cluster must share one actor.id',
        );

        final meta = await db.query('entity_sync_meta');
        expect(meta.length, greaterThanOrEqualTo(2));
        expect(
          meta.map((r) => r['updated_by']).toSet(),
          {'owner-merged-1'},
        );
      },
    );
  });

  group('deleteWriteOff (single project restore)', () {
    test(
      'writeOff delete + project status restore both carry the injected actor',
      () async {
        final db = await AppDatabase.database;
        await _seedProject(db, status: ProjectStatus.settled);
        await db.insert(
          SqfliteProjectWriteOffRepository.table,
          ProjectWriteOff(
            id: 'write-off-1',
            projectId: 'project:1',
            amount: 200,
            reason: ProjectWriteOffReason.settlement.dbValue,
            writeOffDate: '2026-05-18',
            createdAt: '2026-05-18T00:00:00.000Z',
            updatedAt: '2026-05-18T00:00:00.000Z',
          ).toMap(),
        );

        final injected = owner(id: 'owner-delete-1');
        final useCase = ProjectSettlementUseCase(
          repository: LocalProjectSettlementRepository(
            actorProvider: () => injected,
          ),
          now: () => DateTime.utc(2026, 5, 19),
        );

        final result = await useCase.deleteWriteOff(
          projectId: 'project:1',
          writeOffId: 'write-off-1',
          receivable: 20000,
        );
        expect(result.restoredActive, isTrue);

        final rows = await db.query(
          'sync_outbox',
          orderBy: 'local_sequence ASC',
        );
        // writeOff delete (1) + project update (2) — same cluster.
        expect(rows, hasLength(2));
        expect(rows[0]['entity_type'], ProjectWriteOffSyncEnqueuer.entityType);
        expect(rows[0]['operation'], 'delete');
        expect(rows[1]['entity_type'], ProjectSyncEnqueuer.entityType);
        expect(rows[1]['operation'], 'update');

        final groupIds = rows.map((r) => r['transaction_group_id']).toSet();
        expect(groupIds, hasLength(1));
        expect(rows.map((r) => r['local_sequence']).toList(), <int>[1, 2]);

        for (final row in rows) {
          final payload = (jsonDecode(row['payload_json'] as String) as Map)
              .cast<String, Object?>();
          final actor = payload['actor'] as Map<String, Object?>;
          expect(actor['id'], 'owner-delete-1');
          expect(actor.containsKey('session_id'), isTrue);
        }

        final meta = await db.query('entity_sync_meta');
        expect(meta.length, greaterThanOrEqualTo(1));
        expect(
          meta.map((r) => r['updated_by']).toSet(),
          {'owner-delete-1'},
        );
      },
    );
  });

  group('revokeSettlementStatus (project-only mutation)', () {
    test(
      'project status restore enqueues with the injected actor; '
      'meta.updated_by mirrors',
      () async {
        final db = await AppDatabase.database;
        await _seedProject(db, status: ProjectStatus.settled);

        final injected = owner(id: 'owner-revoke-1', sessionId: 'session-r');
        final useCase = ProjectSettlementUseCase(
          repository: LocalProjectSettlementRepository(
            actorProvider: () => injected,
          ),
          now: () => DateTime.utc(2026, 5, 20),
        );

        final result = await useCase.revokeSettlementStatus(
          projectId: 'project:1',
        );
        expect(result.restoredActive, isTrue);

        final rows = await db.query('sync_outbox');
        expect(rows, hasLength(1));
        expect(rows.single['entity_type'], ProjectSyncEnqueuer.entityType);
        expect(rows.single['operation'], 'update');
        expect(rows.single['transaction_group_id'], startsWith('txn-'));
        expect(rows.single['local_sequence'], 1);

        final payload =
            (jsonDecode(rows.single['payload_json'] as String) as Map)
                .cast<String, Object?>();
        final actor = payload['actor'] as Map<String, Object?>;
        expect(actor['type'], 'owner');
        expect(actor['id'], 'owner-revoke-1');
        expect(actor['session_id'], 'session-r');

        final meta = await db.query('entity_sync_meta');
        expect(meta, hasLength(1));
        expect(meta.single['updated_by'], 'owner-revoke-1');
      },
    );
  });

  group('legacy/test fallback (no provider)', () {
    test(
      'without an injected actor the cluster keeps producing the documented '
      'owner-app fallback (null id), kept as a regression breadcrumb',
      () async {
        final db = await AppDatabase.database;
        await _seedProject(db);

        final useCase = ProjectSettlementUseCase(
          repository: const LocalProjectSettlementRepository(),
          now: () => DateTime.utc(2026, 5, 18, 1, 2, 3),
          writeOffIdFactory: (_, _) => 'write-off-1',
        );

        await useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 20000,
          paymentAmount: 5000,
          writeOffAmount: 15000,
          writeOffReason: ProjectWriteOffReason.settlement,
          ymd: 20260518,
        );

        final rows = await db.query('sync_outbox');
        expect(rows, hasLength(3));
        for (final row in rows) {
          final payload = (jsonDecode(row['payload_json'] as String) as Map)
              .cast<String, Object?>();
          final actor = payload['actor'] as Map<String, Object?>;
          expect(actor['type'], 'owner');
          expect(actor['id'], isNull,
              reason: 'no provider → documented owner-app fallback null id');
          expect(actor.containsKey('session_id'), isTrue);
          expect(actor['session_id'], isNull);
        }
        final meta = await db.query('entity_sync_meta');
        expect(meta.map((r) => r['updated_by']).toSet(), {null});
      },
    );
  });
}

Future<void> _seedProject(
  Database db, {
  ProjectStatus status = ProjectStatus.active,
}) async {
  await db.insert(
    SqfliteProjectRepository.table,
    Project(
      id: 'project:1',
      contact: '甲方',
      site: '一号工地',
      status: status,
      settledAt:
          status == ProjectStatus.settled ? '2026-05-18T00:00:00.000Z' : null,
      createdAt: '2026-05-01T00:00:00.000Z',
      updatedAt: '2026-05-01T00:00:00.000Z',
      legacyProjectKey: '甲方||一号工地',
    ).toMap(),
  );
}

Future<void> _seedProjectWithId(
  Database db, {
  required String id,
  required String site,
}) async {
  await db.insert(
    SqfliteProjectRepository.table,
    Project(
      id: id,
      contact: '甲方',
      site: site,
      status: ProjectStatus.active,
      createdAt: '2026-05-01T00:00:00.000Z',
      updatedAt: '2026-05-01T00:00:00.000Z',
      legacyProjectKey: '甲方||$site',
    ).toMap(),
  );
}
