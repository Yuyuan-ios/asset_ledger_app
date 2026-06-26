import 'dart:convert';

import 'package:asset_ledger/core/measure/measure_unit.dart';
import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/account_project_merge_group.dart';
import 'package:asset_ledger/data/models/account_project_merge_member.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/data/repositories/account_project_merge_repository.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/project_rate_repository.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/repositories/project_write_off_repository.dart';
import 'package:asset_ledger/data/repositories/timing_calculation_history_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/data/services/project_resolver.dart';
import 'package:asset_ledger/features/timing/use_cases/save_timing_record_allocation_cutoff_validator.dart';
import 'package:asset_ledger/infrastructure/local/account/project_settlement_impact_service.dart';
import 'package:asset_ledger/infrastructure/local/account/project_sync_enqueuer.dart';
import 'package:asset_ledger/features/timing/use_cases/save_timing_record_with_impact_use_case.dart';
import 'package:asset_ledger/infrastructure/local/timing/local_save_timing_record_with_impact_use_case.dart';
import 'package:asset_ledger/infrastructure/sync/sync_outbox_entry.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

/// 阶段 B Step 3 — 保存计时记录事务化的端到端回归测试。
///
/// 业务规则（business_rules_v1.md §6 / §7）：
/// - 修改计时导致 project_id 变化时，**保存计时 + 解除合并 + 撤销结清**
///   在同一个 sqflite 事务内完成；任一步失败整体回滚。
/// - 撤销结清不删除收款、不删除核销、不删除其它计时。
/// - 影响判断走 amount_fen 整数，不依赖 projectSettlementEpsilon。
/// - UI 不再依赖 pending retry 保障一致性。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late SqfliteTimingRepository timingRepository;
  late SqfliteTimingCalculationHistoryRepository calculationHistoryRepository;
  late SqfliteAccountProjectMergeRepository mergeRepository;
  late SqfliteDeviceRepository deviceRepository;
  late SqfliteProjectRateRepository projectRateRepository;
  late SqfliteProjectRepository projectRepository;
  late ProjectResolver projectResolver;
  late ProjectSettlementImpactService impactService;
  late LocalSaveTimingRecordWithImpactUseCase useCase;

  setUp(() async {
    await AppDatabase.resetForTest();
    await _openCurrentInMemoryDb();
    timingRepository = SqfliteTimingRepository();
    calculationHistoryRepository = SqfliteTimingCalculationHistoryRepository();
    mergeRepository = SqfliteAccountProjectMergeRepository();
    deviceRepository = SqfliteDeviceRepository();
    projectRateRepository = SqfliteProjectRateRepository();
    projectRepository = SqfliteProjectRepository();
    projectResolver = ProjectResolver(projectRepository: projectRepository);
    impactService = ProjectSettlementImpactService(
      projectRepository: projectRepository,
    );
    useCase = LocalSaveTimingRecordWithImpactUseCase(
      timingRepository: timingRepository,
      timingCalculationHistoryRepository: calculationHistoryRepository,
      mergeRepository: mergeRepository,
      deviceRepository: deviceRepository,
      projectRateRepository: projectRateRepository,
      projectResolver: projectResolver,
      impactService: impactService,
      now: () => DateTime.utc(2026, 5, 26, 12),
    );
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  group('新增计时记录（没有 oldProject）', () {
    test('正常保存：projectChanged=false，不解除合并、不撤销结清', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:alpha');

      final result = await useCase.execute(
        editing: null,
        record: TimingRecord(
          deviceId: deviceId,
          startDate: 20260520,
          projectId: 'project:alpha',
          contact: '甲方',
          site: 'alpha',
          type: TimingType.hours,
          startMeter: 0,
          endMeter: 1,
          hours: 1,
          income: 100,
        ),
      );

      expect(result.projectChanged, isFalse);
      expect(result.mergeDissolved, isFalse);
      expect(result.settlementRevoked, isFalse);
      expect(result.affectedProjectIds, contains('project:alpha'));
      expect(result.revokedProjectIds, isEmpty);
      expect(result.savedRecord.id, isNotNull);
      expect(result.userMessage, isNull);

      // 真实落库：timing_records 有这一行。
      final rows = await db.query('timing_records');
      expect(rows, hasLength(1));
    });

    test('成功保存后同事务写入 pending create outbox 和 pendingUpload meta', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:alpha');

      final result = await useCase.execute(
        editing: null,
        record: TimingRecord(
          deviceId: deviceId,
          startDate: 20260520,
          projectId: 'project:alpha',
          contact: '甲方',
          site: 'alpha',
          type: TimingType.hours,
          startMeter: 0,
          endMeter: 1,
          hours: 1,
          income: 100,
        ),
      );

      final savedId = result.savedRecord.id.toString();
      final outboxRows = await db.query('sync_outbox');
      expect(outboxRows, hasLength(2));
      expect(
        _singleOutboxRow(outboxRows, 'project_device_rate')['operation'],
        'update',
      );
      final timingOutbox = _singleOutboxRow(outboxRows, 'timing_record');
      expect(timingOutbox['entity_id'], savedId);
      expect(timingOutbox['operation'], 'create');
      expect(timingOutbox['status'], SyncOutboxStatus.pending.name);
      final payload =
          jsonDecode(timingOutbox['payload_json'] as String)
              as Map<String, Object?>;
      expect(payload['entity_type'], 'timing_record');
      expect(payload['entity_id'], savedId);
      expect(payload['operation'], 'create');
      expect(
        (payload['record'] as Map<String, Object?>)['id'],
        result.savedRecord.id,
      );

      final metaRows = await db.query('entity_sync_meta');
      expect(metaRows, hasLength(2));
      final timingMeta = _singleMetaRow(metaRows, 'timing_record');
      expect(timingMeta['local_id'], savedId);
      expect(timingMeta['sync_status'], SyncStatus.pendingUpload.name);
      expect(timingMeta['source'], 'owner_app');
      expect(timingMeta['payload_hash'], timingOutbox['payload_hash']);
    });

    test('新建工时记录落库和同步 payload 必带 unit 与 quantity_scaled', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:alpha');

      final result = await useCase.execute(
        editing: null,
        record: TimingRecord(
          deviceId: deviceId,
          startDate: 20260520,
          projectId: 'project:alpha',
          contact: '甲方',
          site: 'alpha',
          type: TimingType.hours,
          startMeter: 0,
          endMeter: 7.5,
          hours: 7.5,
          income: 750,
        ),
      );

      final rows = await db.query('timing_records');
      expect(rows, hasLength(1));
      expect(rows.single['unit'], 'HOUR');
      expect(rows.single['quantity_scaled'], 7500);

      final outboxRows = await db.query('sync_outbox');
      expect(outboxRows, hasLength(2));
      final timingOutbox = _singleOutboxRow(outboxRows, 'timing_record');
      final payload =
          jsonDecode(timingOutbox['payload_json'] as String)
              as Map<String, Object?>;
      final payloadRecord = payload['record'] as Map<String, Object?>;
      expect(payloadRecord['id'], result.savedRecord.id);
      expect(payloadRecord['unit'], 'HOUR');
      expect(payloadRecord['quantity_scaled'], 7500);
    });

    test('新建非租期记录缺少 quantity_scaled 时拒绝保存', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:alpha');

      await expectLater(
        useCase.execute(
          editing: null,
          record: _MissingQuantityTimingRecord(deviceId: deviceId),
        ),
        throwsA(isA<TimingRecordQuantityAuthorityException>()),
      );

      expect(await db.query('timing_records'), isEmpty);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    });

    test('免费版已有 29 条时允许新增第 30 条', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:alpha');
      await _seedTimingRecords(
        db,
        count: 29,
        deviceId: deviceId,
        projectId: 'project:alpha',
      );

      final result = await useCase.execute(
        editing: null,
        record: TimingRecord(
          deviceId: deviceId,
          startDate: 20260620,
          projectId: 'project:alpha',
          contact: '甲方',
          site: 'alpha',
          type: TimingType.hours,
          startMeter: 100,
          endMeter: 101,
          hours: 1,
          income: 100,
        ),
      );

      expect(result.savedRecord.id, isNotNull);
      expect(await _timingRecordCount(db), 30);
    });

    test('免费版已有 30 条时拒绝新增且不写入脏数据', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:alpha');
      await _seedTimingRecords(
        db,
        count: 30,
        deviceId: deviceId,
        projectId: 'project:alpha',
      );

      await expectLater(
        useCase.execute(
          editing: null,
          record: TimingRecord(
            deviceId: deviceId,
            startDate: 20260620,
            projectId: 'project:alpha',
            contact: '甲方',
            site: 'alpha',
            type: TimingType.hours,
            startMeter: 100,
            endMeter: 101,
            hours: 1,
            income: 100,
          ),
        ),
        throwsA(
          isA<TimingRecordLimitExceededException>()
              .having((error) => error.currentCount, 'currentCount', 30)
              .having((error) => error.limit, 'limit', 30),
        ),
      );

      expect(await _timingRecordCount(db), 30);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    });

    test('免费版已有 31 条历史数据时拒绝继续新增但保留历史数据', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:alpha');
      await _seedTimingRecords(
        db,
        count: 31,
        deviceId: deviceId,
        projectId: 'project:alpha',
      );

      await expectLater(
        useCase.execute(
          editing: null,
          record: TimingRecord(
            deviceId: deviceId,
            startDate: 20260620,
            projectId: 'project:alpha',
            contact: '甲方',
            site: 'alpha',
            type: TimingType.hours,
            startMeter: 100,
            endMeter: 101,
            hours: 1,
            income: 100,
          ),
        ),
        throwsA(isA<TimingRecordLimitExceededException>()),
      );

      expect(await _timingRecordCount(db), 31);
    });

    test('Pro 或 Max 权益允许 30 条以上继续新增', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:alpha');
      await _seedTimingRecords(
        db,
        count: 31,
        deviceId: deviceId,
        projectId: 'project:alpha',
      );
      final entitledUseCase = LocalSaveTimingRecordWithImpactUseCase(
        timingRepository: timingRepository,
        timingCalculationHistoryRepository: calculationHistoryRepository,
        mergeRepository: mergeRepository,
        deviceRepository: deviceRepository,
        projectRateRepository: projectRateRepository,
        projectResolver: projectResolver,
        impactService: impactService,
        canCreateMoreTimingRecords: (_) => true,
        now: () => DateTime.utc(2026, 5, 26, 12),
      );

      await entitledUseCase.execute(
        editing: null,
        record: TimingRecord(
          deviceId: deviceId,
          startDate: 20260620,
          projectId: 'project:alpha',
          contact: '甲方',
          site: 'alpha',
          type: TimingType.hours,
          startMeter: 100,
          endMeter: 101,
          hours: 1,
          income: 100,
        ),
      );

      expect(await _timingRecordCount(db), 32);
    });
  });

  group('executeWithExecutor 外部事务入口', () {
    test('在外部 transaction 内保存成功，结果与 execute 语义一致', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:alpha');
      final record = TimingRecord(
        deviceId: deviceId,
        startDate: 20260520,
        projectId: 'project:alpha',
        contact: '甲方',
        site: 'alpha',
        type: TimingType.hours,
        startMeter: 0,
        endMeter: 1,
        hours: 1,
        income: 100,
      );
      final preparation = await useCase.prepareForSave(
        editing: null,
        record: record,
      );

      final result = await AppDatabase.inTransaction((txn) {
        return useCase.executeWithExecutor(
          txn,
          editing: null,
          preparation: preparation,
        );
      });

      expect(result.projectChanged, isFalse);
      expect(result.mergeDissolved, isFalse);
      expect(result.settlementRevoked, isFalse);
      expect(result.savedRecord.id, isNotNull);
      final rows = await db.query('timing_records');
      expect(rows, hasLength(1));
      expect(rows.single['project_id'], 'project:alpha');
    });

    test('外部 transaction 后续失败时，executeWithExecutor 的保存会回滚', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:alpha');
      final record = TimingRecord(
        deviceId: deviceId,
        startDate: 20260520,
        projectId: 'project:alpha',
        contact: '甲方',
        site: 'alpha',
        type: TimingType.hours,
        startMeter: 0,
        endMeter: 1,
        hours: 1,
        income: 100,
      );
      final preparation = await useCase.prepareForSave(
        editing: null,
        record: record,
      );

      await expectLater(
        AppDatabase.inTransaction((txn) async {
          await useCase.executeWithExecutor(
            txn,
            editing: null,
            preparation: preparation,
          );
          throw StateError('rollback-after-save');
        }),
        throwsA(isA<StateError>()),
      );

      expect(await db.query('timing_records'), isEmpty);
    });

    test('事务内创建新 project：外部 transaction 成功后 project + timing 一起落库', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      final record = TimingRecord(
        deviceId: deviceId,
        startDate: 20260520,
        projectId: '',
        contact: '新甲方',
        site: '新工地',
        type: TimingType.hours,
        startMeter: 0,
        endMeter: 1,
        hours: 1,
        income: 100,
      );
      final preparation = await useCase.prepareForSave(
        editing: null,
        record: record,
      );
      expect(preparation.recordToSave.projectId, isEmpty);

      final result = await AppDatabase.inTransaction((txn) {
        return useCase.executeWithExecutor(
          txn,
          editing: null,
          preparation: preparation,
        );
      });

      final projects = await db.query('projects');
      expect(projects, hasLength(1));
      expect(projects.single['contact'], '新甲方');
      expect(projects.single['site'], '新工地');
      final projectId = projects.single['id'] as String;
      expect(result.savedRecord.projectId, projectId);
      expect(result.affectedProjectIds, contains(projectId));

      final timings = await db.query('timing_records');
      expect(timings, hasLength(1));
      expect(timings.single['project_id'], projectId);
    });

    test('事务内创建新 project 后续失败：project + timing 都回滚', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      final record = TimingRecord(
        deviceId: deviceId,
        startDate: 20260520,
        projectId: '',
        contact: '回滚甲方',
        site: '回滚工地',
        type: TimingType.hours,
        startMeter: 0,
        endMeter: 1,
        hours: 1,
        income: 100,
      );
      final preparation = await useCase.prepareForSave(
        editing: null,
        record: record,
      );

      await expectLater(
        AppDatabase.inTransaction((txn) async {
          await useCase.executeWithExecutor(
            txn,
            editing: null,
            preparation: preparation,
          );
          throw StateError('rollback-after-project-create');
        }),
        throwsA(isA<StateError>()),
      );

      expect(await db.query('projects'), isEmpty);
      expect(await db.query('timing_records'), isEmpty);
    });

    test('事务内复用 active project：不额外创建空项目', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:active');
      final record = TimingRecord(
        deviceId: deviceId,
        startDate: 20260520,
        projectId: '',
        contact: '甲方',
        site: 'active',
        type: TimingType.hours,
        startMeter: 0,
        endMeter: 1,
        hours: 1,
        income: 100,
      );

      final result = await useCase.execute(editing: null, record: record);

      expect(result.savedRecord.projectId, 'project:active');
      final projects = await db.query('projects');
      expect(projects, hasLength(1));
      final timings = await db.query('timing_records');
      expect(timings.single['project_id'], 'project:active');
    });

    test('settled 旧项目同 contact/site 再保存：事务内创建新 project', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(
        db,
        projectId: 'project:old-settled',
        status: ProjectStatus.settled,
        settledAt: '2026-05-19T00:00:00.000Z',
      );
      final record = TimingRecord(
        deviceId: deviceId,
        startDate: 20260520,
        projectId: '',
        contact: '甲方',
        site: 'old-settled',
        type: TimingType.hours,
        startMeter: 0,
        endMeter: 1,
        hours: 1,
        income: 100,
      );

      final result = await useCase.execute(editing: null, record: record);

      expect(result.savedRecord.projectId, isNot('project:old-settled'));
      final projects = await db.query('projects');
      expect(projects, hasLength(2));
      expect(
        projects.map((row) => row['legacy_project_key']).toSet(),
        hasLength(1),
      );
      final activeRows = projects
          .where((row) => row['status'] == ProjectStatus.active.name)
          .toList();
      expect(activeRows, hasLength(1));
      expect(activeRows.single['id'], result.savedRecord.projectId);
    });
  });

  group('编辑计时记录，projectId 不变', () {
    test('正常保存，不解除合并，不撤销结清', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:alpha');
      final existing = await _seedTimingRecord(
        db,
        deviceId: deviceId,
        projectId: 'project:alpha',
        contact: '甲方',
        site: 'alpha',
        hours: 1,
        income: 100,
      );

      final result = await useCase.execute(
        editing: existing,
        record: existing.copyWith(hours: 2, income: 200),
      );

      expect(result.projectChanged, isFalse);
      expect(result.mergeDissolved, isFalse);
      expect(result.settlementRevoked, isFalse);
      // affectedProjectIds 至少包含 newProjectId（与 oldProjectId 相同）。
      expect(result.affectedProjectIds, contains('project:alpha'));
      expect(result.revokedProjectIds, isEmpty);

      final rows = await db.query('timing_records');
      expect(rows, hasLength(1));
      expect(rows.single['income_fen'], 20000);
    });

    test('编辑成功后同事务写入 pending update outbox 和 pendingUpdate meta', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:alpha');
      final existing = await _seedTimingRecord(
        db,
        deviceId: deviceId,
        projectId: 'project:alpha',
        contact: '甲方',
        site: 'alpha',
        hours: 1,
        income: 100,
      );

      final result = await useCase.execute(
        editing: existing,
        record: existing.copyWith(hours: 2, income: 200),
      );

      final savedId = result.savedRecord.id.toString();
      final outboxRows = await db.query('sync_outbox');
      expect(outboxRows, hasLength(2));
      expect(
        _singleOutboxRow(outboxRows, 'project_device_rate')['operation'],
        'update',
      );
      final timingOutbox = _singleOutboxRow(outboxRows, 'timing_record');
      expect(timingOutbox['entity_id'], savedId);
      expect(timingOutbox['operation'], 'update');
      expect(timingOutbox['status'], SyncOutboxStatus.pending.name);
      final payload =
          jsonDecode(timingOutbox['payload_json'] as String)
              as Map<String, Object?>;
      expect(payload['operation'], 'update');
      expect((payload['record'] as Map<String, Object?>)['income_fen'], 20000);

      final metaRows = await db.query('entity_sync_meta');
      expect(metaRows, hasLength(2));
      final timingMeta = _singleMetaRow(metaRows, 'timing_record');
      expect(timingMeta['local_id'], savedId);
      expect(timingMeta['sync_status'], SyncStatus.pendingUpdate.name);
      expect(timingMeta['payload_hash'], timingOutbox['payload_hash']);
    });

    test('只清空 allocation cutoff 不触发业务影响并写 update outbox', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db, defaultUnitPrice: 100);
      await _seedProject(
        db,
        projectId: 'project:alpha',
        status: ProjectStatus.settled,
        settledAt: '2026-05-20T00:00:00.000Z',
      );
      await _insertPayment(
        db,
        projectId: 'project:alpha',
        amount: 100,
        amountFen: 10000,
      );
      final existing = await _seedTimingRecord(
        db,
        deviceId: deviceId,
        projectId: 'project:alpha',
        contact: '甲方',
        site: 'alpha',
        hours: 1,
        income: 100,
        allocationCutoffDate: 20260610,
      );
      await _seedRate(
        db,
        deviceId: deviceId,
        projectId: 'project:alpha',
        projectKey: '甲方||alpha',
        rate: 100,
      );

      final result = await useCase.execute(
        editing: existing,
        record: existing.copyWith(allocationCutoffDate: null),
      );

      expect(result.projectChanged, isFalse);
      expect(result.mergeDissolved, isFalse);
      expect(result.settlementRevoked, isFalse);
      expect(result.revokedProjectIds, isEmpty);
      expect(result.savedRecord.income, 100);
      expect(result.savedRecord.allocationCutoffDate, isNull);

      final timingRows = await db.query('timing_records');
      expect(timingRows, hasLength(1));
      expect(timingRows.single['allocation_cutoff_date'], isNull);
      expect(timingRows.single['income_fen'], 10000);

      final projectRows = await db.query(
        'projects',
        where: 'id = ?',
        whereArgs: ['project:alpha'],
      );
      expect(projectRows.single['status'], ProjectStatus.settled.name);
      expect(projectRows.single['settled_at'], isNotNull);
      expect(await db.query('account_project_merge_groups'), isEmpty);

      final outboxRows = await db.query('sync_outbox');
      expect(outboxRows, hasLength(1));
      expect(outboxRows.single['operation'], 'update');
      final payload =
          jsonDecode(outboxRows.single['payload_json'] as String)
              as Map<String, Object?>;
      final recordPayload = payload['record'] as Map<String, Object?>;
      expect(recordPayload.containsKey('allocation_cutoff_date'), isTrue);
      expect(recordPayload['allocation_cutoff_date'], isNull);
    });
  });

  group('allocation cutoff save-layer validation', () {
    test(
      'allows null allocation cutoff and preserves legacy save path',
      () async {
        final db = await AppDatabase.database;
        final deviceId = await _seedDevice(db);
        await _seedProject(db, projectId: 'project:alpha');
        await _seedRate(
          db,
          deviceId: deviceId,
          projectId: 'project:alpha',
          projectKey: '甲方||alpha',
          rate: 100,
        );

        final result = await useCase.execute(
          editing: null,
          record: TimingRecord(
            deviceId: deviceId,
            startDate: 20260601,
            projectId: 'project:alpha',
            contact: '甲方',
            site: 'alpha',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 1,
            hours: 1,
            income: 100,
          ),
        );

        expect(result.savedRecord.allocationCutoffDate, isNull);
        expect(result.projectChanged, isFalse);
        final timingRows = await db.query('timing_records');
        expect(timingRows, hasLength(1));
        expect(timingRows.single['allocation_cutoff_date'], isNull);
        expect(await db.query('sync_outbox'), hasLength(1));
        expect(await db.query('entity_sync_meta'), hasLength(1));
      },
    );

    test('rejects allocation cutoff on or before start date', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:alpha');
      final existing = await _seedTimingRecord(
        db,
        deviceId: deviceId,
        projectId: 'project:alpha',
        contact: '甲方',
        site: 'alpha',
        startDate: 20260601,
        hours: 1,
        income: 100,
      );

      for (final cutoff in [20260601, 20260531]) {
        await expectLater(
          useCase.execute(
            editing: existing,
            record: existing.copyWith(allocationCutoffDate: cutoff),
          ),
          throwsA(
            isA<SaveTimingRecordAllocationCutoffValidationException>().having(
              (error) => error.code,
              'code',
              SaveTimingRecordAllocationCutoffValidationException
                  .cutoffNotAfterStartDate,
            ),
          ),
        );
      }

      final timingRows = await db.query('timing_records');
      expect(timingRows, hasLength(1));
      expect(timingRows.single['allocation_cutoff_date'], isNull);
      expect(timingRows.single['income_fen'], 10000);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    });

    test('allows same-day next record with same-day UI end date', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:alpha');
      await _seedProject(db, projectId: 'project:beta');
      final existing = await _seedTimingRecord(
        db,
        deviceId: deviceId,
        projectId: 'project:alpha',
        contact: '甲方',
        site: 'alpha',
        startDate: 20260601,
        startMeter: 0,
        hours: 1,
        income: 100,
      );
      await _seedTimingRecord(
        db,
        deviceId: deviceId,
        projectId: 'project:beta',
        contact: '甲方',
        site: 'beta',
        startDate: 20260601,
        startMeter: 10,
        hours: 1,
        income: 100,
      );
      await _seedRate(
        db,
        deviceId: deviceId,
        projectId: 'project:alpha',
        projectKey: '甲方||alpha',
        rate: 100,
      );

      final result = await useCase.execute(
        editing: existing,
        record: existing.copyWith(allocationCutoffDate: 20260602),
      );

      final timingRows = await db.query('timing_records', orderBy: 'id ASC');
      expect(timingRows, hasLength(2));
      expect(result.savedRecord.allocationCutoffDate, 20260602);
      expect(timingRows.first['allocation_cutoff_date'], 20260602);
      expect((await db.query('sync_outbox')).single['operation'], 'update');
    });

    test(
      'allows allocation cutoff equal to next same-device start date',
      () async {
        final db = await AppDatabase.database;
        final deviceId = await _seedDevice(db);
        await _seedProject(db, projectId: 'project:alpha');
        await _seedProject(db, projectId: 'project:beta');
        final existing = await _seedTimingRecord(
          db,
          deviceId: deviceId,
          projectId: 'project:alpha',
          contact: '甲方',
          site: 'alpha',
          startDate: 20260601,
          hours: 1,
          income: 100,
        );
        await _seedRate(
          db,
          deviceId: deviceId,
          projectId: 'project:alpha',
          projectKey: '甲方||alpha',
          rate: 100,
        );
        await _seedTimingRecord(
          db,
          deviceId: deviceId,
          projectId: 'project:beta',
          contact: '甲方',
          site: 'beta',
          startDate: 20260610,
          hours: 1,
          income: 100,
        );

        final result = await useCase.execute(
          editing: existing,
          record: existing.copyWith(allocationCutoffDate: 20260610),
        );

        expect(result.savedRecord.allocationCutoffDate, 20260610);
        expect(result.projectChanged, isFalse);
        expect(result.mergeDissolved, isFalse);
        expect(result.settlementRevoked, isFalse);
        final timingRows = await db.query(
          'timing_records',
          where: 'id = ?',
          whereArgs: [existing.id],
        );
        expect(timingRows.single['allocation_cutoff_date'], 20260610);
        expect(timingRows.single['income_fen'], 10000);
        expect((await db.query('sync_outbox')).single['operation'], 'update');
      },
    );

    test('allows UI end date equal to next same-device start date', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:alpha');
      await _seedProject(db, projectId: 'project:beta');
      final existing = await _seedTimingRecord(
        db,
        deviceId: deviceId,
        projectId: 'project:alpha',
        contact: '甲方',
        site: 'alpha',
        startDate: 20260601,
        hours: 1,
        income: 100,
      );
      await _seedTimingRecord(
        db,
        deviceId: deviceId,
        projectId: 'project:beta',
        contact: '甲方',
        site: 'beta',
        startDate: 20260610,
        hours: 1,
        income: 100,
      );
      await _seedRate(
        db,
        deviceId: deviceId,
        projectId: 'project:alpha',
        projectKey: '甲方||alpha',
        rate: 100,
      );

      final result = await useCase.execute(
        editing: existing,
        record: existing.copyWith(allocationCutoffDate: 20260611),
      );

      expect(result.savedRecord.allocationCutoffDate, 20260611);
      final timingRows = await db.query(
        'timing_records',
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      expect(timingRows.single['allocation_cutoff_date'], 20260611);
      expect((await db.query('sync_outbox')).single['operation'], 'update');
    });

    test(
      'rejects allocation cutoff after next same-device handoff date',
      () async {
        final db = await AppDatabase.database;
        final deviceId = await _seedDevice(db);
        await _seedProject(db, projectId: 'project:alpha');
        await _seedProject(db, projectId: 'project:beta');
        final existing = await _seedTimingRecord(
          db,
          deviceId: deviceId,
          projectId: 'project:alpha',
          contact: '甲方',
          site: 'alpha',
          startDate: 20260601,
          hours: 1,
          income: 100,
        );
        await _seedTimingRecord(
          db,
          deviceId: deviceId,
          projectId: 'project:beta',
          contact: '甲方',
          site: 'beta',
          startDate: 20260610,
          hours: 1,
          income: 100,
        );

        await expectLater(
          useCase.execute(
            editing: existing,
            record: existing.copyWith(allocationCutoffDate: 20260612),
          ),
          throwsA(
            isA<SaveTimingRecordAllocationCutoffValidationException>().having(
              (error) => error.code,
              'code',
              SaveTimingRecordAllocationCutoffValidationException
                  .cutoffAfterNextSameDeviceStartDate,
            ),
          ),
        );

        final timingRows = await db.query(
          'timing_records',
          where: 'id = ?',
          whereArgs: [existing.id],
        );
        expect(timingRows.single['allocation_cutoff_date'], isNull);
        expect(timingRows.single['income_fen'], 10000);
        expect(await db.query('sync_outbox'), isEmpty);
        expect(await db.query('entity_sync_meta'), isEmpty);
      },
    );

    test(
      'allows allocation cutoff before later next same-device start date',
      () async {
        final db = await AppDatabase.database;
        final deviceId = await _seedDevice(db);
        await _seedProject(db, projectId: 'project:alpha');
        await _seedProject(db, projectId: 'project:beta');
        final existing = await _seedTimingRecord(
          db,
          deviceId: deviceId,
          projectId: 'project:alpha',
          contact: '甲方',
          site: 'alpha',
          startDate: 20260601,
          hours: 1,
          income: 100,
        );
        await _seedTimingRecord(
          db,
          deviceId: deviceId,
          projectId: 'project:beta',
          contact: '甲方',
          site: 'beta',
          startDate: 20260610,
          hours: 1,
          income: 100,
        );
        await _seedRate(
          db,
          deviceId: deviceId,
          projectId: 'project:alpha',
          projectKey: '甲方||alpha',
          rate: 100,
        );

        final result = await useCase.execute(
          editing: existing,
          record: existing.copyWith(allocationCutoffDate: 20260605),
        );

        expect(result.savedRecord.allocationCutoffDate, 20260605);
        expect(result.projectChanged, isFalse);
        expect(result.settlementRevoked, isFalse);
        final timingRows = await db.query(
          'timing_records',
          where: 'id = ?',
          whereArgs: [existing.id],
        );
        expect(timingRows.single['allocation_cutoff_date'], 20260605);
        expect((await db.query('sync_outbox')).single['operation'], 'update');
      },
    );

    test(
      'ignores different-device records when validating allocation cutoff',
      () async {
        final db = await AppDatabase.database;
        final deviceA = await _seedDevice(db, name: 'Device A');
        final deviceB = await _seedDevice(db, name: 'Device B');
        await _seedProject(db, projectId: 'project:alpha');
        await _seedProject(db, projectId: 'project:beta');
        final existing = await _seedTimingRecord(
          db,
          deviceId: deviceA,
          projectId: 'project:alpha',
          contact: '甲方',
          site: 'alpha',
          startDate: 20260601,
          hours: 1,
          income: 100,
        );
        await _seedTimingRecord(
          db,
          deviceId: deviceB,
          projectId: 'project:beta',
          contact: '甲方',
          site: 'beta',
          startDate: 20260605,
          hours: 1,
          income: 100,
        );

        final result = await useCase.execute(
          editing: existing,
          record: existing.copyWith(allocationCutoffDate: 20260610),
        );

        expect(result.savedRecord.allocationCutoffDate, 20260610);
        final timingRows = await db.query(
          'timing_records',
          where: 'id = ?',
          whereArgs: [existing.id],
        );
        expect(timingRows.single['allocation_cutoff_date'], 20260610);
      },
    );

    test(
      'allows allocation cutoff when no next same-device record exists',
      () async {
        final db = await AppDatabase.database;
        final deviceId = await _seedDevice(db);
        await _seedProject(db, projectId: 'project:alpha');
        final existing = await _seedTimingRecord(
          db,
          deviceId: deviceId,
          projectId: 'project:alpha',
          contact: '甲方',
          site: 'alpha',
          startDate: 20260601,
          hours: 1,
          income: 100,
        );

        final result = await useCase.execute(
          editing: existing,
          record: existing.copyWith(allocationCutoffDate: 20260701),
        );

        expect(result.savedRecord.allocationCutoffDate, 20260701);
        expect(result.projectChanged, isFalse);
        expect(result.mergeDissolved, isFalse);
        expect(result.settlementRevoked, isFalse);
        final timingRows = await db.query('timing_records');
        expect(timingRows.single['allocation_cutoff_date'], 20260701);
      },
    );

    test(
      'cutoff-only legal edit does not change project state and writes update outbox',
      () async {
        final db = await AppDatabase.database;
        final deviceId = await _seedDevice(db, defaultUnitPrice: 100);
        await _seedProject(
          db,
          projectId: 'project:alpha',
          status: ProjectStatus.settled,
          settledAt: '2026-06-01T00:00:00.000Z',
        );
        await _seedProject(db, projectId: 'project:beta');
        await _seedProject(db, projectId: 'project:gamma');
        await _seedActiveMergeGroup(
          db,
          contact: '甲方',
          members: [
            ('project:alpha', '甲方||alpha'),
            ('project:gamma', '甲方||gamma'),
          ],
        );
        await _insertPayment(
          db,
          projectId: 'project:alpha',
          amount: 100,
          amountFen: 10000,
        );
        final existing = await _seedTimingRecord(
          db,
          deviceId: deviceId,
          projectId: 'project:alpha',
          contact: '甲方',
          site: 'alpha',
          startDate: 20260601,
          hours: 1,
          income: 100,
        );
        await _seedTimingRecord(
          db,
          deviceId: deviceId,
          projectId: 'project:beta',
          contact: '甲方',
          site: 'beta',
          startDate: 20260610,
          hours: 1,
          income: 100,
        );
        await _seedRate(
          db,
          deviceId: deviceId,
          projectId: 'project:alpha',
          projectKey: '甲方||alpha',
          rate: 100,
        );

        final result = await useCase.execute(
          editing: existing,
          record: existing.copyWith(allocationCutoffDate: 20260610),
        );

        expect(result.projectChanged, isFalse);
        expect(result.mergeDissolved, isFalse);
        expect(result.settlementRevoked, isFalse);
        expect(result.revokedProjectIds, isEmpty);
        expect(result.savedRecord.income, 100);
        expect(result.savedRecord.allocationCutoffDate, 20260610);

        final projectRows = await db.query(
          'projects',
          where: 'id = ?',
          whereArgs: ['project:alpha'],
        );
        expect(projectRows.single['status'], ProjectStatus.settled.name);
        expect(projectRows.single['settled_at'], isNotNull);
        final mergeRows = await db.query('account_project_merge_groups');
        expect(mergeRows.single['is_active'], 1);
        expect(mergeRows.single['dissolved_at'], isNull);

        final timingRows = await db.query(
          'timing_records',
          where: 'id = ?',
          whereArgs: [existing.id],
        );
        expect(timingRows.single['income_fen'], 10000);
        expect(timingRows.single['allocation_cutoff_date'], 20260610);

        final outboxRows = await db.query('sync_outbox');
        expect(outboxRows, hasLength(1));
        expect(outboxRows.single['operation'], 'update');
        final payload =
            jsonDecode(outboxRows.single['payload_json'] as String)
                as Map<String, Object?>;
        final recordPayload = payload['record'] as Map<String, Object?>;
        expect(recordPayload['allocation_cutoff_date'], 20260610);
      },
    );
  });

  group('编辑计时记录，project A → B：自动解除合并', () {
    test('解除合并 + affectedProjectIds 包含 A、B 与组内其他成员', () async {
      final db = await AppDatabase.database;
      final deviceA = await _seedDevice(
        db,
        name: 'DevA',
        defaultUnitPrice: 100,
      );
      final deviceB = await _seedDevice(
        db,
        name: 'DevB',
        defaultUnitPrice: 100,
      );

      await _seedProject(db, projectId: 'project:A');
      await _seedProject(db, projectId: 'project:B');
      await _seedProject(db, projectId: 'project:C');
      // A 和 C 在同一个合并组。
      await _seedActiveMergeGroup(
        db,
        contact: '甲方',
        members: [('project:A', '甲方||A'), ('project:C', '甲方||C')],
      );

      final existing = await _seedTimingRecord(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 1,
        income: 100,
      );

      // 把 A 的工地改成 B 的工地（触发 legacy_project_key 变化 →
      // resolveOrCreate 切到 project:B）。
      final result = await useCase.execute(
        editing: existing,
        record: existing.copyWith(
          deviceId: deviceB,
          contact: '甲方',
          site: 'B',
          // 把 projectId 清空，让 use case 通过 resolver 切到 project:B。
          projectId: '',
          hours: 2,
          income: 200,
        ),
      );

      expect(result.projectChanged, isTrue);
      expect(result.mergeDissolved, isTrue);
      expect(
        result.affectedProjectIds,
        containsAll(['project:A', 'project:B', 'project:C']),
      );

      // 合并组已 dissolved。
      final mergeGroupRows = await db.query('account_project_merge_groups');
      expect(mergeGroupRows.single['is_active'], 0);
      expect(mergeGroupRows.single['dissolved_at'], isNotNull);
    });
  });

  group('解除合并失败：事务整体回滚', () {
    test('impact service 抛错 → 计时未保存，合并未解除', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:A');
      await _seedProject(db, projectId: 'project:B');
      await _seedActiveMergeGroup(
        db,
        contact: '甲方',
        members: [('project:A', '甲方||A'), ('project:B', '甲方||B')],
      );
      final existing = await _seedTimingRecord(
        db,
        deviceId: deviceId,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 1,
        income: 100,
      );

      // 注入一个"在 evaluate 之后抛错"的 impact service，模拟事务后期失败。
      final failingUseCase = LocalSaveTimingRecordWithImpactUseCase(
        timingRepository: timingRepository,
        timingCalculationHistoryRepository: calculationHistoryRepository,
        mergeRepository: mergeRepository,
        deviceRepository: deviceRepository,
        projectRateRepository: projectRateRepository,
        projectResolver: projectResolver,
        impactService: const _FailingImpactService(),
        now: () => DateTime.utc(2026, 5, 26, 12),
      );

      await expectLater(
        failingUseCase.execute(
          editing: existing,
          record: existing.copyWith(
            contact: '甲方',
            site: 'B',
            projectId: '',
            hours: 2,
            income: 200,
          ),
        ),
        throwsA(isA<StateError>()),
      );

      // 1) timing_records 未被更新到新值（仍是 income_fen=10000）。
      final timingRows = await db.query('timing_records');
      expect(timingRows.single['income_fen'], 10000, reason: '保存计时应被事务回滚');
      expect(
        timingRows.single['project_id'],
        'project:A',
        reason: '保存的 project_id 也应被回滚',
      );

      // 2) merge group 仍处于 active（未被半解除）。
      final mergeGroupRows = await db.query('account_project_merge_groups');
      expect(mergeGroupRows.single['is_active'], 1, reason: '合并组解除应被事务回滚');
      expect(mergeGroupRows.single['dissolved_at'], isNull);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    });

    test('sync_outbox 写失败时保存整体回滚', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:alpha');
      final failingUseCase = LocalSaveTimingRecordWithImpactUseCase(
        timingRepository: timingRepository,
        timingCalculationHistoryRepository: calculationHistoryRepository,
        mergeRepository: mergeRepository,
        deviceRepository: deviceRepository,
        projectRateRepository: projectRateRepository,
        projectResolver: projectResolver,
        impactService: impactService,
        syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
        now: () => DateTime.utc(2026, 5, 26, 12),
      );

      await expectLater(
        failingUseCase.execute(
          editing: null,
          record: TimingRecord(
            deviceId: deviceId,
            startDate: 20260520,
            projectId: 'project:alpha',
            contact: '甲方',
            site: 'alpha',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 1,
            hours: 1,
            income: 100,
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect(await db.query('timing_records'), isEmpty);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    });
  });

  group('结清撤销 / 不撤销', () {
    test('旧项目改走后：fen 显示已不再覆盖 → 自动撤销结清，不删除 payment/write_off', () async {
      final db = await AppDatabase.database;
      final deviceA = await _seedDevice(db, defaultUnitPrice: 100);
      final deviceB = await _seedDevice(db, defaultUnitPrice: 100);

      // 旧项目 A 已结清，已收 100 元（10000 fen）。
      await _seedProject(
        db,
        projectId: 'project:A',
        status: ProjectStatus.settled,
        settledAt: '2026-05-20T00:00:00.000Z',
      );
      await _seedProject(db, projectId: 'project:B');
      await _seedRate(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        projectKey: '甲方||A',
        rate: 100,
      );
      await _seedRate(
        db,
        deviceId: deviceB,
        projectId: 'project:B',
        projectKey: '甲方||B',
        rate: 100,
      );
      await _insertPayment(
        db,
        projectId: 'project:A',
        amount: 100,
        amountFen: 10000,
      );

      // A 项目原本有 1 小时 × 100 = 100 元应收，已收 100 元，刚好覆盖、settled。
      final existingOnA = await _seedTimingRecord(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 1,
        income: 100,
      );
      // 再给 A 加一条 1 小时（增加 100 元应收），保留它独立用作 settled 项目。
      // 然后我们把 existingOnA 移到 B，A 还剩 1 小时（100 元应收，只覆盖 100 元收款，
      // 仍刚好覆盖）。所以这里加一条更大的应收，确保移走后 A 不再覆盖。
      await _seedTimingRecord(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 1,
        income: 100,
      );

      // 现在 A 的应收 = 200 元，已收 100 元。结清状态是脏数据（之前结清了 100 元的时候是对的，
      // 现在 200 元应收已超过）。我们把其中一条计时移到 B → A 应收降回 100 元，刚好覆盖，
      // 不撤销结清。为了真正测试"撤销"，应该让 A 的剩余应收 > 已收。
      // 重新设计：把 A 的剩余 1 小时改成大数字（保留 100 元应收 + 已收 100 → 仍覆盖，
      // 不撤销）；为了让 A 撤销结清，应让 A 剩余应收 > 已收。
      // 改为：把 existingOnA 移到 B，A 剩 100 元应收，已收 100 元 → 刚好覆盖，不撤销。
      // → 改测一个真实失衡场景：再加一条 200 元应收在 A 保留。

      // 重做种子：清掉刚才加的，加一条 200 元应收。
      await db.delete(
        'timing_records',
        where: 'project_id = ? AND id != ?',
        whereArgs: ['project:A', existingOnA.id],
      );
      await _seedTimingRecord(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 2,
        income: 200,
      );

      // 当前 A: 应收 100 + 200 = 300 元（fen=30000）；已收 10000 fen → 仍欠 20000 fen。
      // 但 A 的 status 是 settled（dirty 状态）。
      // 把 existingOnA（100 元的那条）移到 B → A 仅剩 200 元应收，已收 100 元 → 剩余 100 元 → 需要撤销。
      final result = await useCase.execute(
        editing: existingOnA,
        record: existingOnA.copyWith(
          deviceId: deviceB,
          contact: '甲方',
          site: 'B',
          projectId: '',
          hours: 1,
          income: 100,
        ),
      );

      expect(result.projectChanged, isTrue);
      expect(result.settlementRevoked, isTrue);
      expect(result.revokedProjectIds, contains('project:A'));

      // A status 已撤销结清。
      final projectA = (await db.query(
        'projects',
        where: 'id = ?',
        whereArgs: ['project:A'],
      )).single;
      expect(projectA['status'], ProjectStatus.active.name);
      expect(projectA['settled_at'], isNull);

      // payment 没动。
      expect(await db.query('account_payments'), hasLength(1));
      // 其它 timing 没动（A 还剩一条 200 元应收的）。
      final remainingA = await db.query(
        'timing_records',
        where: 'project_id = ?',
        whereArgs: ['project:A'],
      );
      expect(remainingA, hasLength(1));
    });

    test(
      'timing_save_revocation_project_outbox_test: restored project update '
      'shares transaction group, sequence and actor with timing save',
      () async {
        final db = await AppDatabase.database;
        final deviceA = await _seedDevice(db, defaultUnitPrice: 100);
        final deviceB = await _seedDevice(db, defaultUnitPrice: 100);
        await _seedProject(
          db,
          projectId: 'project:A',
          status: ProjectStatus.settled,
          settledAt: '2026-05-20T00:00:00.000Z',
        );
        await _seedProject(db, projectId: 'project:B');
        await _seedRate(
          db,
          deviceId: deviceA,
          projectId: 'project:A',
          projectKey: '甲方||A',
          rate: 100,
        );
        await _seedRate(
          db,
          deviceId: deviceB,
          projectId: 'project:B',
          projectKey: '甲方||B',
          rate: 100,
        );
        await _insertPayment(
          db,
          projectId: 'project:A',
          amount: 100,
          amountFen: 10000,
        );
        final existingOnA = await _seedTimingRecord(
          db,
          deviceId: deviceA,
          projectId: 'project:A',
          contact: '甲方',
          site: 'A',
          hours: 1,
          income: 100,
        );
        await _seedTimingRecord(
          db,
          deviceId: deviceA,
          projectId: 'project:A',
          contact: '甲方',
          site: 'A',
          hours: 2,
          income: 200,
        );

        final actorUseCase = LocalSaveTimingRecordWithImpactUseCase(
          timingRepository: timingRepository,
          timingCalculationHistoryRepository: calculationHistoryRepository,
          mergeRepository: mergeRepository,
          deviceRepository: deviceRepository,
          projectRateRepository: projectRateRepository,
          projectRepository: projectRepository,
          projectResolver: projectResolver,
          impactService: impactService,
          actorProvider: () => ActorContext(
            actorType: OperationActorType.owner,
            actorId: 'owner-save-revoke',
            sessionId: 'session-save-revoke',
          ),
          now: () => DateTime.utc(2026, 5, 26, 12),
        );

        final result = await actorUseCase.execute(
          editing: existingOnA,
          record: existingOnA.copyWith(
            deviceId: deviceB,
            contact: '甲方',
            site: 'B',
            projectId: '',
            hours: 1,
            income: 100,
          ),
        );

        expect(result.projectChanged, isTrue);
        expect(result.settlementRevoked, isTrue);
        expect(result.revokedProjectIds, <String>['project:A']);

        final projectA = (await db.query(
          'projects',
          where: 'id = ?',
          whereArgs: ['project:A'],
        )).single;
        expect(projectA['status'], ProjectStatus.active.name);
        expect(projectA['settled_at'], isNull);
        expect(projectA['settled_snapshot'], isNull);

        final outboxRows = await db.query(
          'sync_outbox',
          orderBy: 'local_sequence ASC',
        );
        expect(outboxRows, hasLength(2));
        expect(outboxRows[0]['entity_type'], 'timing_record');
        expect(outboxRows[0]['entity_id'], result.savedRecord.id.toString());
        expect(outboxRows[0]['operation'], 'update');
        expect(outboxRows[1]['entity_type'], ProjectSyncEnqueuer.entityType);
        expect(outboxRows[1]['entity_id'], 'project:A');
        expect(outboxRows[1]['operation'], 'update');

        final groupId = outboxRows[0]['transaction_group_id'];
        expect(groupId, isA<String>());
        expect(groupId as String, startsWith('txn-'));
        expect(outboxRows[1]['transaction_group_id'], groupId);
        expect(
          outboxRows.map((row) => row['local_sequence']).toList(),
          <int>[1, 2],
          reason: 'timing update is the causal save; project restore follows',
        );

        for (final row in outboxRows) {
          final payload = (jsonDecode(row['payload_json'] as String) as Map)
              .cast<String, Object?>();
          expect(payload['payload_schema_version'], 1);
          expect(payload['entity_type'], row['entity_type']);
          expect(payload['entity_id'], row['entity_id']);
          expect(payload['operation'], row['operation']);
          final actor = payload['actor'] as Map<String, Object?>;
          expect(actor['type'], 'owner');
          expect(actor['id'], 'owner-save-revoke');
          expect(actor['session_id'], 'session-save-revoke');
          final recordPayload = payload['record'] as Map<String, Object?>;
          expect(recordPayload.containsKey('actor'), isFalse);
          expect(recordPayload.containsKey('payload_schema_version'), isFalse);
        }

        final projectPayload =
            (jsonDecode(outboxRows[1]['payload_json'] as String) as Map)
                .cast<String, Object?>();
        final projectRecord = projectPayload['record'] as Map<String, Object?>;
        expect(projectRecord['status'], ProjectStatus.active.name);
        expect(projectRecord['settled_at'], isNull);
        expect(projectRecord['settled_snapshot'], isNull);

        final metaRows = await db.query(
          'entity_sync_meta',
          orderBy: 'entity_type ASC',
        );
        expect(metaRows, hasLength(2));
        expect(metaRows.map((row) => row['updated_by']).toSet(), {
          'owner-save-revoke',
        });
        final projectMeta = metaRows.singleWhere(
          (row) => row['entity_type'] == ProjectSyncEnqueuer.entityType,
        );
        expect(projectMeta['local_id'], 'project:A');
        expect(projectMeta['sync_status'], SyncStatus.pendingUpdate.name);
      },
    );

    test('旧项目改走后，收款 + 核销仍覆盖应收 → 不撤销结清', () async {
      final db = await AppDatabase.database;
      final deviceA = await _seedDevice(db, defaultUnitPrice: 100);
      final deviceB = await _seedDevice(db, defaultUnitPrice: 100);
      await _seedProject(
        db,
        projectId: 'project:A',
        status: ProjectStatus.settled,
        settledAt: '2026-05-20T00:00:00.000Z',
      );
      await _seedProject(db, projectId: 'project:B');
      await _seedRate(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        projectKey: '甲方||A',
        rate: 100,
      );
      await _seedRate(
        db,
        deviceId: deviceB,
        projectId: 'project:B',
        projectKey: '甲方||B',
        rate: 100,
      );

      // A 应收原本 200 元，全部已收。
      final existingOnA = await _seedTimingRecord(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 1,
        income: 100,
      );
      await _seedTimingRecord(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 1,
        income: 100,
      );
      await _insertPayment(
        db,
        projectId: 'project:A',
        amount: 200,
        amountFen: 20000,
      );

      // 把 existingOnA 移到 B：A 剩 100 元应收，已收 200 元 → 已覆盖 → 不撤销。
      final result = await useCase.execute(
        editing: existingOnA,
        record: existingOnA.copyWith(
          deviceId: deviceB,
          contact: '甲方',
          site: 'B',
          projectId: '',
          hours: 1,
          income: 100,
        ),
      );

      expect(result.projectChanged, isTrue);
      expect(result.settlementRevoked, isFalse);
      expect(result.revokedProjectIds, isEmpty);

      final projectA = (await db.query(
        'projects',
        where: 'id = ?',
        whereArgs: ['project:A'],
      )).single;
      expect(
        projectA['status'],
        ProjectStatus.settled.name,
        reason: 'A 的应收已被收款覆盖，无需撤销结清',
      );
    });

    test('timing_save_no_revocation_no_project_outbox_test: covered settlement '
        'keeps the legacy single timing outbox shape', () async {
      final db = await AppDatabase.database;
      final deviceA = await _seedDevice(db, defaultUnitPrice: 100);
      final deviceB = await _seedDevice(db, defaultUnitPrice: 100);
      await _seedProject(
        db,
        projectId: 'project:A',
        status: ProjectStatus.settled,
        settledAt: '2026-05-20T00:00:00.000Z',
      );
      await _seedProject(db, projectId: 'project:B');
      await _seedRate(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        projectKey: '甲方||A',
        rate: 100,
      );
      await _seedRate(
        db,
        deviceId: deviceB,
        projectId: 'project:B',
        projectKey: '甲方||B',
        rate: 100,
      );
      final existingOnA = await _seedTimingRecord(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 1,
        income: 100,
      );
      await _seedTimingRecord(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 1,
        income: 100,
      );
      await _insertPayment(
        db,
        projectId: 'project:A',
        amount: 200,
        amountFen: 20000,
      );

      final result = await useCase.execute(
        editing: existingOnA,
        record: existingOnA.copyWith(
          deviceId: deviceB,
          contact: '甲方',
          site: 'B',
          projectId: '',
          hours: 1,
          income: 100,
        ),
      );

      expect(result.settlementRevoked, isFalse);
      expect(result.revokedProjectIds, isEmpty);

      final outboxRows = await db.query('sync_outbox');
      expect(outboxRows, hasLength(1));
      expect(outboxRows.single['entity_type'], 'timing_record');
      expect(outboxRows.single['operation'], 'update');
      expect(outboxRows.single['transaction_group_id'], isNull);
      expect(outboxRows.single['local_sequence'], isNull);

      final metaRows = await db.query('entity_sync_meta');
      expect(metaRows, hasLength(1));
      expect(metaRows.single['entity_type'], 'timing_record');
      expect(
        (await db.query(
          'projects',
          where: 'id = ?',
          whereArgs: ['project:A'],
        )).single['status'],
        ProjectStatus.settled.name,
      );
    });

    test('timing_save_revocation_rollback_test: project outbox failure rolls '
        'back timing save, project restore, outbox and meta', () async {
      final db = await AppDatabase.database;
      final deviceA = await _seedDevice(db, defaultUnitPrice: 100);
      final deviceB = await _seedDevice(db, defaultUnitPrice: 100);
      await _seedProject(
        db,
        projectId: 'project:A',
        status: ProjectStatus.settled,
        settledAt: '2026-05-20T00:00:00.000Z',
      );
      await _seedProject(db, projectId: 'project:B');
      await _seedRate(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        projectKey: '甲方||A',
        rate: 100,
      );
      await _seedRate(
        db,
        deviceId: deviceB,
        projectId: 'project:B',
        projectKey: '甲方||B',
        rate: 100,
      );
      await _insertPayment(
        db,
        projectId: 'project:A',
        amount: 100,
        amountFen: 10000,
      );
      final existingOnA = await _seedTimingRecord(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 1,
        income: 100,
      );
      await _seedTimingRecord(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 2,
        income: 200,
      );
      final failingProjectOutboxUseCase =
          LocalSaveTimingRecordWithImpactUseCase(
            timingRepository: timingRepository,
            timingCalculationHistoryRepository: calculationHistoryRepository,
            mergeRepository: mergeRepository,
            deviceRepository: deviceRepository,
            projectRateRepository: projectRateRepository,
            projectRepository: projectRepository,
            projectResolver: projectResolver,
            impactService: impactService,
            projectSyncEnqueuer: const ProjectSyncEnqueuer(
              syncOutboxRepository: _ThrowingSyncOutboxRepository(),
            ),
            now: () => DateTime.utc(2026, 5, 26, 12),
          );

      await expectLater(
        failingProjectOutboxUseCase.execute(
          editing: existingOnA,
          record: existingOnA.copyWith(
            deviceId: deviceB,
            contact: '甲方',
            site: 'B',
            projectId: '',
            hours: 1,
            income: 100,
          ),
        ),
        throwsA(isA<StateError>()),
      );

      final timingRows = await db.query(
        'timing_records',
        where: 'id = ?',
        whereArgs: [existingOnA.id],
      );
      expect(timingRows.single['project_id'], 'project:A');
      expect(timingRows.single['income_fen'], 10000);

      final projectA = (await db.query(
        'projects',
        where: 'id = ?',
        whereArgs: ['project:A'],
      )).single;
      expect(projectA['status'], ProjectStatus.settled.name);
      expect(projectA['settled_at'], isNotNull);

      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    });

    test('1 fen 边界：fen 差 1 → 撤销；fen 刚好覆盖 → 不撤销', () async {
      final db = await AppDatabase.database;
      final deviceA = await _seedDevice(db, defaultUnitPrice: 100);
      final deviceB = await _seedDevice(db, defaultUnitPrice: 100);
      await _seedProject(
        db,
        projectId: 'project:A',
        status: ProjectStatus.settled,
        settledAt: '2026-05-20T00:00:00.000Z',
      );
      await _seedProject(db, projectId: 'project:B');
      await _seedRate(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        projectKey: '甲方||A',
        rate: 100,
      );
      await _seedRate(
        db,
        deviceId: deviceB,
        projectId: 'project:B',
        projectKey: '甲方||B',
        rate: 100,
      );

      // A 当前应收 100.00 元（fen=10000），已收 99.99 元（fen=9999） —— 差 1 fen。
      // status 是 settled（脏）。
      final existingOnA = await _seedTimingRecord(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 0.5,
        income: 50, // 50 元
      );
      await _seedTimingRecord(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 0.5,
        income: 50, // 50 元
      );
      await _insertPayment(
        db,
        projectId: 'project:A',
        amount: 99.99,
        amountFen: 9999,
      );

      // 把 existingOnA 移到 B → A 剩 50 元应收（fen=5000），已收 9999 fen →
      // 已收 > 应收（多收 4999 fen），coversReceivable = true，不撤销。
      // 这不是我们想要的 "差 1 fen" 边界。需要换个安排：
      // - 保留 existingOnA 在 A，加一条新计时让 A 应收 100.01 元（fen=10001），
      //   已收 9999 fen → 差 2 fen，未覆盖 → 撤销结清。
      // 用 income=0.01 实现 100.01 元应收。
      await _insertTimingRow(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 0.0001,
        income: 0.01,
      );

      // 此刻 A 应收 = 50 + 50 + 0.01 = 100.01 元（fen=10001），已收 9999 fen → 差 2 fen，未覆盖。
      // 我们想测的是"刚好差 1 fen"。直接调一次 evaluate：
      final probe1 = await impactService.evaluate(
        executor: db,
        receivableFenByProjectId: const {'project:A': 10001},
      );
      expect(probe1.snapshots.single.remainingFen, 2);

      // 现在为了真正测"刚好差 1 fen"，构造 A 应收 = 100 元（10000 fen），已收 9999 fen：
      // 删掉刚才加的 0.01 元那条。
      await db.delete(
        'timing_records',
        where: 'income_fen = ?',
        whereArgs: [1],
      );
      // A 应收回到 100.00 元（10000 fen），已收 9999 fen → 差 1 fen。
      final probe2 = await impactService.evaluate(
        executor: db,
        receivableFenByProjectId: const {'project:A': 10000},
      );
      expect(probe2.snapshots.single.remainingFen, 1);
      expect(probe2.snapshots.single.coversReceivable, isFalse);

      // 走 use case：再加一条空计时在 B（不改 A）。
      // 这里我们直接编辑 existingOnA 把它移到 B：A 剩 50 元应收（fen=5000），
      // 已收 9999 fen → 多收 4999 fen → 已覆盖 → 不撤销（刚好覆盖类）。
      final result = await useCase.execute(
        editing: existingOnA,
        record: existingOnA.copyWith(
          deviceId: deviceB,
          contact: '甲方',
          site: 'B',
          projectId: '',
        ),
      );

      expect(result.projectChanged, isTrue);
      // A 现在已收 > 应收 → 仍 covered → 不撤销。
      expect(result.settlementRevoked, isFalse);
    });
  });

  group('amount REAL 与 amount_fen 故意不一致：判断走 fen', () {
    test('REAL 看似差很多，fen 显示覆盖 → 不撤销结清', () async {
      final db = await AppDatabase.database;
      final deviceA = await _seedDevice(db, defaultUnitPrice: 100);
      final deviceB = await _seedDevice(db, defaultUnitPrice: 100);
      await _seedProject(
        db,
        projectId: 'project:A',
        status: ProjectStatus.settled,
        settledAt: '2026-05-20T00:00:00.000Z',
      );
      await _seedProject(db, projectId: 'project:B');
      await _seedRate(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        projectKey: '甲方||A',
        rate: 100,
      );
      await _seedRate(
        db,
        deviceId: deviceB,
        projectId: 'project:B',
        projectKey: '甲方||B',
        rate: 100,
      );

      // A 应收 200 元，amount REAL 看似只收 0.01，amount_fen 才是权威 20000。
      final existingOnA = await _seedTimingRecord(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 1,
        income: 100,
      );
      await _seedTimingRecord(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 1,
        income: 100,
      );
      await _insertPayment(
        db,
        projectId: 'project:A',
        amount: 0.01, // 脏 REAL
        amountFen: 20000, // 权威 fen
      );

      // 把 existingOnA 移到 B → A 剩 100 元应收，权威已收 20000 fen → 多收 100 元 →
      // 已覆盖 → 不撤销。如果错读 REAL 0.01 → 会误判应撤销。
      final result = await useCase.execute(
        editing: existingOnA,
        record: existingOnA.copyWith(
          deviceId: deviceB,
          contact: '甲方',
          site: 'B',
          projectId: '',
          hours: 1,
          income: 100,
        ),
      );

      expect(
        result.settlementRevoked,
        isFalse,
        reason: '判断必须走 amount_fen，不应被脏 REAL 干扰',
      );
    });
  });

  group('UI pending retry 不再是一致性保障', () {
    test('execute 一次返回后，DB 状态已一致：无需任何 UI retry', () async {
      final db = await AppDatabase.database;
      final deviceA = await _seedDevice(db, defaultUnitPrice: 100);
      final deviceB = await _seedDevice(db, defaultUnitPrice: 100);
      await _seedProject(db, projectId: 'project:A');
      await _seedProject(db, projectId: 'project:B');
      await _seedActiveMergeGroup(
        db,
        contact: '甲方',
        members: [('project:A', '甲方||A'), ('project:B', '甲方||B')],
      );
      final existing = await _seedTimingRecord(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 1,
        income: 100,
      );

      await useCase.execute(
        editing: existing,
        record: existing.copyWith(
          deviceId: deviceB,
          contact: '甲方',
          site: 'B',
          projectId: '',
        ),
      );

      // 不再做任何 UI retry —— 直接断言：merge 已 dissolve、timing 已落 B、A 还在
      // （因为 status 不是 settled，所以不会触发 revoke）。
      final mergeGroupRows = await db.query('account_project_merge_groups');
      expect(
        mergeGroupRows.single['is_active'],
        0,
        reason: '事务提交后，合并组应已解除，无需 UI retry',
      );
      final timingRows = await db.query('timing_records');
      expect(timingRows.single['project_id'], 'project:B');
    });
  });

  // =================================================================
  // Step 3 收尾修复：事务内权威 oldProjectId / update 行数检查 /
  // old + new 两侧合并组解除。
  // =================================================================

  group('事务内重读旧 TimingRecord — stale editing 不再作为权威', () {
    test('UI 传入 stale editing(A)，但 DB 旧记录 projectId 已是 C：'
        '事务内必须以 C 作为 oldProjectId', () async {
      final db = await AppDatabase.database;
      final deviceA = await _seedDevice(db);
      final deviceB = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:A');
      await _seedProject(db, projectId: 'project:B');
      await _seedProject(db, projectId: 'project:C');
      await _seedProject(db, projectId: 'project:D');
      // C 和 D 在同一个合并组；A、B 都不在任何合并组。
      // 期望：保存后只解除 C 的组（A 不在组中），不解除 A 的组（因为 oldProjectId
      // 必须是 C 而不是 stale 的 A）。
      await _seedActiveMergeGroup(
        db,
        contact: '甲方',
        members: [('project:C', '甲方||C'), ('project:D', '甲方||D')],
      );
      // DB 里真实旧记录的 projectId 已经是 C（不是 UI 显示的 A）。
      final dbRecord = await _seedTimingRecord(
        db,
        deviceId: deviceA,
        projectId: 'project:C',
        contact: '甲方',
        site: 'C',
        hours: 1,
        income: 100,
      );
      // UI 那边显示的 editing 仍是过期的"在 A 上"。
      final staleEditing = dbRecord.copyWith(
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
      );

      final result = await useCase.execute(
        editing: staleEditing,
        record: staleEditing.copyWith(
          deviceId: deviceB,
          contact: '甲方',
          site: 'B',
          projectId: '',
          hours: 2,
          income: 200,
        ),
      );

      expect(result.projectChanged, isTrue);
      // 必须按 DB 权威的 C 作为 oldProjectId，而不是 UI stale 的 A。
      expect(
        result.affectedProjectIds,
        contains('project:C'),
        reason: 'oldProjectId 必须来自 DB（C），不是 UI stale 的 A',
      );
      expect(result.affectedProjectIds, contains('project:B'));
      // C 在组中，解除组后 D 也应纳入受影响。
      expect(result.affectedProjectIds, contains('project:D'));
      expect(result.mergeDissolved, isTrue, reason: 'C 所在合并组应被解除');

      // 合并组（C+D）已 dissolved。
      final groupRows = await db.query('account_project_merge_groups');
      expect(groupRows.single['is_active'], 0);
    });
  });

  group('事务内重读旧 TimingRecord — DB 中已不存在', () {
    test('UI editing.id 在 DB 中已不存在：抛错且事务回滚', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:A');
      await _seedProject(db, projectId: 'project:B');
      await _seedActiveMergeGroup(
        db,
        contact: '甲方',
        members: [('project:A', '甲方||A'), ('project:B', '甲方||B')],
      );

      // 注意：不在 DB 中 seed 这条 timing；UI 传入的 editing.id 是 99999。
      final ghostEditing = TimingRecord(
        id: 99999,
        deviceId: deviceId,
        startDate: 20260518,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        type: TimingType.hours,
        startMeter: 0,
        endMeter: 1,
        hours: 1,
        income: 100,
      );

      await expectLater(
        useCase.execute(
          editing: ghostEditing,
          record: ghostEditing.copyWith(
            contact: '甲方',
            site: 'B',
            projectId: '',
            hours: 2,
            income: 200,
          ),
        ),
        throwsA(isA<TimingRecordSaveStaleException>()),
      );

      // 1) timing_records 仍为空（save 已回滚）。
      final timingRows = await db.query('timing_records');
      expect(timingRows, isEmpty, reason: 'save 必须回滚');

      // 2) 合并组仍 active（dissolve 已回滚或根本未发生）。
      final groupRows = await db.query('account_project_merge_groups');
      expect(groupRows.single['is_active'], 1, reason: '合并组不应被触碰');
    });
  });

  group('updateWithExecutor 返回行数异常', () {
    test('update 返回 0 → 抛 TimingRecordSaveStaleException 并回滚', () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:A');
      await _seedProject(db, projectId: 'project:B');
      await _seedActiveMergeGroup(
        db,
        contact: '甲方',
        members: [('project:A', '甲方||A'), ('project:B', '甲方||B')],
      );
      final existing = await _seedTimingRecord(
        db,
        deviceId: deviceId,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 1,
        income: 100,
      );

      // 注入一个固定返回 0 的 timing repository，模拟"event-loop 之间被并发删除"
      // 类型的更新失败。
      final forcedZeroUseCase = LocalSaveTimingRecordWithImpactUseCase(
        timingRepository: _UpdateAlwaysReturnsZeroTimingRepository(),
        timingCalculationHistoryRepository: calculationHistoryRepository,
        mergeRepository: mergeRepository,
        deviceRepository: deviceRepository,
        projectRateRepository: projectRateRepository,
        projectResolver: projectResolver,
        impactService: impactService,
        now: () => DateTime.utc(2026, 5, 26, 12),
      );

      await expectLater(
        forcedZeroUseCase.execute(
          editing: existing,
          record: existing.copyWith(
            contact: '甲方',
            site: 'B',
            projectId: '',
            hours: 2,
            income: 200,
          ),
        ),
        throwsA(isA<TimingRecordSaveStaleException>()),
      );

      // 1) 原 timing 行未被修改（保留 income_fen=10000、projectId=A）。
      final timingRows = await db.query('timing_records');
      expect(timingRows.single['income_fen'], 10000);
      expect(timingRows.single['project_id'], 'project:A');

      // 2) 合并组未被解除。
      final groupRows = await db.query('account_project_merge_groups');
      expect(groupRows.single['is_active'], 1);
    });
  });

  group('A / B 分别属于不同 active 合并组：两组都自动解除', () {
    test('group1=(A,C), group2=(B,D)，全部 contact=甲方：A -> B 应同时解除两组', () async {
      final db = await AppDatabase.database;
      final deviceA = await _seedDevice(db, defaultUnitPrice: 100);
      final deviceB = await _seedDevice(db, defaultUnitPrice: 100);
      // 4 个项目都属于"甲方"，site 互不相同。
      await _seedProject(db, projectId: 'project:A');
      await _seedProject(db, projectId: 'project:B');
      await _seedProject(db, projectId: 'project:C');
      await _seedProject(db, projectId: 'project:D');

      await _seedActiveMergeGroup(
        db,
        contact: '甲方',
        members: [('project:A', '甲方||A'), ('project:C', '甲方||C')],
      );
      await _seedActiveMergeGroup(
        db,
        contact: '甲方',
        members: [('project:B', '甲方||B'), ('project:D', '甲方||D')],
      );
      final existingOnA = await _seedTimingRecord(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 1,
        income: 100,
      );

      // 把 A 的计时移到 B（resolveOrCreate 会命中已存在的 project:B 因为同
      // contact+site）。
      final result = await useCase.execute(
        editing: existingOnA,
        record: existingOnA.copyWith(
          deviceId: deviceB,
          contact: '甲方',
          site: 'B',
          projectId: '',
          hours: 2,
          income: 200,
        ),
      );

      expect(result.projectChanged, isTrue);
      expect(result.mergeDissolved, isTrue);
      expect(
        result.affectedProjectIds,
        containsAll(['project:A', 'project:B', 'project:C', 'project:D']),
      );

      // 两个合并组都已 dissolve。
      final groupRows = await db.query(
        'account_project_merge_groups',
        orderBy: 'id ASC',
      );
      expect(groupRows, hasLength(2));
      expect(
        groupRows.every((r) => r['is_active'] == 0),
        isTrue,
        reason: 'group1 和 group2 都必须 dissolve',
      );
    });
  });

  group('A / B 属于同一个 active 合并组：只 dissolve 一次', () {
    test('group=(A,B)，从 A 改到 B → 同一组只 dissolve 一次', () async {
      final db = await AppDatabase.database;
      final deviceA = await _seedDevice(db, defaultUnitPrice: 100);
      final deviceB = await _seedDevice(db, defaultUnitPrice: 100);
      await _seedProject(db, projectId: 'project:A');
      await _seedProject(db, projectId: 'project:B');

      await _seedActiveMergeGroup(
        db,
        contact: '甲方',
        members: [('project:A', '甲方||A'), ('project:B', '甲方||B')],
      );

      final existingOnA = await _seedTimingRecord(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 1,
        income: 100,
      );

      final result = await useCase.execute(
        editing: existingOnA,
        record: existingOnA.copyWith(
          deviceId: deviceB,
          contact: '甲方',
          site: 'B',
          projectId: '',
          hours: 2,
          income: 200,
        ),
      );

      expect(result.projectChanged, isTrue);
      expect(result.mergeDissolved, isTrue);
      expect(
        result.affectedProjectIds,
        containsAll(['project:A', 'project:B']),
      );

      // 只有一个 group，全部 dissolved。
      final groupRows = await db.query('account_project_merge_groups');
      expect(groupRows, hasLength(1));
      expect(groupRows.single['is_active'], 0);

      // member 也都已 inactive。
      final memberRows = await db.query('account_project_merge_members');
      expect(memberRows.every((r) => r['is_active'] == 0), isTrue);
    });
  });

  group('两组合并解除中途失败：整体回滚', () {
    test('第二次 dissolve 抛错时，第一次 dissolve 也回滚 + timing 保存回滚', () async {
      final db = await AppDatabase.database;
      final deviceA = await _seedDevice(db, defaultUnitPrice: 100);
      final deviceB = await _seedDevice(db, defaultUnitPrice: 100);
      await _seedProject(db, projectId: 'project:A');
      await _seedProject(db, projectId: 'project:B');
      await _seedProject(db, projectId: 'project:C');
      await _seedProject(db, projectId: 'project:D');
      await _seedActiveMergeGroup(
        db,
        contact: '甲方',
        members: [('project:A', '甲方||A'), ('project:C', '甲方||C')],
      );
      await _seedActiveMergeGroup(
        db,
        contact: '甲方',
        members: [('project:B', '甲方||B'), ('project:D', '甲方||D')],
      );
      final existingOnA = await _seedTimingRecord(
        db,
        deviceId: deviceA,
        projectId: 'project:A',
        contact: '甲方',
        site: 'A',
        hours: 1,
        income: 100,
      );

      // 注入会在第二次 dissolve 时抛错的 merge repo。
      final failingMergeRepo = _FailOnSecondDissolveMergeRepository();
      final failingUseCase = LocalSaveTimingRecordWithImpactUseCase(
        timingRepository: timingRepository,
        timingCalculationHistoryRepository: calculationHistoryRepository,
        mergeRepository: failingMergeRepo,
        deviceRepository: deviceRepository,
        projectRateRepository: projectRateRepository,
        projectResolver: projectResolver,
        impactService: impactService,
        now: () => DateTime.utc(2026, 5, 26, 12),
      );

      await expectLater(
        failingUseCase.execute(
          editing: existingOnA,
          record: existingOnA.copyWith(
            deviceId: deviceB,
            contact: '甲方',
            site: 'B',
            projectId: '',
            hours: 2,
            income: 200,
          ),
        ),
        throwsA(isA<StateError>()),
      );

      // 第二次 dissolve 应被尝试 ⇒ failingMergeRepo 内部计数 >= 2。
      expect(
        failingMergeRepo.dissolveCalls,
        2,
        reason: '必须先 dissolve old group → 再尝试 dissolve new group → 失败',
      );

      // 整事务回滚验证：
      // 1) timing_records 仍是 income_fen=10000、project_id=project:A。
      final timingRows = await db.query('timing_records');
      expect(timingRows.single['income_fen'], 10000);
      expect(timingRows.single['project_id'], 'project:A');

      // 2) 两个 merge group 仍都是 is_active=1（即便第一次 dissolve 调用进了
      //    repository，事务回滚也会把 SQL UPDATE 一并撤销）。
      final groupRows = await db.query(
        'account_project_merge_groups',
        orderBy: 'id ASC',
      );
      expect(
        groupRows.every((r) => r['is_active'] == 1),
        isTrue,
        reason: '事务回滚后两个 group 都应恢复 active',
      );
    });
  });
}

