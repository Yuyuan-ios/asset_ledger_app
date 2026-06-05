import 'dart:convert';

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

import '../../../test_setup.dart';

/// R5.22-A cluster test against the real single-project settlement use case.
///
/// `settle()` produces three outbox rows inside one transaction:
///   payment create → write-off create → project status update.
/// They must share one transaction_group_id and carry local_sequence 1,2,3 in
/// that business-causal order, while payload / entity_sync_meta semantics stay
/// exactly as before R5.22-A.
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

  test(
    'single-project settle writes payment+write-off+project outbox in one '
    'transaction group with sequence 1,2,3',
    () async {
      final db = await AppDatabase.database;
      await _seedProject(db);

      final useCase = ProjectSettlementUseCase(
        repository: const LocalProjectSettlementRepository(),
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

      // All three rows belong to the same non-null txn-* group.
      final groupIds = rows.map((r) => r['transaction_group_id']).toSet();
      expect(groupIds, hasLength(1));
      final groupId = groupIds.single as String?;
      expect(groupId, isNotNull);
      expect(groupId, startsWith('txn-'));

      // local_sequence is the dense causal order 1,2,3.
      expect(rows.map((r) => r['local_sequence']).toList(), <int>[1, 2, 3]);

      // Causal order: payment (1) → write-off (2) → project (3).
      expect(rows[0]['entity_type'], AccountPaymentSyncEnqueuer.entityType);
      expect(rows[0]['operation'], 'create');
      expect(rows[1]['entity_type'], ProjectWriteOffSyncEnqueuer.entityType);
      expect(rows[1]['operation'], 'create');
      expect(rows[2]['entity_type'], ProjectSyncEnqueuer.entityType);
      expect(rows[2]['operation'], 'update');

      // Old semantics intact: grouping metadata is NOT in the payload, and the
      // payload still carries the business record.
      for (final row in rows) {
        final payload = jsonDecode(row['payload_json'] as String) as Map;
        expect(payload.containsKey('transaction_group_id'), isFalse);
        expect(payload.containsKey('local_sequence'), isFalse);
        expect(payload.containsKey('record'), isTrue);
      }

      // entity_sync_meta still written once per entity (unchanged).
      final meta = await db.query('entity_sync_meta');
      expect(meta, hasLength(3));
      // meta carries no grouping columns (outbox-only concern).
      expect(meta.first.containsKey('transaction_group_id'), isFalse);
      expect(meta.first.containsKey('local_sequence'), isFalse);
    },
  );

  test('ordinary single write-off delete (non-cluster) stays grouped only when '
      'the entry point is a settlement cluster method', () async {
    // deleteWriteOff is itself a settlement cluster entry; with no status
    // change it still produces exactly one outbox row, grouped with sequence 1.
    final db = await AppDatabase.database;
    await _seedProject(db, status: ProjectStatus.active);
    await db.insert(
      SqfliteProjectWriteOffRepository.table,
      ProjectWriteOff(
        id: 'write-off-1',
        projectId: 'project:1',
        amount: 50,
        reason: ProjectWriteOffReason.rounding.dbValue,
        writeOffDate: '2026-05-18',
        createdAt: '2026-05-18T00:00:00.000Z',
        updatedAt: '2026-05-18T00:00:00.000Z',
      ).toMap(),
    );

    final useCase = ProjectSettlementUseCase(
      repository: const LocalProjectSettlementRepository(),
      now: () => DateTime.utc(2026, 5, 18, 1, 2, 3),
      writeOffIdFactory: (_, _) => 'write-off-1',
    );

    await useCase.deleteWriteOff(
      projectId: 'project:1',
      writeOffId: 'write-off-1',
      receivable: 20000,
    );

    final rows = await db.query('sync_outbox');
    expect(rows, hasLength(1));
    expect(rows.single['entity_type'], ProjectWriteOffSyncEnqueuer.entityType);
    expect(rows.single['operation'], 'delete');
    // Single-row cluster entry still gets a group + sequence 1.
    expect(rows.single['transaction_group_id'], startsWith('txn-'));
    expect(rows.single['local_sequence'], 1);
  });

  test(
    'merged write-off delete assigns local_sequence by createdAt ASC, id ASC '
    'then project status updates continue the same group',
    () async {
      final db = await AppDatabase.database;
      // Two settled member projects, each with exactly one merge write-off.
      await _seedProjectWithId(db, id: 'project:1', site: '一号', settled: true);
      await _seedProjectWithId(db, id: 'project:2', site: '二号', settled: true);

      // Write-off "...-a" is alphabetically first but created LATER; "...-b" is
      // alphabetically second but created EARLIER. A deterministic createdAt-ASC
      // sort must order b before a, distinguishing it from an id-only sort and
      // from SQLite's unspecified `id IN (...)` order.
      await _seedMergeWriteOff(
        db,
        id: 'writeoff-merge-7-a',
        projectId: 'project:1',
        createdAt: '2026-05-18T00:00:02.000Z',
      );
      await _seedMergeWriteOff(
        db,
        id: 'writeoff-merge-7-b',
        projectId: 'project:2',
        createdAt: '2026-05-18T00:00:01.000Z',
      );

      const repository = LocalProjectSettlementRepository();
      await repository.deleteMergedWriteOffs(
        const DeleteMergedProjectWriteOffsRequest(
          mergedProjectId: 'merge:7',
          mergeGroupId: 7,
          members: [
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
          writeOffIds: ['writeoff-merge-7-a', 'writeoff-merge-7-b'],
          receivable: 200,
          updatedAtIso: '2026-05-18T01:02:03.000Z',
        ),
      );

      final rows = await db.query('sync_outbox', orderBy: 'local_sequence ASC');
      // 2 write-off deletes + 2 project status updates.
      expect(rows, hasLength(4));

      // Single shared group.
      final groupIds = rows.map((r) => r['transaction_group_id']).toSet();
      expect(groupIds, hasLength(1));
      expect(groupIds.single, startsWith('txn-'));

      // Dense, gap-free, non-repeating 1..4.
      expect(rows.map((r) => r['local_sequence']).toList(), <int>[1, 2, 3, 4]);

      // seq 1,2 are the write-off deletes ordered by createdAt ASC: b before a.
      expect(rows[0]['entity_type'], ProjectWriteOffSyncEnqueuer.entityType);
      expect(rows[0]['operation'], 'delete');
      expect(rows[0]['entity_id'], 'writeoff-merge-7-b');
      expect(rows[1]['entity_type'], ProjectWriteOffSyncEnqueuer.entityType);
      expect(rows[1]['operation'], 'delete');
      expect(rows[1]['entity_id'], 'writeoff-merge-7-a');

      // seq 3,4 are project status updates AFTER the write-off deletes.
      expect(rows[2]['entity_type'], ProjectSyncEnqueuer.entityType);
      expect(rows[2]['operation'], 'update');
      expect(rows[3]['entity_type'], ProjectSyncEnqueuer.entityType);
      expect(rows[3]['operation'], 'update');
    },
  );
}

Future<void> _seedProjectWithId(
  Database db, {
  required String id,
  required String site,
  bool settled = false,
}) async {
  await db.insert(
    SqfliteProjectRepository.table,
    Project(
      id: id,
      contact: '甲方',
      site: site,
      status: settled ? ProjectStatus.settled : ProjectStatus.active,
      settledAt: settled ? '2026-05-18T00:00:00.000Z' : null,
      createdAt: '2026-05-01T00:00:00.000Z',
      updatedAt: '2026-05-01T00:00:00.000Z',
      legacyProjectKey: '甲方||$site',
    ).toMap(),
  );
}

Future<void> _seedMergeWriteOff(
  Database db, {
  required String id,
  required String projectId,
  required String createdAt,
}) async {
  await db.insert(
    SqfliteProjectWriteOffRepository.table,
    ProjectWriteOff(
      id: id,
      projectId: projectId,
      amount: 50,
      reason: ProjectWriteOffReason.settlement.dbValue,
      writeOffDate: '2026-05-18',
      createdAt: createdAt,
      updatedAt: createdAt,
    ).toMap(),
  );
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
      settledAt: status == ProjectStatus.settled
          ? '2026-05-18T00:00:00.000Z'
          : null,
      createdAt: '2026-05-01T00:00:00.000Z',
      updatedAt: '2026-05-01T00:00:00.000Z',
      legacyProjectKey: '甲方||一号工地',
    ).toMap(),
  );
}
