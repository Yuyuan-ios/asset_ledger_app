import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/repositories/project_write_off_repository.dart';
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