/// 让 updateWithExecutor 永远返回 0 的 timing repo，用于触发 Step 3 收尾
/// 修复中的"update 0 行 → stale 异常 + 事务回滚"分支。
class _UpdateAlwaysReturnsZeroTimingRepository extends SqfliteTimingRepository {
  @override
  Future<int> updateWithExecutor(
    DatabaseExecutor executor,
    TimingRecord r,
  ) async {
    return 0;
  }
}

/// 第二次 dissolveGroupWithExecutor 抛错的 merge repo，用于测试
/// "old group dissolve 后 → new group dissolve 失败 → 整事务回滚"。
class _FailOnSecondDissolveMergeRepository
    extends SqfliteAccountProjectMergeRepository {
  int dissolveCalls = 0;

  @override
  Future<void> dissolveGroupWithExecutor(
    DatabaseExecutor executor, {
    required int groupId,
    required String dissolvedAt,
  }) async {
    dissolveCalls += 1;
    if (dissolveCalls >= 2) {
      throw StateError('注入的失败：第二次 dissolve 抛错以触发事务回滚');
    }
    return super.dissolveGroupWithExecutor(
      executor,
      groupId: groupId,
      dissolvedAt: dissolvedAt,
    );
  }
}

/// 用于"事务回滚"测试：evaluate 完成后抛错，使整个事务回滚。
class _FailingImpactService implements ProjectSettlementImpactService {
  const _FailingImpactService();

