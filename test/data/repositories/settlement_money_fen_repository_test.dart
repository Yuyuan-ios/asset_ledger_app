import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/data/repositories/project_write_off_repository.dart';
import 'package:asset_ledger/features/account/domain/repositories/project_settlement_repository.dart';
import 'package:asset_ledger/infrastructure/local/account/local_project_settlement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

/// 阶段 B Step 1 — 金额 fen 权威汇总回归测试。
///
/// 业务规则（business_rules_v1.md §3）：
/// - 数据库 / 计算 / 汇总统一使用 amount_fen。
/// - 财务判断、结清判断、核销判断不得依赖 REAL amount 字段。
/// - Track A / A4-5 后 project_write_offs.amount REAL 已拆除。
///
/// 本测试用整数分裸落库来检测权威路径：如果某个 SUM 没有走 amount_fen，
/// 结果会偏离预期；走 fen 才能稳定通过。
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

  group('ProjectWriteOffRepository sum 权威走 amount_fen', () {
    test('sum 必须以 amount_fen 为准', () async {
      final db = await AppDatabase.database;
      await _seedProject(db, projectId: 'project:alpha');

      // 写入两行：amount_fen 为权威 12345 / 6789。
      await _insertWriteOffRow(
        db,
        id: 'wo-bad-real-1',
        projectId: 'project:alpha',
        amount: 999.99,
        amountFen: 12345,
      );
      await _insertWriteOffRow(
        db,
        id: 'wo-bad-real-2',
        projectId: 'project:alpha',
        amount: 999.99,
        amountFen: 6789,
      );

      final repository = SqfliteProjectWriteOffRepository();
      // 公共 yuan API：以 fen 汇总后再 / 100。
      expect(
        await repository.sumByProjectId('project:alpha'),
        (12345 + 6789) / 100.0,
        reason: '权威汇总应以 SUM(amount_fen) 为准',
      );
      expect(await repository.sumByProjectIds(['project:alpha']), {
        'project:alpha': (12345 + 6789) / 100.0,
      });

      // fen API：直接返回 int fen。
      expect(await repository.sumFenByProjectId('project:alpha'), 12345 + 6789);
      expect(await repository.sumFenByProjectIds(['project:alpha']), {
        'project:alpha': 12345 + 6789,
      });
    });

    test('0.1 + 0.2 的 REAL 累加误差不会污染 fen 汇总', () async {
      final db = await AppDatabase.database;
      await _seedProject(db, projectId: 'project:alpha');
      await _insertWriteOffRow(
        db,
        id: 'wo-0.1',
        projectId: 'project:alpha',
        amount: 0.1,
        amountFen: 10,
      );
      await _insertWriteOffRow(
        db,
        id: 'wo-0.2',
        projectId: 'project:alpha',
        amount: 0.2,
        amountFen: 20,
      );

      final repository = SqfliteProjectWriteOffRepository();
      expect(
        await repository.sumFenByProjectId('project:alpha'),
        30,
        reason: 'fen 整数汇总不应该有 0.30000000000000004 这种漂移',
      );
      expect(
        await repository.sumByProjectId('project:alpha'),
        0.3,
        reason: '由 fen / 100 还原 yuan，结果必须是干净的 0.3',
      );
    });
  });

  group('LocalProjectSettlementRepository settle / 撤销 以 fen 为权威', () {
    test('settle 判断结清以 amount_fen 为准（REAL amount 被脏数据污染时仍然结清）', () async {
      final db = await AppDatabase.database;
      await _seedProject(db, projectId: 'project:alpha');

      // 旧已收：amount REAL 写脏（0.01），amount_fen=9000 才是权威已收 90 元。
      await _insertPaymentRow(
        db,
        projectId: 'project:alpha',
        amount: 0.01,
        amountFen: 9000,
      );

      // receivable = 100 元，已收 90 元，再收 10 元 → 应结清；并且这一收 10 元
      // 不应该被旧脏 REAL（0.01）误判为"远超待收"。
      final repo = const LocalProjectSettlementRepository();
      final result = await repo.settle(
        const ProjectSettlementRequest(
          projectId: 'project:alpha',
          projectKey: '甲方||alpha',
          receivable: 100.0,
          paymentAmount: 10.0,
          writeOffAmount: 0,
          writeOffReasonDbValue: null,
          ymd: 20260526,
          createdAtIso: '2026-05-26T00:00:00.000Z',
          writeOffDate: '2026-05-26',
        ),
      );

      expect(result.settled, isTrue, reason: '应基于 fen 判断为已结清');
      expect(result.receivedBefore, 90.0);
      expect(result.remainingBefore, 10.0);
      expect(result.receivedAfter, 100.0);
      expect(result.remainingAfter, 0.0);

      final projectRow = (await db.query(
        'projects',
        where: 'id = ?',
        whereArgs: ['project:alpha'],
      )).single;
      expect(projectRow['status'], ProjectStatus.settled.name);
    });

    test('settle 抛错"已结清"以 fen 为准：amount_fen 已覆盖待收时，应拒绝再次结清', () async {
      final db = await AppDatabase.database;
      await _seedProject(db, projectId: 'project:alpha');

      // REAL 显示只收 0.01，但 amount_fen=10000 才是权威：已经覆盖 100 元待收。
      await _insertPaymentRow(
        db,
        projectId: 'project:alpha',
        amount: 0.01,
        amountFen: 10000,
      );

      final repo = const LocalProjectSettlementRepository();
      await expectLater(
        repo.settle(
          const ProjectSettlementRequest(
            projectId: 'project:alpha',
            projectKey: '甲方||alpha',
            receivable: 100.0,
            paymentAmount: 1.0,
            writeOffAmount: 0,
            writeOffReasonDbValue: null,
            ymd: 20260526,
            createdAtIso: '2026-05-26T00:00:00.000Z',
            writeOffDate: '2026-05-26',
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('已结清'),
          ),
        ),
        reason:
            'remaining = 100 - 100 = 0 在 fen 下应判已结清，'
            '不应被脏 REAL（0.01）误判为还差很多',
      );
    });

    test('settle 判断超出待收以 fen 为准：REAL 看似还差很多，fen 已接近覆盖', () async {
      final db = await AppDatabase.database;
      await _seedProject(db, projectId: 'project:alpha');

      // REAL 0.01，但 amount_fen=9999 = 99.99 元（权威），仅差 1 分。
      await _insertPaymentRow(
        db,
        projectId: 'project:alpha',
        amount: 0.01,
        amountFen: 9999,
      );

      final repo = const LocalProjectSettlementRepository();
      // 还差 0.01 元 / 1 fen，再收 10 元应被拒。
      await expectLater(
        repo.settle(
          const ProjectSettlementRequest(
            projectId: 'project:alpha',
            projectKey: '甲方||alpha',
            receivable: 100.0,
            paymentAmount: 10.0,
            writeOffAmount: 0,
            writeOffReasonDbValue: null,
            ymd: 20260526,
            createdAtIso: '2026-05-26T00:00:00.000Z',
            writeOffDate: '2026-05-26',
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('超出当前待收'),
          ),
        ),
      );

      // 收 0.01 元应成功并结清。
      final result = await repo.settle(
        const ProjectSettlementRequest(
          projectId: 'project:alpha',
          projectKey: '甲方||alpha',
          receivable: 100.0,
          paymentAmount: 0.01,
          writeOffAmount: 0,
          writeOffReasonDbValue: null,
          ymd: 20260526,
          createdAtIso: '2026-05-26T00:00:00.000Z',
          writeOffDate: '2026-05-26',
        ),
      );
      expect(result.settled, isTrue);
      expect(result.remainingAfter, 0.0);
    });

    test('删除核销时撤销结清判断以 fen 为权威', () async {
      final db = await AppDatabase.database;
      await _seedProject(
        db,
        projectId: 'project:alpha',
        status: ProjectStatus.settled,
        settledAt: '2026-05-20T00:00:00.000Z',
      );
      // 已收 10 元；剩余 90 元被核销冲账掉了。amount REAL 故意写脏。
      await _insertPaymentRow(
        db,
        projectId: 'project:alpha',
        amount: 0.01,
        amountFen: 1000,
      );
      await _insertWriteOffRow(
        db,
        id: 'wo-target',
        projectId: 'project:alpha',
        amount: 999.99,
        amountFen: 9000,
      );

      final repo = const LocalProjectSettlementRepository();
      final result = await repo.deleteWriteOff(
        const DeleteProjectWriteOffRequest(
          projectId: 'project:alpha',
          writeOffId: 'wo-target',
          receivable: 100.0,
          updatedAtIso: '2026-05-26T00:00:00.000Z',
        ),
      );

      // 删除后还差 90 元（10000 - 1000 - 0 = 9000 fen），结清应撤销。
      expect(result.restoredActive, isTrue);
      expect(result.remainingAfter, 90.0);

      final projectRow = (await db.query(
        'projects',
        where: 'id = ?',
        whereArgs: ['project:alpha'],
      )).single;
      expect(projectRow['status'], ProjectStatus.active.name);
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

/// 直接落库一行 write_off：只写 amount_fen，用来探测权威 SUM 走的是哪一列。
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

/// 直接落库一行 payment：amount REAL 与 amount_fen 故意脱钩。
Future<void> _insertPaymentRow(
  Database db, {
  required String projectId,
  required double amount,
  required int amountFen,
}) async {
  await db.insert(SqfliteAccountPaymentRepository.table, <String, Object?>{
    'project_id': projectId,
    'project_key': '甲方||$projectId',
    'ymd': 20260518,
    'amount': amount,
    'amount_fen': amountFen,
    'note': null,
    'source_type': 'manual',
    'created_at': '2026-05-18T00:00:00.000Z',
  });
}
