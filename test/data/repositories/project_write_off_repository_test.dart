import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/repositories/project_write_off_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late SqfliteProjectWriteOffRepository repository;

  setUp(() async {
    await AppDatabase.resetForTest();
    await _openCurrentInMemoryDb();
    repository = SqfliteProjectWriteOffRepository();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  test('inserts, lists, sums, and deletes project write-offs', () async {
    final db = await AppDatabase.database;
    await _seedProject(db, projectId: 'project:alpha');
    await _seedProject(db, projectId: 'project:beta');

    await repository.insert(
      _writeOff(
        id: 'write-off-1',
        projectId: 'project:alpha',
        amount: 60,
        reason: ProjectWriteOffReason.rounding.dbValue,
      ),
    );
    await repository.insert(
      _writeOff(
        id: 'write-off-2',
        projectId: 'project:alpha',
        amount: 40,
        reason: ProjectWriteOffReason.underpaid.dbValue,
      ),
    );
    await repository.insert(
      _writeOff(
        id: 'write-off-3',
        projectId: 'project:beta',
        amount: 25,
        reason: ProjectWriteOffReason.settlement.dbValue,
      ),
    );
    final rawRows = await db.query(
      'project_write_offs',
      where: 'id = ?',
      whereArgs: ['write-off-1'],
    );
    expect(rawRows.single['amount_fen'], 6000);

    final alphaRows = await repository.listByProjectId('project:alpha');
    expect(alphaRows.map((row) => row.id).toSet(), {
      'write-off-1',
      'write-off-2',
    });
    expect(await repository.listAll(), hasLength(3));
    expect(await repository.sumByProjectId('project:alpha'), 100);
    expect(
      await repository.sumByProjectIds(['project:alpha', 'project:beta']),
      {'project:alpha': 100, 'project:beta': 25},
    );

    await repository.deleteById('write-off-1');

    expect(await repository.sumByProjectId('project:alpha'), 40);
    expect(await repository.listByProjectId('project:alpha'), hasLength(1));
  });

  test('update replaces an existing project write-off row', () async {
    final db = await AppDatabase.database;
    await _seedProject(db, projectId: 'project:alpha');
    await repository.insert(_writeOff(id: 'write-off-1'));

    final count = await repository.update(
      _writeOff(
        id: 'write-off-1',
        amount: 80,
        reason: ProjectWriteOffReason.badDebt.dbValue,
        note: '尾款坏账',
      ),
    );

    final rows = await repository.listByProjectId('project:alpha');
    expect(count, 1);
    expect(rows.single.amount, 80);
    expect(rows.single.reason, ProjectWriteOffReason.badDebt.dbValue);
    expect(rows.single.note, '尾款坏账');
  });

  test('rejects invalid write-off rows before inserting', () async {
    final db = await AppDatabase.database;
    await _seedProject(db, projectId: 'project:alpha');

    await expectLater(
      repository.insert(_writeOff(id: '', amount: 10)),
      throwsArgumentError,
    );
    await expectLater(
      repository.insert(_writeOff(projectId: '', amount: 10)),
      throwsArgumentError,
    );
    await expectLater(
      repository.insert(_writeOff(amount: 0)),
      throwsArgumentError,
    );
    await expectLater(
      repository.insert(_writeOff(reason: '')),
      throwsArgumentError,
    );
    await expectLater(
      repository.insert(_writeOff(writeOffDate: '')),
      throwsArgumentError,
    );
    await expectLater(
      repository.insert(_writeOff(createdAt: '')),
      throwsArgumentError,
    );
    await expectLater(
      repository.insert(_writeOff(updatedAt: '')),
      throwsArgumentError,
    );
  });

  test('clearAllForRestore removes all project write-offs', () async {
    final db = await AppDatabase.database;
    await _seedProject(db, projectId: 'project:alpha');
    await repository.insert(_writeOff(id: 'write-off-1'));
    await repository.insert(_writeOff(id: 'write-off-2', amount: 20));

    final count = await repository.clearAllForRestore();

    expect(count, 2);
    expect(await repository.listAll(), isEmpty);
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
      createdAt: '2026-05-18T00:00:00.000Z',
      updatedAt: '2026-05-18T00:00:00.000Z',
    ).toMap(),
  );
}

ProjectWriteOff _writeOff({
  String id = 'write-off-1',
  String projectId = 'project:alpha',
  double amount = 60,
  String reason = 'rounding',
  String? note,
  String writeOffDate = '2026-05-18',
  String createdAt = '2026-05-18T00:00:00.000Z',
  String updatedAt = '2026-05-18T00:00:00.000Z',
}) {
  return ProjectWriteOff(
    id: id,
    projectId: projectId,
    amount: amount,
    reason: reason,
    note: note,
    writeOffDate: writeOffDate,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