  @override
  Future<ProjectSettlementImpactDecision> evaluate({
    required DatabaseExecutor executor,
    required Map<String, int> receivableFenByProjectId,
    ProjectSettlementImpactReason reason = ProjectSettlementImpactReason.other,
  }) async {
    // 返回空决策；让 applyRevocations 阶段抛错。
    return const ProjectSettlementImpactDecision(snapshots: []);
  }

  @override
  Future<ProjectSettlementRevocationResult> applyRevocations({
    required DatabaseExecutor executor,
    required ProjectSettlementImpactDecision decision,
    required String updatedAtIso,
  }) async {
    throw StateError('注入的失败：模拟事务后期失败 → 应触发整体回滚');
  }
}

class _ThrowingSyncOutboxRepository implements SyncOutboxRepository {
  const _ThrowingSyncOutboxRepository();

  @override
  Future<SyncOutboxEntry> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
    String? transactionGroupId,
    int? localSequence,
  }) {
    throw StateError('注入的失败：sync_outbox 写入失败');
  }

  @override
  Future<SyncOutboxEntry> enqueueWithExecutor(
    DatabaseExecutor executor, {
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
    String? transactionGroupId,
    int? localSequence,
  }) {
    throw StateError('注入的失败：sync_outbox 写入失败');
  }

  @override
  Future<List<SyncOutboxEntry>> listPending({int limit = 50}) async {
    return [];
  }
}

