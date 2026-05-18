import 'package:asset_ledger/data/db/db_migrations.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/features/timing/calculator/model/timing_calculation_history.dart';
import 'package:asset_ledger/features/timing/calculator/repository/timing_calculation_history_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  group('SqfliteTimingCalculationHistoryRepository', () {
    test(
      'insertMany and findByTimingRecordId isolate records and sort desc',
      () async {
        final db = await _openCurrentInMemoryDb();
        final repository = SqfliteTimingCalculationHistoryRepository();

        await _seedTimingRecord(db, id: 1);
        await _seedTimingRecord(db, id: 2);

        await repository.insertMany(1, [
          _history(
            id: 'h1',
            timingRecordId: 999,
            createdAt: DateTime.utc(2026, 5, 14, 8),
            expression: '8+8',
            result: 16.0,
            ticketCount: 2,
          ),
          _history(
            id: 'h2',
            timingRecordId: 999,
            createdAt: DateTime.utc(2026, 5, 14, 9),
            expression: '8+8.2',
            result: 16.2,
            ticketCount: 2,
          ),
        ]);
        await repository.insertMany(2, [
          _history(
            id: 'h3',
            timingRecordId: 2,
            createdAt: DateTime.utc(2026, 5, 14, 10),
            expression: '5+3',
            result: 8.0,
            ticketCount: 2,
          ),
        ]);

        final firstRecordHistories = await repository.findByTimingRecordId(1);
        final secondRecordHistories = await repository.findByTimingRecordId(2);

        expect(firstRecordHistories.map((item) => item.id), ['h2', 'h1']);
        expect(firstRecordHistories.map((item) => item.timingRecordId), [1, 1]);
        expect(secondRecordHistories.map((item) => item.id), ['h3']);
      },
    );

    test('insertMany with an empty list returns without error', () async {
      await _openCurrentInMemoryDb();
      final repository = SqfliteTimingCalculationHistoryRepository();

      await repository.insertMany(1, const []);

      expect(await repository.findByTimingRecordId(1), isEmpty);
    });

    test(
      'deleteByTimingRecordId only deletes histories for one timing record',
      () async {
        final db = await _openCurrentInMemoryDb();
        final repository = SqfliteTimingCalculationHistoryRepository();

        await _seedTimingRecord(db, id: 1);
        await _seedTimingRecord(db, id: 2);
        await repository.insertMany(1, [_history(id: 'h1', timingRecordId: 1)]);
        await repository.insertMany(2, [_history(id: 'h2', timingRecordId: 2)]);

        await repository.deleteByTimingRecordId(1);

        expect(await repository.findByTimingRecordId(1), isEmpty);
        expect(await repository.findByTimingRecordId(2), hasLength(1));
      },
    );

    test(
      'deleting a timing record cascades to its calculation histories',
      () async {
        final db = await _openCurrentInMemoryDb();
        final repository = SqfliteTimingCalculationHistoryRepository();

        await _seedTimingRecord(db, id: 1);
        await repository.insertMany(1, [_history(id: 'h1', timingRecordId: 1)]);

        await db.delete('timing_records', where: 'id = ?', whereArgs: [1]);

        expect(await repository.findByTimingRecordId(1), isEmpty);
      },
    );

    test(
      'v10 migration creates table and index without affecting v9 rows',
      () async {
        final db = await openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (db, _) async {
            await _createMinimalV9Schema(db);
            await _seedTimingRecord(db, id: 1);
          },
        );
        addTearDown(db.close);

        await DbMigrations.apply(db, 9, 10);

        expect(await _tableExists(db, 'timing_calculation_history'), isTrue);
        expect(await _indexExists(db, 'idx_timing_calc_record_id'), isTrue);

        final timingRow = (await db.query('timing_records')).single;
        expect(timingRow['id'], 1);
        expect(timingRow['contact'], '甲方');
      },
    );

    test(
      'saving a new timing record with histories persists both in one call',
      () async {
        final db = await _openCurrentInMemoryDb();
        final timingRepository = SqfliteTimingRepository();
        final historyRepository = SqfliteTimingCalculationHistoryRepository();
        await _seedProject(db, contact: '新建', site: '一号工地');

        final savedRecord = await timingRepository.saveWithCalculationHistories(
          _record(contact: '新建'),
          calculationHistories: [_history(id: 'new-h1', timingRecordId: 0)],
        );

        expect(savedRecord.id, isNotNull);
        final rows = await db.query(
          'timing_records',
          where: 'id = ?',
          whereArgs: [savedRecord.id],
        );
        expect(rows.single['contact'], '新建');

        final histories = await historyRepository.findByTimingRecordId(
          savedRecord.id!,
        );
        expect(histories, hasLength(1));
        expect(histories.single.id, 'new-h1');
        expect(histories.single.timingRecordId, savedRecord.id);
      },
    );

    test(
      'updating a timing record appends new histories without deleting old ones',
      () async {
        final db = await _openCurrentInMemoryDb();
        final timingRepository = SqfliteTimingRepository();
        final historyRepository = SqfliteTimingCalculationHistoryRepository();
        await _seedProject(db, contact: '更新前', site: '一号工地');

        final savedRecord = await timingRepository.saveWithCalculationHistories(
          _record(contact: '更新前'),
          calculationHistories: [
            _history(
              id: 'old-h1',
              timingRecordId: 0,
              createdAt: DateTime.utc(2026, 5, 14, 8),
            ),
          ],
        );

        await timingRepository.saveWithCalculationHistories(
          savedRecord.copyWith(contact: '更新后', hours: 3, endMeter: 3),
          calculationHistories: [
            _history(
              id: 'new-h1',
              timingRecordId: 999,
              createdAt: DateTime.utc(2026, 5, 14, 9),
              expression: '2+1',
              result: 3.0,
              ticketCount: 2,
            ),
          ],
        );

        final histories = await historyRepository.findByTimingRecordId(
          savedRecord.id!,
        );
        expect(histories.map((item) => item.id).toSet(), {'old-h1', 'new-h1'});
        expect(histories.map((item) => item.timingRecordId).toSet(), {
          savedRecord.id,
        });
      },
    );

    test(
      'saving with empty histories only persists the timing record',
      () async {
        final db = await _openCurrentInMemoryDb();
        final timingRepository = SqfliteTimingRepository();
        final historyRepository = SqfliteTimingCalculationHistoryRepository();
        await _seedProject(db, contact: '无历史', site: '一号工地');

        final savedRecord = await timingRepository.saveWithCalculationHistories(
          _record(contact: '无历史'),
        );

        final rows = await db.query(
          'timing_records',
          where: 'id = ?',
          whereArgs: [savedRecord.id],
        );
        expect(rows, hasLength(1));
        expect(
          await historyRepository.findByTimingRecordId(savedRecord.id!),
          isEmpty,
        );
      },
    );

    test('rolls back the timing record when history insertion fails', () async {
      final db = await _openCurrentInMemoryDb();
      final timingRepository = SqfliteTimingRepository();
      await _seedProject(db, contact: '应回滚', site: '一号工地');

      await expectLater(
        timingRepository.saveWithCalculationHistories(
          _record(contact: '应回滚'),
          calculationHistories: [
            _history(id: 'duplicate-id', timingRecordId: 0),
            _history(
              id: 'duplicate-id',
              timingRecordId: 0,
              expression: '5+5',
              result: 10.0,
            ),
          ],
        ),
        throwsA(anything),
      );

      final recordRows = await db.query(
        'timing_records',
        where: 'contact = ?',
        whereArgs: ['应回滚'],
      );
      final historyRows = await db.query(
        'timing_calculation_history',
        where: 'id = ?',
        whereArgs: ['duplicate-id'],
      );
      expect(recordRows, isEmpty);
      expect(historyRows, isEmpty);
    });
  });
}

