import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/repositories/project_write_off_repository.dart';
import 'package:asset_ledger/features/account/use_cases/project_settlement_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  group('ProjectSettlementUseCase', () {
    test('settles a project with a full cash payment', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db);
      await _seedPayment(db, amount: 500);
      final useCase = _useCase();

      final result = await useCase.execute(
        projectId: 'project:1',
        projectKey: '甲方||一号工地',
        receivable: 2600,
        paymentAmount: 2100,
        writeOffAmount: 0,
        writeOffReason: null,
        ymd: 20260518,
      );

      expect(result.settled, isTrue);
      expect(result.receivedAfter, 2600);
      expect(result.writeOffAfter, 0);
      expect(result.remainingAfter, 0);
      expect(await _paymentCount(db), 2);
      expect(await _paymentSum(db), 2600);
      expect(await _writeOffCount(db), 0);
      expect(await _projectStatus(db), ProjectStatus.settled);
    });

    test(
      'settles a project with write-off only without increasing received',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProject(db);
        await _seedPayment(db, amount: 1200);
        final useCase = _useCase();

        final result = await useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 1260,
          paymentAmount: 0,
          writeOffAmount: 60,
          writeOffReason: ProjectWriteOffReason.rounding,
          ymd: 20260518,
          note: '尾款抹零',
        );

        expect(result.receivable, 1260);
        expect(result.receivedAfter, 1200);
        expect(result.writeOffAfter, 60);
        expect(result.remainingAfter, 0);
        expect(await _paymentCount(db), 1);
        expect(await _paymentSum(db), 1200);
        final writeOffs = await _writeOffRows(db);
        expect(writeOffs, hasLength(1));
        expect(writeOffs.single.amount, 60);
        expect(writeOffs.single.reason, ProjectWriteOffReason.rounding.dbValue);
        expect(writeOffs.single.note, '尾款抹零');
        expect(await _projectStatus(db), ProjectStatus.settled);
      },
    );

    test('settles a project with payment plus write-off', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db);
      await _seedPayment(db, amount: 5000);
      final useCase = _useCase();

      final result = await useCase.execute(
        projectId: 'project:1',
        projectKey: '甲方||一号工地',
        receivable: 20000,
        paymentAmount: 5000,
        writeOffAmount: 10000,
        writeOffReason: ProjectWriteOffReason.settlement,
        ymd: 20260518,
      );

      expect(result.receivedAfter, 10000);
      expect(result.writeOffAfter, 10000);
      expect(result.remainingAfter, 0);
      expect(await _paymentCount(db), 2);
      expect(await _paymentSum(db), 10000);
      expect(await _writeOffCount(db), 1);
      expect(await _writeOffSum(db), 10000);
      expect(await _projectStatus(db), ProjectStatus.settled);
    });

    test('requires a reason when write-off amount is positive', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db);
      final useCase = _useCase();

      await expectLater(
        useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 1000,
          paymentAmount: 900,
          writeOffAmount: 100,
          writeOffReason: null,
          ymd: 20260518,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _paymentCount(db), 0);
      expect(await _writeOffCount(db), 0);
      expect(await _projectStatus(db), ProjectStatus.active);
    });

    test('rejects payment amount above remaining', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db);
      await _seedPayment(db, amount: 400);
      final useCase = _useCase();

      await expectLater(
        useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 1000,
          paymentAmount: 700,
          writeOffAmount: 0,
          writeOffReason: null,
          ymd: 20260518,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _paymentCount(db), 1);
      expect(await _writeOffCount(db), 0);
      expect(await _projectStatus(db), ProjectStatus.active);
    });

    test('rejects negative payment and write-off amounts', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db);
      final useCase = _useCase();

      await expectLater(
        useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 1000,
          paymentAmount: -1,
          writeOffAmount: 0,
          writeOffReason: null,
          ymd: 20260518,
        ),
        throwsArgumentError,
      );
      await expectLater(
        useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 1000,
          paymentAmount: 0,
          writeOffAmount: -1,
          writeOffReason: ProjectWriteOffReason.other,
          ymd: 20260518,
        ),
        throwsArgumentError,
      );

      expect(await _paymentCount(db), 0);
      expect(await _writeOffCount(db), 0);
    });

    test('rejects repeat settlement after remaining reaches zero', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db);
      await _seedPayment(db, amount: 1000);
      final useCase = _useCase();

      await expectLater(
        useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 1000,
          paymentAmount: 1,
          writeOffAmount: 0,
          writeOffReason: null,
          ymd: 20260518,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _paymentCount(db), 1);
      expect(await _writeOffCount(db), 0);
    });

    test(
      'repeat calls do not create duplicate payment or write-off rows',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProject(db);
        await _seedPayment(db, amount: 1200);
        final useCase = _useCase();

        await useCase.execute(
          projectId: 'project:1',
          projectKey: '甲方||一号工地',
          receivable: 1260,
          paymentAmount: 0,
          writeOffAmount: 60,
          writeOffReason: ProjectWriteOffReason.rounding,
          ymd: 20260518,
        );

        await expectLater(
          useCase.execute(
            projectId: 'project:1',
            projectKey: '甲方||一号工地',
            receivable: 1260,
            paymentAmount: 0,
            writeOffAmount: 60,
            writeOffReason: ProjectWriteOffReason.rounding,
            ymd: 20260518,
          ),
          throwsA(isA<StateError>()),
        );

        expect(await _paymentCount(db), 1);
        expect(await _writeOffCount(db), 1);
        expect(await _projectStatus(db), ProjectStatus.settled);
      },
    );

    test(
      'deletes write-off and restores a settled project to active',
      () async {
        final db = await _openCurrentInMemoryDb();
        await _seedProject(db, status: ProjectStatus.settled);
        await _seedPayment(db, amount: 1200);
        await _seedWriteOff(db, amount: 60);
        final useCase = _useCase();

        final result = await useCase.deleteWriteOff(
          projectId: 'project:1',
          writeOffId: 'write-off-1',
          receivable: 1260,
        );

        expect(result.deletedAmount, 60);
        expect(result.receivable, 1260);
        expect(result.received, 1200);
        expect(result.writeOffBefore, 60);
        expect(result.writeOffAfter, 0);
        expect(result.remainingAfter, 60);
        expect(result.restoredActive, isTrue);
        expect(await _paymentCount(db), 1);
        expect(await _paymentSum(db), 1200);
        expect(await _writeOffCount(db), 0);
        expect(await _writeOffSum(db), 0);
        final project = await _projectRow(db);
        expect(project.status, ProjectStatus.active);
        expect(project.settledAt, isNull);
      },
    );

    test('deleting write-off does not change payments or receivable', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db, status: ProjectStatus.settled);
      await _seedPayment(db, amount: 1200);
      await _seedWriteOff(db, amount: 60);
      final useCase = _useCase();

      final result = await useCase.deleteWriteOff(
        projectId: 'project:1',
        writeOffId: 'write-off-1',
        receivable: 1260,
      );

      expect(result.receivable, 1260);
      expect(result.received, 1200);
      expect(await _paymentCount(db), 1);
      expect(await _paymentSum(db), 1200);
      expect(await _writeOffCount(db), 0);
    });

    test('rolls back status when write-off delete target is missing', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedProject(db, status: ProjectStatus.settled);
      await _seedPayment(db, amount: 1200);
      await _seedWriteOff(db, amount: 60);
      final useCase = _useCase();

      await expectLater(
        useCase.deleteWriteOff(
          projectId: 'project:1',
          writeOffId: 'missing-write-off',
          receivable: 1260,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _writeOffCount(db), 1);
      expect(await _projectStatus(db), ProjectStatus.settled);
    });
  });
}

