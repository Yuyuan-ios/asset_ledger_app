import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

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

  group('SqfliteTimingRepository allocation cutoff persistence', () {
    test('roundtrips null allocation cutoff through repository rows', () async {
      final db = await AppDatabase.database;
      final repository = SqfliteTimingRepository();
      final projectId = await _seedProject(db);

      final id = await repository.insert(_record(projectId: projectId));

      final row = (await db.query(
        'timing_records',
        where: 'id = ?',
        whereArgs: [id],
      )).single;
      expect(row.containsKey('allocation_cutoff_date'), isTrue);
      expect(row['allocation_cutoff_date'], isNull);

      final records = await repository.listAll();
      expect(records.single.allocationCutoffDate, isNull);
    });

    test(
      'roundtrips non-null allocation cutoff through repository rows',
      () async {
        final db = await AppDatabase.database;
        final repository = SqfliteTimingRepository();
        final projectId = await _seedProject(db);

        final id = await repository.insert(
          _record(projectId: projectId, allocationCutoffDate: 20260610),
        );

        final row = (await db.query(
          'timing_records',
          where: 'id = ?',
          whereArgs: [id],
        )).single;
        expect(row['allocation_cutoff_date'], 20260610);

        final records = await repository.listAll();
        expect(records.single.allocationCutoffDate, 20260610);
      },
    );

    test('updates allocation cutoff from non-null to null', () async {
      final db = await AppDatabase.database;
      final repository = SqfliteTimingRepository();
      final projectId = await _seedProject(db);

      final id = await repository.insert(
        _record(projectId: projectId, allocationCutoffDate: 20260610),
      );
      final existing = (await repository.listAll()).single;

      await repository.update(existing.copyWith(allocationCutoffDate: null));

      final row = (await db.query(
        'timing_records',
        where: 'id = ?',
        whereArgs: [id],
      )).single;
      expect(row['allocation_cutoff_date'], isNull);
      expect((await repository.listAll()).single.allocationCutoffDate, isNull);
    });
  });
}

TimingRecord _record({required String projectId, int? allocationCutoffDate}) {
  return TimingRecord(
    projectId: projectId,
    deviceId: 1,
    startDate: 20260601,
    allocationCutoffDate: allocationCutoffDate,
    contact: '甲方',
    site: '一号工地',
    type: TimingType.hours,
    startMeter: 0,
    endMeter: 8,
    hours: 8,
    income: 800,
  );
}

Future<String> _seedProject(Database db) async {
  const contact = '甲方';
  const site = '一号工地';
  final projectId = ProjectId.legacyFromParts(contact: contact, site: site);
  await db.insert(
    'projects',
    Project(
      id: projectId,
      contact: contact,
      site: site,
      createdAt: '2026-06-01T00:00:00.000Z',
      updatedAt: '2026-06-01T00:00:00.000Z',
    ).toMap(),
  );
  return projectId;
}