Future<Database> _openCurrentInMemoryDb() async {
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

TimingCalculationHistory _history({
  required String id,
  required int timingRecordId,
  DateTime? createdAt,
  String expression = '8+8',
  double result = 16.0,
  int ticketCount = 2,
}) {
  return TimingCalculationHistory(
    id: id,
    timingRecordId: timingRecordId,
    createdAt: createdAt ?? DateTime.utc(2026, 5, 14, 8),
    expression: expression,
    result: result,
    ticketCount: ticketCount,
  );
}

TimingRecord _record({String contact = '甲方'}) {
  return TimingRecord(
    projectId: ProjectId.legacyFromParts(contact: contact, site: '一号工地'),
    deviceId: 1,
    startDate: 20260514,
    contact: contact,
    site: '一号工地',
    type: TimingType.hours,
    startMeter: 0.0,
    endMeter: 8.0,
    hours: 8.0,
    income: 800.0,
  );
}

Future<void> _seedTimingRecord(Database db, {required int id}) async {
  final row = <String, Object?>{
    'id': id,
    'device_id': 1,
    'start_date': 20260514,
    'contact': '甲方',
    'site': '一号工地',
    'type': 'hours',
    'start_meter': 0.0,
    'end_meter': 8.0,
    'hours': 8.0,
    'income': 800.0,
    'exclude_from_fuel_eff': 0,
    'is_breaking': 0,
  };
  final columns = await db.rawQuery('PRAGMA table_info(timing_records);');
  if (columns.any((column) => column['name'] == 'project_id')) {
    row['project_id'] = ProjectId.legacyFromParts(contact: '甲方', site: '一号工地');
    await _seedProject(db, contact: '甲方', site: '一号工地');
  }
  await db.insert('timing_records', row);
}

Future<void> _seedProject(
  Database db, {
  required String contact,
  required String site,
}) async {
  if (!await _tableExists(db, 'projects')) return;
  final now = DateTime.utc(2026, 5, 14).toIso8601String();
  await db.insert('projects', {
    'id': ProjectId.legacyFromParts(contact: contact, site: site),
    'contact': contact,
    'site': site,
    'status': 'active',
    'settled_at': null,
    'settled_snapshot': null,
    'created_at': now,
    'updated_at': now,
    'legacy_project_key': '$contact||$site',
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
}

Future<void> _createMinimalV9Schema(Database db) async {
  await db.execute('''
    CREATE TABLE timing_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id INTEGER NOT NULL,
      start_date INTEGER NOT NULL,
      contact TEXT NOT NULL,
      site TEXT NOT NULL,
      type TEXT NOT NULL,
      start_meter REAL NOT NULL,
      end_meter REAL NOT NULL,
      hours REAL NOT NULL,
      income REAL NOT NULL,
      exclude_from_fuel_eff INTEGER NOT NULL DEFAULT 0,
      is_breaking INTEGER NOT NULL DEFAULT 0
    );
  ''');
}

Future<bool> _tableExists(Database db, String table) async {
  final rows = await db.query(
    'sqlite_master',
    columns: ['name'],
    where: 'type = ? AND name = ?',
    whereArgs: ['table', table],
    limit: 1,
  );
  return rows.isNotEmpty;
}

Future<bool> _indexExists(Database db, String index) async {
  final rows = await db.query(
    'sqlite_master',
    columns: ['name'],
    where: 'type = ? AND name = ?',
    whereArgs: ['index', index],
    limit: 1,
  );
  return rows.isNotEmpty;
}
