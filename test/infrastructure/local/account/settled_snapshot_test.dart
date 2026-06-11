import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_settled_snapshot.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/features/account/domain/repositories/project_settlement_repository.dart';
import 'package:asset_ledger/infrastructure/local/account/local_project_settlement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

/// §6.3 结清确认快照：结清瞬间的 fen 口径结果随同一确认动作持久化到
/// projects.settled_snapshot；revoke 清空；合并结清两条置 settled 路径
/// （分摊结清 / 整组兜底结清）成员各自落快照。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
    await _openCurrentInMemoryDb();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  const createdAtIso = '2026-06-12T00:00:00.000Z';

  test('settle persists the fen snapshot of the settle moment', () async {
    final db = await AppDatabase.database;
    await _seedProject(db, projectId: 'project:alpha');
    // 旧已收 90 元（fen 权威）。
    await _insertPaymentRow(db, projectId: 'project:alpha', amountFen: 9000);

    const repo = LocalProjectSettlementRepository();
    final result = await repo.settle(
      const ProjectSettlementRequest(
        projectId: 'project:alpha',
        projectKey: '甲方||project:alpha',
        receivable: 100.0,
        paymentAmount: 10.0,
        writeOffAmount: 0,
        writeOffReasonDbValue: null,
        ymd: 20260612,
        createdAtIso: createdAtIso,
        writeOffDate: '2026-06-12',
      ),
    );
    expect(result.settled, isTrue);

    final row = (await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: ['project:alpha'],
    )).single;
    expect(row['status'], ProjectStatus.settled.name);

    final snapshot = ProjectSettledSnapshot.tryDecode(
      row['settled_snapshot'] as String?,
    );
    expect(snapshot, isNotNull, reason: '结清必须落不可漂移快照');
    expect(snapshot!.receivableFen, 10000);
    expect(snapshot.receivedFen, 10000);
    expect(snapshot.writeOffFen, 0);
    expect(snapshot.remainingFen, 0);
    expect(snapshot.settledAt, createdAtIso);
    expect(
      row['settled_snapshot'],
      contains('"snapshot_schema_version":1'),
    );
  });

  test('snapshot freezes the settle moment even if data changes later',
      () async {
    final db = await AppDatabase.database;
    await _seedProject(db, projectId: 'project:alpha');
    await _insertPaymentRow(db, projectId: 'project:alpha', amountFen: 9000);

    const repo = LocalProjectSettlementRepository();
    await repo.settle(
      const ProjectSettlementRequest(
        projectId: 'project:alpha',
        projectKey: '甲方||project:alpha',
        receivable: 100.0,
        paymentAmount: 10.0,
        writeOffAmount: 0,
        writeOffReasonDbValue: null,
        ymd: 20260612,
        createdAtIso: createdAtIso,
        writeOffDate: '2026-06-12',
      ),
    );

    // 结清后又灌入新的收款行——快照不得漂移。
    await _insertPaymentRow(db, projectId: 'project:alpha', amountFen: 12345);

    final row = (await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: ['project:alpha'],
    )).single;
    final snapshot = ProjectSettledSnapshot.tryDecode(
      row['settled_snapshot'] as String?,
    );
    expect(snapshot!.receivedFen, 10000, reason: '快照记录结清那一刻,不随后续变化');
  });

  test('revoke clears the snapshot together with settled status', () async {
    final db = await AppDatabase.database;
    await _seedProject(db, projectId: 'project:alpha');
    await _insertPaymentRow(db, projectId: 'project:alpha', amountFen: 9000);

    const repo = LocalProjectSettlementRepository();
    await repo.settle(
      const ProjectSettlementRequest(
        projectId: 'project:alpha',
        projectKey: '甲方||project:alpha',
        receivable: 100.0,
        paymentAmount: 10.0,
        writeOffAmount: 0,
        writeOffReasonDbValue: null,
        ymd: 20260612,
        createdAtIso: createdAtIso,
        writeOffDate: '2026-06-12',
      ),
    );
    var row = (await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: ['project:alpha'],
    )).single;
    expect(row['settled_snapshot'], isNotNull);

    await repo.revokeSettlementStatus(
      const RevokeProjectSettlementStatusRequest(
        projectId: 'project:alpha',
        updatedAtIso: '2026-06-13T00:00:00.000Z',
      ),
    );

    row = (await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: ['project:alpha'],
    )).single;
    expect(row['status'], ProjectStatus.active.name);
    expect(row['settled_at'], isNull);
    expect(row['settled_snapshot'], isNull, reason: '撤销结清必须清空快照');
  });

  test('merged settle writes per-member snapshots on both settle paths',
      () async {
    final db = await AppDatabase.database;
    // m1：应收 100,已收 60,分摊核销 40 → 经「分摊结清」路径置 settled。
    await _seedProject(db, projectId: 'project:m1');
    await _insertPaymentRow(db, projectId: 'project:m1', amountFen: 6000);
    // m2：应收 50,已收 50 → 经「整组兜底」路径置 settled(无核销)。
    await _seedProject(db, projectId: 'project:m2');
    await _insertPaymentRow(db, projectId: 'project:m2', amountFen: 5000);

    const repo = LocalProjectSettlementRepository();
    final result = await repo.settleMerged(
      const MergedProjectSettlementRequest(
        mergedProjectId: 'project:m1',
        mergeGroupId: 1,
        receivable: 150.0,
        writeOffAmount: 40.0,
        writeOffReasonDbValue: 'settlement',
        ymd: 20260612,
        createdAtIso: createdAtIso,
        writeOffDate: '2026-06-12',
        members: [
          MergedProjectSettlementMemberRequest(
            projectId: 'project:m1',
            projectKey: '甲方||project:m1',
            receivable: 100.0,
          ),
          MergedProjectSettlementMemberRequest(
            projectId: 'project:m2',
            projectKey: '甲方||project:m2',
            receivable: 50.0,
          ),
        ],
        allocations: [
          MergedProjectSettlementAllocationRequest(
            projectId: 'project:m1',
            projectKey: '甲方||project:m1',
            receivable: 100.0,
            writeOffAmount: 40.0,
            writeOffId: 'wo-m1',
          ),
        ],
      ),
    );
    expect(result.settled, isTrue);

    final m1 = (await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: ['project:m1'],
    )).single;
    final s1 = ProjectSettledSnapshot.tryDecode(
      m1['settled_snapshot'] as String?,
    );
    expect(m1['status'], ProjectStatus.settled.name);
    expect(s1, isNotNull, reason: '分摊结清路径成员必须落快照');
    expect(s1!.receivableFen, 10000);
    expect(s1.receivedFen, 6000);
    expect(s1.writeOffFen, 4000);
    expect(s1.remainingFen, 0);

    final m2 = (await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: ['project:m2'],
    )).single;
    final s2 = ProjectSettledSnapshot.tryDecode(
      m2['settled_snapshot'] as String?,
    );
    expect(m2['status'], ProjectStatus.settled.name);
    expect(s2, isNotNull, reason: '整组兜底路径成员必须落快照');
    expect(s2!.receivableFen, 5000);
    expect(s2.receivedFen, 5000);
    expect(s2.writeOffFen, 0);
    expect(s2.remainingFen, 0);
  });

  test('tryDecode is defensive against malformed snapshots', () {
    expect(ProjectSettledSnapshot.tryDecode(null), isNull);
    expect(ProjectSettledSnapshot.tryDecode(''), isNull);
    expect(ProjectSettledSnapshot.tryDecode('not-json'), isNull);
    expect(ProjectSettledSnapshot.tryDecode('[1,2]'), isNull);
    expect(
      ProjectSettledSnapshot.tryDecode('{"receivable_fen":"x"}'),
      isNull,
    );

    final roundTrip = ProjectSettledSnapshot.tryDecode(
      const ProjectSettledSnapshot(
        receivableFen: 10000,
        receivedFen: 9000,
        writeOffFen: 1000,
        remainingFen: 0,
        settledAt: createdAtIso,
      ).encode(),
    );
    expect(roundTrip!.receivableFen, 10000);
    expect(roundTrip.receivedFen, 9000);
    expect(roundTrip.writeOffFen, 1000);
    expect(roundTrip.remainingFen, 0);
    expect(roundTrip.settledAt, createdAtIso);
  });
}

Future<Database> _openCurrentInMemoryDb() {
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
  return AppDatabase.database;
}

Future<void> _seedProject(Database db, {required String projectId}) async {
  await db.insert(
    'projects',
    Project(
      id: projectId,
      contact: '甲方',
      site: projectId,
      createdAt: '2026-06-01T00:00:00.000Z',
      updatedAt: '2026-06-01T00:00:00.000Z',
    ).toMap(),
  );
}

Future<void> _insertPaymentRow(
  Database db, {
  required String projectId,
  required int amountFen,
}) async {
  await db.insert(SqfliteAccountPaymentRepository.table, <String, Object?>{
    'project_id': projectId,
    'project_key': '甲方||$projectId',
    'ymd': 20260601,
    'amount': amountFen / 100,
    'amount_fen': amountFen,
    'note': null,
    'source_type': 'manual',
    'created_at': '2026-06-01T00:00:00.000Z',
  });
}