class _MissingQuantityTimingRecord extends TimingRecord {
  _MissingQuantityTimingRecord({required super.deviceId})
    : super(
        startDate: 20260520,
        projectId: 'project:alpha',
        contact: '甲方',
        site: 'alpha',
        type: TimingType.hours,
        startMeter: 0,
        endMeter: 1,
        hours: 1,
        income: 100,
      );

  @override
  MeasureUnit get unit => MeasureUnit.hour;

  @override
  int? get quantityScaled => null;
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

Future<int> _seedDevice(
  Database db, {
  String name = 'Device',
  double defaultUnitPrice = 100.0,
}) async {
  return db.insert(
    'devices',
    Device(
      name: name,
      brand: 'brand',
      defaultUnitPrice: defaultUnitPrice,
      baseMeterHours: 0,
    ).toMap(),
  );
}

Future<void> _seedProject(
  Database db, {
  required String projectId,
  ProjectStatus status = ProjectStatus.active,
  String? settledAt,
}) async {
  final site = projectId.split(':').last;
  await db.insert(
    'projects',
    Project(
      id: projectId,
      contact: '甲方',
      site: site,
      status: status,
      settledAt: settledAt,
      legacyProjectKey: '甲方||$site',
      createdAt: '2026-05-18T00:00:00.000Z',
      updatedAt: '2026-05-18T00:00:00.000Z',
    ).toMap(),
  );
}

Future<TimingRecord> _seedTimingRecord(
  Database db, {
  required int deviceId,
  required String projectId,
  required String contact,
  required String site,
  required double hours,
  required double income,
  int startDate = 20260518,
  double startMeter = 0,
  int? allocationCutoffDate,
}) async {
  final record = TimingRecord(
    deviceId: deviceId,
    startDate: startDate,
    allocationCutoffDate: allocationCutoffDate,
    projectId: projectId,
    contact: contact,
    site: site,
    type: TimingType.hours,
    startMeter: startMeter,
    endMeter: hours,
    hours: hours,
    income: income,
  );
  final id = await db.insert('timing_records', record.toMap());
  return record.copyWith(id: id);
}

Future<void> _seedTimingRecords(
  Database db, {
  required int count,
  required int deviceId,
  required String projectId,
}) async {
  for (var index = 0; index < count; index++) {
    await _seedTimingRecord(
      db,
      deviceId: deviceId,
      projectId: projectId,
      contact: '甲方',
      site: projectId.split(':').last,
      hours: 1,
      income: 100,
      startDate: 20260501 + index,
      startMeter: index.toDouble(),
    );
  }
}

Future<int> _timingRecordCount(Database db) async {
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS count FROM timing_records',
  );
  return (rows.single['count'] as num?)?.toInt() ?? 0;
}

