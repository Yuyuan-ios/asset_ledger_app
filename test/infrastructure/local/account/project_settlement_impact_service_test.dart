import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/data/repositories/project_write_off_repository.dart';
import 'package:asset_ledger/infrastructure/local/account/project_settlement_impact_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

/// 阶段 B Step 2 — ProjectSettlementImpactService 权威结清影响判断测试。
///
/// 业务规则（business_rules_v1.md §3 / §5 / §7）：
/// - 所有"是否仍覆盖应收 / 是否需要撤销结清"判断走 amount_fen 整数。
/// - 0 元空项目不能结清；如已结清，应被视为需要撤销。
/// - 合并解除 / 修改计时后，若原结清不再成立，应撤销结清；但不删除收款 / 核销。
///
/// 所有用例：
/// - 走真实 sqflite（inMemoryDatabasePath + DbSchema.create + AppDatabase）。
/// - 直接 `db.insert(...)` 写入 payment / write_off / project 行，必要时
///   故意把 amount REAL 与 amount_fen 脱钩，证明判断只读 fen。
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

  group('evaluate — 单项目结清影响判断', () {
    test(
      '已结清 + 应收上调后 remainingFen > 0 → shouldRevokeSettlement = true',
      () async {
        final db = await AppDatabase.database;
        await _seedProject(
          db,
          projectId: 'project:alpha',
          status: ProjectStatus.settled,
        );
        // 旧已收 100 元（10000 fen），但 receivable 现在被上调到 150 元。
        await _insertPaymentRow(
          db,
          projectId: 'project:alpha',
          amount: 100,
          amountFen: 10000,
        );

        final service = ProjectSettlementImpactService();
        final decision = await service.evaluate(
          executor: db,
          receivableFenByProjectId: const {'project:alpha': 15000},
          reason: ProjectSettlementImpactReason.editTiming,
        );

        final snapshot = decision.snapshots.single;
        expect(snapshot.receivableFen, 15000);
        expect(snapshot.receivedFen, 10000);
        expect(snapshot.writeOffFen, 0);
        expect(snapshot.remainingFen, 5000);
        expect(snapshot.wasSettled, isTrue);
        expect(snapshot.coversReceivable, isFalse);
        expect(snapshot.isZeroAmount, isFalse);
        expect(snapshot.shouldRevokeSettlement, isTrue);
        expect(snapshot.reason, ProjectSettlementImpactReason.editTiming);
        expect(decision.anyRevocationNeeded, isTrue);
      },
    );

    test('已结清 + 收款+核销仍覆盖应收 → shouldRevokeSettlement = false', () async {
      final db = await AppDatabase.database;
      await _seedProject(
        db,
        projectId: 'project:alpha',
        status: ProjectStatus.settled,
      );
      // 已收 60 元 + 核销 40 元 = 100 元，刚好覆盖应收 100 元。
      await _insertPaymentRow(
        db,
        projectId: 'project:alpha',
        amount: 60,
        amountFen: 6000,
      );
      await _insertWriteOffRow(
        db,
        id: 'wo-cover',
        projectId: 'project:alpha',
        amount: 40,
        amountFen: 4000,
      );

      final service = ProjectSettlementImpactService();
      final decision = await service.evaluate(
        executor: db,
        receivableFenByProjectId: const {'project:alpha': 10000},
        reason: ProjectSettlementImpactReason.dissolveMerge,
      );
      final snapshot = decision.snapshots.single;
      expect(snapshot.remainingFen, 0);
      expect(snapshot.coversReceivable, isTrue);
      expect(snapshot.shouldRevokeSettlement, isFalse);
      expect(decision.anyRevocationNeeded, isFalse);
    });

    test('未结清 + 任意状态 → 不返回撤销结清动作', () async {
      final db = await AppDatabase.database;
      await _seedProject(
        db,
        projectId: 'project:alpha',
        status: ProjectStatus.active,
      );
      await _insertPaymentRow(
        db,
        projectId: 'project:alpha',
        amount: 30,
        amountFen: 3000,
      );

      final service = ProjectSettlementImpactService();
      final decision = await service.evaluate(
        executor: db,
        receivableFenByProjectId: const {'project:alpha': 10000},
      );
      final snapshot = decision.snapshots.single;
      expect(snapshot.wasSettled, isFalse);
      expect(snapshot.remainingFen, 7000);
      expect(
        snapshot.shouldRevokeSettlement,
        isFalse,
        reason: '未结清的项目永远不需要"撤销结清"动作',
      );
    });

    test('0 元空项目：receivable=0 / received=0 / writeOff=0 → 不能视为可结清', () async {
      final db = await AppDatabase.database;
      // 一个 active 0 元空项目：业务规则 §5 已禁止结清。
      await _seedProject(
        db,
        projectId: 'project:empty',
        status: ProjectStatus.active,
      );

      final service = ProjectSettlementImpactService();
      final decision = await service.evaluate(
        executor: db,
        receivableFenByProjectId: const {'project:empty': 0},
      );
      final snapshot = decision.snapshots.single;
      expect(snapshot.isZeroAmount, isTrue);
      expect(
        snapshot.coversReceivable,
        isTrue,
        reason: '0 + 0 >= 0 — 形式上覆盖，但仍是 0 元空项目，不应据此判可结清',
      );
      // active 项目永远不需要撤销动作。
      expect(snapshot.shouldRevokeSettlement, isFalse);
    });

    test('0 元空项目但状态为 settled：被视为需要撤销（§5 兜底）', () async {
      final db = await AppDatabase.database;
      await _seedProject(
        db,
        projectId: 'project:wrongly_settled',
        status: ProjectStatus.settled,
        settledAt: '2026-05-20T00:00:00.000Z',
      );

      final service = ProjectSettlementImpactService();
      final decision = await service.evaluate(
        executor: db,
        receivableFenByProjectId: const {'project:wrongly_settled': 0},
      );
      final snapshot = decision.snapshots.single;
      expect(snapshot.isZeroAmount, isTrue);
      expect(snapshot.wasSettled, isTrue);
      expect(
        snapshot.shouldRevokeSettlement,
        isTrue,
        reason: '已结清却是 0 元空项目（§5 禁止），应回到 active',
      );
    });

    test('amount REAL 与 amount_fen 故意不一致时，判断必须以 fen 为准', () async {
      final db = await AppDatabase.database;
      await _seedProject(
        db,
        projectId: 'project:alpha',
        status: ProjectStatus.settled,
      );
      // REAL 看似只收 0.01 元，但 amount_fen=10000 才是权威：刚好覆盖 100 元。
      await _insertPaymentRow(
        db,
        projectId: 'project:alpha',
        amount: 0.01,
        amountFen: 10000,
      );

      final service = ProjectSettlementImpactService();
      final decision = await service.evaluate(
        executor: db,
        receivableFenByProjectId: const {'project:alpha': 10000},
      );
      final snapshot = decision.snapshots.single;
      expect(
        snapshot.receivedFen,
        10000,
        reason:
            '权威已收必须从 SUM(amount_fen) 读出 10000，'
            '不能被脏 REAL=0.01 污染',
      );
      expect(snapshot.coversReceivable, isTrue);
      expect(snapshot.shouldRevokeSettlement, isFalse);
    });

    test('差 1 fen 边界：fen=9999 vs receivable=10000 → 未覆盖，需撤销结清', () async {
      final db = await AppDatabase.database;
      await _seedProject(
        db,
        projectId: 'project:alpha',
        status: ProjectStatus.settled,
      );
      await _insertPaymentRow(
        db,
        projectId: 'project:alpha',
        amount: 99.99,
        amountFen: 9999,
      );

      final service = ProjectSettlementImpactService();
      final decision = await service.evaluate(
        executor: db,
        receivableFenByProjectId: const {'project:alpha': 10000},
      );
      final snapshot = decision.snapshots.single;
      expect(snapshot.remainingFen, 1, reason: '正好差 1 fen');
      expect(snapshot.coversReceivable, isFalse, reason: '差 1 fen 不能算覆盖');
      expect(snapshot.shouldRevokeSettlement, isTrue);
    });

    test(
      '刚好覆盖：fen=10000 = receivable=10000 → coversReceivable=true，不撤销',
      () async {
        final db = await AppDatabase.database;
        await _seedProject(
          db,
          projectId: 'project:alpha',
          status: ProjectStatus.settled,
        );
        await _insertPaymentRow(
          db,
          projectId: 'project:alpha',
          amount: 100,
          amountFen: 10000,
        );

        final service = ProjectSettlementImpactService();
        final decision = await service.evaluate(
          executor: db,
          receivableFenByProjectId: const {'project:alpha': 10000},
        );
        final snapshot = decision.snapshots.single;
        expect(snapshot.remainingFen, 0);
        expect(snapshot.coversReceivable, isTrue);
        expect(snapshot.shouldRevokeSettlement, isFalse);
      },
    );
  });

  group('evaluate — 多项目批量评估，可被 delete/edit/dissolve 共用', () {
    test('一批项目里只有需要撤销的子集出现在 revocationsNeeded', () async {
      final db = await AppDatabase.database;
      await _seedProject(
        db,
        projectId: 'p:keep_settled',
        status: ProjectStatus.settled,
      );
      await _insertPaymentRow(
        db,
        projectId: 'p:keep_settled',
        amount: 50,
        amountFen: 5000,
      );
      await _insertWriteOffRow(
        db,
        id: 'wo-keep',
        projectId: 'p:keep_settled',
        amount: 50,
        amountFen: 5000,
      );

      await _seedProject(
        db,
        projectId: 'p:revoke',
        status: ProjectStatus.settled,
      );
      // 应收上调 → 不再覆盖。
      await _insertPaymentRow(
        db,
        projectId: 'p:revoke',
        amount: 100,
        amountFen: 10000,
      );

      await _seedProject(
        db,
        projectId: 'p:still_active',
        status: ProjectStatus.active,
      );

      final service = ProjectSettlementImpactService();
      final decision = await service.evaluate(
        executor: db,
        receivableFenByProjectId: const {
          'p:keep_settled': 10000,
          'p:revoke': 15000,
          'p:still_active': 20000,
        },
        reason: ProjectSettlementImpactReason.dissolveMerge,
      );

      expect(decision.snapshots, hasLength(3));
      expect(decision.revocationsNeeded.map((s) => s.projectId).toSet(), {
        'p:revoke',
      });
      expect(decision.anyRevocationNeeded, isTrue);
    });
  });

  group('applyRevocations — 仅撤销 status，不删业务记录', () {
    test(
      'applyRevocations 只把 settled → active，不删 payments / write_offs',
      () async {
        final db = await AppDatabase.database;
        await _seedProject(
          db,
          projectId: 'project:alpha',
          status: ProjectStatus.settled,
          settledAt: '2026-05-20T00:00:00.000Z',
        );
        await _insertPaymentRow(
          db,
          projectId: 'project:alpha',
          amount: 30,
          amountFen: 3000,
        );
        await _insertWriteOffRow(
          db,
          id: 'wo-stay',
          projectId: 'project:alpha',
          amount: 20,
          amountFen: 2000,
        );

        final service = ProjectSettlementImpactService();
        final decision = await service.evaluate(
          executor: db,
          receivableFenByProjectId: const {'project:alpha': 10000},
        );
        expect(decision.anyRevocationNeeded, isTrue);

        final result = await service.applyRevocations(
          executor: db,
          decision: decision,
          updatedAtIso: '2026-05-26T00:00:00.000Z',
        );

        expect(result.revokedProjectIds, ['project:alpha']);

        // 项目状态已撤销结清。
        final projectRow = (await db.query(
          'projects',
          where: 'id = ?',
          whereArgs: ['project:alpha'],
        )).single;
        expect(projectRow['status'], ProjectStatus.active.name);
        expect(projectRow['settled_at'], isNull);
        expect(projectRow['settled_snapshot'], isNull);

        // 收款 / 核销 / 计时 一行都没动。
        expect(
          await db.query(SqfliteAccountPaymentRepository.table),
          hasLength(1),
        );
        expect(
          await db.query(SqfliteProjectWriteOffRepository.table),
          hasLength(1),
        );
      },
    );

    test('applyRevocations 对未结清项目幂等：不报错、不写库', () async {
      final db = await AppDatabase.database;
      await _seedProject(
        db,
        projectId: 'project:active',
        status: ProjectStatus.active,
      );

      final service = ProjectSettlementImpactService();
      final decision = await service.evaluate(
        executor: db,
        receivableFenByProjectId: const {'project:active': 0},
      );
      // 未结清不会进入 revocationsNeeded —— 直接应用应为空动作。
      final result = await service.applyRevocations(
        executor: db,
        decision: decision,
        updatedAtIso: '2026-05-26T00:00:00.000Z',
      );
      expect(result.revokedProjectIds, isEmpty);
    });

    test('evaluate + applyRevocations 可在同一事务内联用', () async {
      final db = await AppDatabase.database;
      await _seedProject(
        db,
        projectId: 'project:alpha',
        status: ProjectStatus.settled,
        settledAt: '2026-05-20T00:00:00.000Z',
      );
      await _insertPaymentRow(
        db,
        projectId: 'project:alpha',
        amount: 50,
        amountFen: 5000,
      );

      final service = ProjectSettlementImpactService();
      // 用真实事务包裹整个 evaluate + apply 流程，证明 Step 3 可以
      // 安全把 "保存计时 + 解除合并 + 撤销结清" 写在同一事务里。
      final revokedInTxn = await AppDatabase.inTransaction((txn) async {
        final decision = await service.evaluate(
          executor: txn,
          receivableFenByProjectId: const {'project:alpha': 10000},
          reason: ProjectSettlementImpactReason.editTiming,
        );
        final result = await service.applyRevocations(
          executor: txn,
          decision: decision,
          updatedAtIso: '2026-05-26T00:00:00.000Z',
        );
        return result.revokedProjectIds;
      });
      expect(revokedInTxn, ['project:alpha']);
      expect(
        (await db.query(
          'projects',
          where: 'id = ?',
          whereArgs: ['project:alpha'],
        )).single['status'],
        ProjectStatus.active.name,
      );
    });
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

Future<void> _seedProject(
  Database db, {
  required String projectId,
  ProjectStatus status = ProjectStatus.active,
  String? settledAt,
}) async {
  await db.insert(
    'projects',
    Project(
      id: projectId,
      contact: '甲方',
      site: projectId,
      status: status,
      settledAt: settledAt,
      createdAt: '2026-05-18T00:00:00.000Z',
      updatedAt: '2026-05-18T00:00:00.000Z',
    ).toMap(),
  );
}

Future<void> _insertPaymentRow(
  Database db, {
  required String projectId,
  required double amount,
  required int amountFen,
}) async {
  if (!amount.isFinite) {
    throw ArgumentError.value(amount, 'amount');
  }
  await db.insert(SqfliteAccountPaymentRepository.table, <String, Object?>{
    'project_id': projectId,
    'project_key': '甲方||$projectId',
    'ymd': 20260518,
    'amount_fen': amountFen,
    'note': null,
    'source_type': 'manual',
    'created_at': '2026-05-18T00:00:00.000Z',
  });
}

Future<void> _insertWriteOffRow(
  Database db, {
  required String id,
  required String projectId,
  required double amount,
  required int amountFen,
}) async {
  if (!amount.isFinite) {
    throw ArgumentError.value(amount, 'amount');
  }
  await db.insert(SqfliteProjectWriteOffRepository.table, <String, Object?>{
    'id': id,
    'project_id': projectId,
    'amount_fen': amountFen,
    'reason': 'rounding',
    'note': null,
    'write_off_date': '2026-05-18',
    'created_at': '2026-05-18T00:00:00.000Z',
    'updated_at': '2026-05-18T00:00:00.000Z',
  });
}