ProjectSettlementUseCase _useCase() {
  return ProjectSettlementUseCase(
    now: () => DateTime.utc(2026, 5, 18, 1, 2, 3),
    writeOffIdFactory: (_, _) => 'write-off-1',
  );
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

Future<void> _seedWriteOff(Database db, {required double amount}) async {
  await db.insert(
    SqfliteProjectWriteOffRepository.table,
    ProjectWriteOff(
      id: 'write-off-1',
      projectId: 'project:1',
      amount: amount,
      reason: ProjectWriteOffReason.rounding.dbValue,
      writeOffDate: '2026-05-18',
      createdAt: '2026-05-18T00:00:00.000Z',
      updatedAt: '2026-05-18T00:00:00.000Z',
    ).toMap(),
  );
}

Future<void> _seedPayment(Database db, {required double amount}) async {
  await db.insert(
    SqfliteAccountPaymentRepository.table,
    AccountPayment(
      projectId: 'project:1',
      projectKey: '甲方||一号工地',
      ymd: 20260501,
      amount: amount,
      createdAt: '2026-05-01T00:00:00.000Z',
    ).toMap(),
  );
}

Future<int> _paymentCount(Database db) async {
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS count FROM ${SqfliteAccountPaymentRepository.table}',
  );
  return (rows.single['count'] as num).toInt();
}

Future<double> _paymentSum(Database db) async {
  final rows = await db.rawQuery(
    'SELECT COALESCE(SUM(amount), 0) AS total FROM ${SqfliteAccountPaymentRepository.table}',
  );
  return (rows.single['total'] as num?)?.toDouble() ?? 0.0;
}

Future<int> _writeOffCount(Database db) async {
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS count FROM ${SqfliteProjectWriteOffRepository.table}',
  );
  return (rows.single['count'] as num).toInt();
}

Future<double> _writeOffSum(Database db) async {
  final rows = await db.rawQuery(
    'SELECT COALESCE(SUM(amount), 0) AS total FROM ${SqfliteProjectWriteOffRepository.table}',
  );
  return (rows.single['total'] as num?)?.toDouble() ?? 0.0;
}

Future<List<ProjectWriteOff>> _writeOffRows(Database db) async {
  final rows = await db.query(SqfliteProjectWriteOffRepository.table);
  return rows.map(ProjectWriteOff.fromMap).toList();
}

Future<ProjectStatus> _projectStatus(Database db) async {
  return (await _projectRow(db)).status;
}

Future<Project> _projectRow(Database db) async {
  final rows = await db.query(
    SqfliteProjectRepository.table,
    where: 'id = ?',
    whereArgs: ['project:1'],
  );
  return Project.fromMap(rows.single);
}