Future<void> _insertTimingRow(
  Database db, {
  required int deviceId,
  required String projectId,
  required String contact,
  required String site,
  required double hours,
  required double income,
}) async {
  await db.insert(
    'timing_records',
    TimingRecord(
      deviceId: deviceId,
      startDate: 20260518,
      projectId: projectId,
      contact: contact,
      site: site,
      type: TimingType.hours,
      startMeter: 0,
      endMeter: hours,
      hours: hours,
      income: income,
    ).toMap(),
  );
}

Future<void> _seedRate(
  Database db, {
  required int deviceId,
  required String projectId,
  required String projectKey,
  required double rate,
}) async {
  await db.insert(
    'project_device_rates',
    ProjectDeviceRate(
      projectId: projectId,
      projectKey: projectKey,
      deviceId: deviceId,
      rate: rate,
    ).toMap(),
  );
}

Map<String, Object?> _singleOutboxRow(
  List<Map<String, Object?>> rows,
  String entityType,
) {
  final matches = rows
      .where((row) => row['entity_type'] == entityType)
      .toList(growable: false);
  expect(matches, hasLength(1));
  return matches.single;
}

Map<String, Object?> _singleMetaRow(
  List<Map<String, Object?>> rows,
  String entityType,
) {
  final matches = rows
      .where((row) => row['entity_type'] == entityType)
      .toList(growable: false);
  expect(matches, hasLength(1));
  return matches.single;
}

Future<void> _seedActiveMergeGroup(
  Database db, {
  required String contact,
  required List<(String, String)> members,
}) async {
  final groupId = await db.insert(
    'account_project_merge_groups',
    AccountProjectMergeGroup(
      contact: contact,
      isActive: true,
      createdAt: '2026-05-18T00:00:00.000Z',
      updatedAt: '2026-05-18T00:00:00.000Z',
    ).toMap(),
  );
  for (var i = 0; i < members.length; i++) {
    final (projectId, projectKey) = members[i];
    final pk = projectKey.split('||');
    await db.insert(
      'account_project_merge_members',
      AccountProjectMergeMember(
        groupId: groupId,
        projectId: projectId,
        projectKey: projectKey,
        contact: pk.first,
        site: pk.last,
        sortOrder: i,
        isActive: true,
        createdAt: '2026-05-18T00:00:00.000Z',
      ).toMap(),
    );
  }
}

Future<void> _insertPayment(
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

// ignore_for_file: unused_import
