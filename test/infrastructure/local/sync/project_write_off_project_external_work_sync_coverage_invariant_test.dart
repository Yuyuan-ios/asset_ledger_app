import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('project/write-off/external-work sync coverage invariant', () {
    test('known ProjectWriteOff production writes are sync covered', () {
      final enqueuer = _read(
        'lib/infrastructure/local/account/project_write_off_sync_enqueuer.dart',
      );
      final settlement = _read(
        'lib/infrastructure/local/account/local_project_settlement_repository.dart',
      );
      final timingDelete = _read(
        'lib/infrastructure/local/timing/local_delete_timing_record_with_impact_use_case.dart',
      );
      final externalWork = _read(
        'lib/data/repositories/external_work_record_repository.dart',
      );

      _expectAllContains(enqueuer, const [
        'class ProjectWriteOffSyncEnqueuer',
        "static const String entityType = 'project_write_off';",
        'enqueueCreate(',
        'enqueueDelete(',
        // R5.25 payload schema version + actor traceability + updated_by.
        "'payload_schema_version': kSyncPayloadSchemaVersion",
        "'actor': syncActorPayload(resolvedActor)",
        'updatedBy: resolvedActor.actorId',
        "'record': writeOff.toMap()",
        'SyncStatus.pendingUpload',
        'SyncStatus.pendingDelete',
        'payloadHash: entry.payloadHash',
      ]);

      _expectAllContains(settlement, const [
        'Future<ProjectSettlementResult> settle(',
        'Future<ProjectSettlementResult> settleMerged(',
        'Future<DeleteProjectWriteOffResult> deleteWriteOff(',
        'Future<DeleteProjectWriteOffResult> deleteMergedWriteOffs(',
        'ProjectWriteOffSyncEnqueuer projectWriteOffSyncEnqueuer',
        'final ProjectWriteOffSyncEnqueuer _projectWriteOffSyncEnqueuer;',
        '_projectWriteOffRepository.insertWithExecutor(txn, writeOff)',
        '_projectWriteOffSyncEnqueuer.enqueueCreate(',
        '_projectWriteOffSyncEnqueuer.enqueueDelete(',
      ]);
      _expectInOrder(settlement, const [
        'final writeOff = ProjectWriteOff(',
        '_projectWriteOffRepository.insertWithExecutor(txn, writeOff)',
        '_projectWriteOffSyncEnqueuer.enqueueCreate(',
      ]);
      _expectInOrder(settlement, const [
        'final writeOff = await _projectWriteOffRepository.findByIdWithExecutor(',
        'await txn.delete(',
        '_projectWriteOffSyncEnqueuer.enqueueDelete(',
      ]);

      _expectAllContains(timingDelete, const [
        'ProjectWriteOffSyncEnqueuer? projectWriteOffSyncEnqueuer',
        'final ProjectWriteOffSyncEnqueuer _projectWriteOffSyncEnqueuer;',
        'listByProjectIdWithExecutor(',
        'deleteByIdWithExecutor(',
        '_projectWriteOffSyncEnqueuer.enqueueDelete(',
      ]);

      final resetSlice = _sliceBetween(
        externalWork,
        '@override\n  Future<int> linkBatchToProjectWithSettlementReset({',
        '@override\n  Future<int> unlinkBatch({',
      );
      _expectAllContains(resetSlice, const [
        'listByProjectIdWithExecutor(txn, normalizedProjectId)',
        'deleteByIdWithExecutor(',
        '_projectWriteOffSyncEnqueuer.enqueueDelete(',
      ]);
      _expectInOrder(resetSlice, const [
        'final writeOffSnapshots = await _writeOffRepository',
        'deleteByIdWithExecutor(',
        '_projectWriteOffSyncEnqueuer.enqueueDelete(',
      ]);
    });

    test('known project settlement status mutations are sync covered', () {
      final enqueuer = _read(
        'lib/infrastructure/local/account/project_sync_enqueuer.dart',
      );
      final projectRepository = _read(
        'lib/data/repositories/project_repository.dart',
      );
      final settlement = _read(
        'lib/infrastructure/local/account/local_project_settlement_repository.dart',
      );
      final timingDelete = _read(
        'lib/infrastructure/local/timing/local_delete_timing_record_with_impact_use_case.dart',
      );
      final externalWork = _read(
        'lib/data/repositories/external_work_record_repository.dart',
      );

      _expectAllContains(enqueuer, const [
        'class ProjectSyncEnqueuer',
        "static const String entityType = 'project';",
        'enqueueUpdate(',
        // R5.26-A: create/update/delete now share a parameterized `_enqueue`,
        // so the payload carries `'operation': operation` and enqueueUpdate
        // passes operation: 'update' + SyncStatus.pendingUpdate. The settlement
        // status update path remains covered.
        "operation: 'update'",
        "'operation': operation",
        // R5.25 payload schema version + actor traceability + updated_by.
        "'payload_schema_version': kSyncPayloadSchemaVersion",
        "'actor': syncActorPayload(resolvedActor)",
        'updatedBy: resolvedActor.actorId',
        "'record': project.toMap()",
        'SyncStatus.pendingUpdate',
        'payloadHash: entry.payloadHash',
      ]);
      _expectAllContains(projectRepository, const [
        'Future<bool> restoreActiveWithExecutor(',
        'status: ProjectStatus.active',
        'settledAt: null',
        'settledSnapshot: null',
        "'status': project.status.name",
        "'settled_at': project.settledAt",
        "'settled_snapshot': project.settledSnapshot",
      ]);
      _expectAllContains(settlement, const [
        'ProjectSyncEnqueuer projectSyncEnqueuer',
        'final ProjectSyncEnqueuer _projectSyncEnqueuer;',
        'status: ProjectStatus.settled',
        'settledAt: request.createdAtIso',
        'status: ProjectStatus.active',
        'settledAt: null',
        'settledSnapshot: null',
        // R5.25-Hardening: the helper call now spans multiple lines to add
        // `actor:`, so match the call prefix only (the order/arg invariant
        // in project_settlement_status_sync_strategy_invariant_test pins
        // the args).
        '_enqueueProjectUpdate(',
        '_projectSyncEnqueuer.enqueueUpdate(',
      ]);
      _expectAllContains(timingDelete, const [
        'ProjectSyncEnqueuer? projectSyncEnqueuer',
        'restoreActiveWithExecutor(',
        '_enqueueProjectUpdate(',
        '_projectSyncEnqueuer.enqueueUpdate(',
      ]);
      _expectAllContains(externalWork, const [
        'ProjectSyncEnqueuer projectSyncEnqueuer',
        'restoreActiveWithExecutor(',
        '_projectRepository.findByIdWithExecutor(',
        '_projectSyncEnqueuer.enqueueUpdate(',
      ]);
    });

    test('known ExternalWork production writes are sync covered', () {
      final enqueuer = _read(
        'lib/infrastructure/local/timing/external_work_sync_enqueuer.dart',
      );
      final importer = _read(
        'lib/data/share/jztshare/project_external_work_importer.dart',
      );
      final repository = _read(
        'lib/data/repositories/external_work_record_repository.dart',
      );
      final timingDelete = _read(
        'lib/infrastructure/local/timing/local_delete_timing_record_with_impact_use_case.dart',
      );
      final store = _read(
        'lib/features/timing/state/timing_external_work_store.dart',
      );
      final timingPage = _read('lib/features/timing/view/timing_page.dart');

      _expectAllContains(enqueuer, const [
        'class ExternalWorkSyncEnqueuer',
        "static const String entityType = 'external_work_record';",
        'enqueueCreate(',
        'enqueueUpdate(',
        'enqueueDelete(',
        // R5.25 payload schema version + actor traceability + updated_by.
        "'payload_schema_version': kSyncPayloadSchemaVersion",
        "'actor': syncActorPayload(resolvedActor)",
        'updatedBy: resolvedActor.actorId',
        "'record': record.toMap()",
        'payloadHash: entry.payloadHash',
      ]);
      _expectAllContains(importer, const [
        'ExternalWorkSyncEnqueuer syncEnqueuer = const ExternalWorkSyncEnqueuer()',
        'AppDatabase.inTransaction<void>((txn) async {',
        'SqfliteExternalWorkRecordRepository.insertRecordWithExecutor(',
        'await _syncEnqueuer.enqueueCreate(',
      ]);
      _expectAllContains(repository, const [
        'ExternalWorkSyncEnqueuer syncEnqueuer = const ExternalWorkSyncEnqueuer()',
        'await _syncEnqueuer.enqueueDelete(',
        // R5.25-Hardening: call spans multiple lines to add `actor:`; the
        // external_work_sync_strategy_invariant pins the body args.
        'await _enqueueBatchUpdates(',
        'await _syncEnqueuer.enqueueUpdate(',
      ]);
      _expectAllContains(timingDelete, const [
        'ExternalWorkSyncEnqueuer? externalWorkSyncEnqueuer',
        'listByLinkedProjectIdWithExecutor(txn, projectId)',
        'unlinkByProjectIdWithExecutor(',
        '_externalWorkSyncEnqueuer.enqueueUpdate(',
      ]);
      _expectAllContains(store, const [
        '_recordRepository.deleteById(normalized)',
        '_recordRepository.linkBatchToProject(',
        '_recordRepository.linkBatchToProjectWithSettlementReset(',
        '_recordRepository.unlinkBatch(',
        '_recordRepository.deleteByBatchId(normalized)',
      ]);
      _expectAllContains(timingPage, const [
        'store.linkBatchToProject(package.batchId, candidate.projectId)',
        'store.linkSettledBatchToProject(',
        'store.unlinkBatch(package.batchId)',
        'store.deleteByBatchId(batchId)',
      ]);
    });

    test('restore and migrations remain explicit sync exemptions', () {
      final backupTables = _read('lib/data/services/backup/backup_tables.dart');
      final restore = _read(
        'lib/data/services/backup/local_restore_service.dart',
      );
      final migration018 = _read('lib/data/db/migrations/migration_018.dart');
      final migration019 = _read('lib/data/db/migrations/migration_019.dart');
      final projectIdentity = _read(
        'lib/data/db/migrations/project_identity_migration.dart',
      );

      _expectAllContains(backupTables, const [
        'static const List<String> clearOrder',
        "'external_work_records'",
        "'project_write_offs'",
        "'projects'",
        'static const List<String> insertOrder',
      ]);
      _expectAllContains(restore, const [
        'for (final tableName in BackupRestoreTables.clearOrder)',
        'batch.delete(tableName)',
        'for (final tableName in BackupRestoreTables.insertOrder)',
        'batch.insert(',
        'tableName,',
        'row,',
      ]);
      _expectAllContains(migration018, const [
        "if (await _tableExists(db, 'project_write_offs'))",
        'UPDATE project_write_offs',
      ]);
      _expectAllContains(migration019, const [
        'CREATE TABLE external_work_records__v19',
        'INSERT INTO external_work_records__v19',
        'FROM external_work_records',
        'DROP TABLE external_work_records',
      ]);
      _expectAllContains(projectIdentity, const [
        '_ensureProjectStatusColumns',
        'settled_at',
        'settled_snapshot',
        "ProjectStatus.active.name",
      ]);

      for (final path in _restoreAndMigrationExemptionFiles) {
        expect(File(path).existsSync(), isTrue, reason: 'Missing $path');
      }
    });

    test('preview and duplicate checker paths remain read only', () {
      final paths = const {
        'external work import preview use case':
            'lib/features/external_work/import_preview/use_cases/prepare_external_work_import_preview_use_case.dart',
        'external work duplicate checker':
            'lib/data/share/jztshare/project_external_work_duplicate_checker.dart',
        'external work import view model':
            'lib/features/external_work/import_preview/view_model/external_work_import_preview_view_model.dart',
        'save timing operation analyzer':
            'lib/features/timing/operations/save_timing_record_operation_analyzer.dart',
      };

      for (final entry in paths.entries) {
        final source = _read(entry.value);
        expect(
          _projectWriteOffWriteMarkers(source),
          isEmpty,
          reason: '${entry.key} must not write project_write_offs.',
        );
        expect(
          _projectStatusWriteMarkers(source),
          isEmpty,
          reason:
              '${entry.key} must not mutate project settlement status fields.',
        );
        expect(
          _externalWorkWriteMarkers(source),
          isEmpty,
          reason: '${entry.key} must not write external_work_records.',
        );
        expect(
          source,
          isNot(contains('SyncEnqueuer')),
          reason: '${entry.key} must remain preview/analyze/read-only.',
        );
      }
    });

    test('unknown production writes must be registered', () {
      _expectRegisteredWritePaths(
        label: 'project_write_offs',
        actual: _scanLib(_projectWriteOffWriteMarkers),
        registered: _registeredProjectWriteOffWriteFiles,
        suggestion:
            'Route production writes through ProjectWriteOffSyncEnqueuer in '
            'the same transaction, or add a narrow restore/migration/deferred '
            'exemption.',
      );
      _expectRegisteredWritePaths(
        label: 'projects.status/settled_at/settled_snapshot',
        actual: _scanLib(_projectStatusWriteMarkers),
        registered: _registeredProjectStatusWriteFiles,
        suggestion:
            'Route production settlement status mutations through '
            'ProjectSyncEnqueuer in the same transaction, or explicitly '
            'register a non-covered blocker.',
      );
      _expectRegisteredWritePaths(
        label: 'external_work_records',
        actual: _scanLib(_externalWorkWriteMarkers),
        registered: _registeredExternalWorkWriteFiles,
        suggestion:
            'Route production writes through ExternalWorkSyncEnqueuer inside '
            'their transaction, or register restore/migration/deferred paths.',
      );
    });

    test('sync coverage does not mean cloud push is ready', () {
      expect(
        _coverageStrategy
            .projectWriteOffCoverageCompleteForKnownProductionPaths,
        isTrue,
      );
      expect(
        _coverageStrategy.projectStatusCoverageCompleteForKnownSettlementPaths,
        isTrue,
      );
      expect(
        _coverageStrategy.externalWorkCoverageCompleteForKnownProductionPaths,
        isTrue,
      );
      expect(_coverageStrategy.externalWorkResetCovered, isTrue);
      expect(_coverageStrategy.externalWorkImportCovered, isTrue);
      expect(_coverageStrategy.externalWorkLinkUnlinkDeleteCovered, isTrue);
      expect(_coverageStrategy.restoreReconcileRequiredBeforeCloudPush, isTrue);
      expect(
        _coverageStrategy
            .syncManagerOrderingOrTransactionGroupRequiredBeforeCloudPush,
        isTrue,
      );
      expect(
        _coverageStrategy.pendingUploadDeleteFoldingRequiredBeforeCloudPush,
        isTrue,
      );
      expect(
        _coverageStrategy
            .projectFullLifecycleOrBaselineStrategyRequiredBeforeCloudPush,
        isTrue,
      );
      expect(_coverageStrategy.cloudPushReady, isFalse);
    });

    test('direct write detectors recognize common write patterns', () {
      const projectWriteOffWrites = {
        'sqflite delete':
            "await txn.delete('project_write_offs', where: 'id = ?');",
        'raw delete':
            "await db.rawDelete('DELETE FROM project_write_offs WHERE project_id = ?');",
        'repository delete':
            'final SqfliteProjectWriteOffRepository repository; '
            'await repository.deleteByIdWithExecutor(txn, id);',
      };
      for (final entry in projectWriteOffWrites.entries) {
        expect(
          _projectWriteOffWriteMarkers(entry.value),
          isNotEmpty,
          reason: 'ProjectWriteOff detector missed ${entry.key}.',
        );
      }
      expect(
        _projectWriteOffWriteMarkers(
          "await txn.delete('account_payments', where: 'id = ?');",
        ),
        isEmpty,
      );

      const projectStatusWrites = {
        'settled status copy': 'status: ProjectStatus.settled,',
        'restore helper':
            'await repository.restoreActiveWithExecutor(txn, projectId: id, updatedAt: now);',
        'raw project status update':
            "await db.rawUpdate('UPDATE projects SET status = ?');",
      };
      for (final entry in projectStatusWrites.entries) {
        expect(
          _projectStatusWriteMarkers(entry.value),
          isNotEmpty,
          reason: 'Project status detector missed ${entry.key}.',
        );
      }
      expect(
        _projectStatusWriteMarkers(
          'enum ProjectStatus { active, settled, archived, voided }',
        ),
        isEmpty,
      );
      expect(
        _projectStatusWriteMarkers(
          'Project(id: id, status: ProjectStatus.active, createdAt: now, updatedAt: now);',
        ),
        isEmpty,
      );

      const externalWorkWrites = {
        'sqflite update': "await txn.update('external_work_records', data);",
        'raw insert':
            "await db.rawInsert('INSERT INTO external_work_records (id) VALUES (?)');",
        'reset repository call':
            'final ExternalWorkRecordRepository repository; '
            'await repository.linkBatchToProjectWithSettlementReset('
            'importBatchId: batchId, projectId: projectId, updatedAt: now);',
      };
      for (final entry in externalWorkWrites.entries) {
        expect(
          _externalWorkWriteMarkers(entry.value),
          isNotEmpty,
          reason: 'ExternalWork detector missed ${entry.key}.',
        );
      }
      expect(
        _externalWorkWriteMarkers(
          "await executor.query('external_work_records', where: 'id = ?');",
        ),
        isEmpty,
      );
    });
  });
}

const _coverageStrategy = _CoverageStrategy(
  projectWriteOffCoverageCompleteForKnownProductionPaths: true,
  projectStatusCoverageCompleteForKnownSettlementPaths: true,
  externalWorkCoverageCompleteForKnownProductionPaths: true,
  externalWorkResetCovered: true,
  externalWorkImportCovered: true,
  externalWorkLinkUnlinkDeleteCovered: true,
  restoreReconcileRequiredBeforeCloudPush: true,
  syncManagerOrderingOrTransactionGroupRequiredBeforeCloudPush: true,
  pendingUploadDeleteFoldingRequiredBeforeCloudPush: true,
  projectFullLifecycleOrBaselineStrategyRequiredBeforeCloudPush: true,
  cloudPushReady: false,
);

const Map<String, String> _registeredProjectWriteOffWriteFiles = {
  'lib/data/repositories/project_write_off_repository.dart':
      'low-level ProjectWriteOff CRUD repository',
  'lib/infrastructure/local/account/local_project_settlement_repository.dart':
      'covered single and merged settlement create/delete paths',
  'lib/infrastructure/local/timing/local_delete_timing_record_with_impact_use_case.dart':
      'covered timing delete cascade ProjectWriteOff delete path',
  'lib/data/repositories/external_work_record_repository.dart':
      'covered ExternalWork settlement reset ProjectWriteOff delete path',
  'lib/data/db/migrations/migration_018.dart':
      'migration amount_fen backfill exemption',
  'lib/data/db/migrations/migration_030.dart':
      'migration table rebuild exemption',
};

const Map<String, String> _registeredProjectStatusWriteFiles = {
  'lib/data/repositories/project_repository.dart':
      'low-level Project status persistence repository',
  'lib/infrastructure/local/account/local_project_settlement_repository.dart':
      'covered single and merged settlement status paths',
  'lib/infrastructure/local/timing/local_delete_timing_record_with_impact_use_case.dart':
      'covered timing delete cascade Project status restore path',
  'lib/data/repositories/external_work_record_repository.dart':
      'covered ExternalWork settlement reset Project status restore path',
  'lib/infrastructure/local/account/project_settlement_impact_service.dart':
      'deferred timing edit status restore helper; not a Cloud-ready covered path',
  'lib/infrastructure/local/timing/local_save_timing_record_with_impact_use_case.dart':
      'deferred timing edit status restore entry; guardrail keeps blocker explicit',
  'lib/data/db/migrations/project_identity_migration.dart':
      'migration project status backfill exemption',
};

const Map<String, String> _registeredExternalWorkWriteFiles = {
  'lib/data/repositories/external_work_record_repository.dart':
      'low-level ExternalWork CRUD plus covered link/unlink/delete/reset paths',
  'lib/data/share/jztshare/project_external_work_importer.dart':
      'covered row-level import create path',
  'lib/features/external_work/import_preview/use_cases/confirm_external_work_import_use_case.dart':
      'covered import confirm orchestration path',
  'lib/features/timing/state/timing_external_work_store.dart':
      'covered timing store ExternalWork write actions',
  'lib/features/timing/view/timing_page.dart':
      'covered timing page ExternalWork write actions',
  'lib/infrastructure/local/timing/local_delete_timing_record_with_impact_use_case.dart':
      'covered timing delete cascade ExternalWork unlink path',
  'lib/data/db/migrations/migration_019.dart':
      'migration table rebuild exemption',
};

const Set<String> _restoreAndMigrationExemptionFiles = {
  'lib/data/services/backup/backup_tables.dart',
  'lib/data/services/backup/local_restore_service.dart',
  'lib/data/db/migrations/migration_018.dart',
  'lib/data/db/migrations/migration_019.dart',
  'lib/data/db/migrations/project_identity_migration.dart',
};

Map<String, List<String>> _scanLib(List<String> Function(String) detector) {
  final actual = <String, List<String>>{};
  for (final file in _libDartFiles()) {
    final markers = detector(file.readAsStringSync());
    if (markers.isNotEmpty) {
      actual[_relativePath(file)] = markers;
    }
  }
  return actual;
}

List<String> _projectWriteOffWriteMarkers(String source) {
  final normalized = _normalizeWriteSource(source);
  final markers = <String>{};

  for (final pattern in _directProjectWriteOffTableWritePatterns.entries) {
    if (pattern.value.hasMatch(normalized)) {
      markers.add(pattern.key);
    }
  }
  if (normalized.contains('project_write_offs') &&
      _tableVariableCrudPattern.hasMatch(normalized)) {
    markers.add('sqflite project_write_offs table variable CRUD call');
  }

  for (final repositoryName in _repositoryVariableNames(
    source,
    typedNames: const [
      'ProjectWriteOffRepository',
      'SqfliteProjectWriteOffRepository',
    ],
    constructedName: 'SqfliteProjectWriteOffRepository',
  )) {
    final escapedName = RegExp.escape(repositoryName);
    final pattern = RegExp(
      '$escapedName\\s*\\.\\s*'
      '(insertWithExecutor|deleteByIdWithExecutor|'
      'deleteByProjectIdWithExecutor|deleteByIdsWithExecutor|'
      'insert|update|deleteById|deleteByProjectId)\\s*\\(',
    );
    if (pattern.hasMatch(source)) {
      markers.add('ProjectWriteOffRepository direct write call');
    }
  }

  return markers.toList()..sort();
}

List<String> _projectStatusWriteMarkers(String source) {
  final normalized = _normalizeWriteSource(source);
  final markers = <String>{};

  if (source.contains('restoreActiveWithExecutor(')) {
    markers.add('restoreActiveWithExecutor');
  }
  if (source.contains('applyRevocations(') &&
      source.contains('ProjectSettlementImpactReason.')) {
    markers.add('ProjectSettlementImpactService.applyRevocations');
  }
  if (RegExp(r'status\s*:\s*ProjectStatus\.settled').hasMatch(source)) {
    markers.add('ProjectStatus.settled mutation');
  }
  if (RegExp(
    r'status\s*:\s*ProjectStatus\.active[\s\S]{0,280}'
    r'(settledAt\s*:\s*null|settledSnapshot\s*:\s*null)',
  ).hasMatch(source)) {
    markers.add('ProjectStatus.active settlement restore');
  }
  if (RegExp(
    r"""['"]status['"]\s*:\s*project\.status\.name""",
  ).hasMatch(source)) {
    markers.add('project repository status map write');
  }
  if (RegExp(
    r'\.\s*update\s*\(\s*(sqfliteprojectrepository\.table|projects)\b'
    r'[\s\S]{0,420}(status|settled_at|settled_snapshot)',
  ).hasMatch(normalized)) {
    markers.add('projects table status update');
  }
  if (RegExp(
    r'(rawupdate|execute)\s*\(\s*(?:r)?\s*update\s+projects\b'
    r'[\s\S]{0,420}(status|settled_at|settled_snapshot)',
  ).hasMatch(normalized)) {
    markers.add('raw projects status SQL update');
  }

  return markers.toList()..sort();
}

List<String> _externalWorkWriteMarkers(String source) {
  final normalized = _normalizeWriteSource(source);
  final markers = <String>{};

  for (final pattern in _directExternalWorkTableWritePatterns.entries) {
    if (pattern.value.hasMatch(normalized)) {
      markers.add(pattern.key);
    }
  }
  if (normalized.contains('external_work_records') &&
      _tableVariableCrudPattern.hasMatch(normalized)) {
    markers.add('sqflite external_work_records table variable CRUD call');
  }

  for (final repositoryName in _repositoryVariableNames(
    source,
    typedNames: const [
      'ExternalWorkRecordRepository',
      'SqfliteExternalWorkRecordRepository',
    ],
    constructedName: 'SqfliteExternalWorkRecordRepository',
  )) {
    final escapedName = RegExp.escape(repositoryName);
    final pattern = RegExp(
      '$escapedName\\s*\\.\\s*'
      '(insertRecord|insertRecords|insertRecordWithExecutor|'
      'insertRecordsWithExecutor|linkBatchToProject|'
      'linkBatchToProjectWithSettlementReset|unlinkBatch|'
      'unlinkByProjectIdWithExecutor|deleteById|deleteByBatchId|'
      'deleteByIdWithExecutor|deleteByBatchIdWithExecutor|'
      'updateLocalFields|updateWithExecutor)\\s*\\(',
    );
    if (pattern.hasMatch(source)) {
      markers.add('ExternalWorkRecordRepository direct write call');
    }
  }

  for (final storeName in _timingExternalWorkStoreVariableNames(source)) {
    final escapedName = RegExp.escape(storeName);
    final pattern = RegExp(
      '$escapedName\\s*\\.\\s*'
      '(deleteById|deleteByBatchId|linkBatchToProject|'
      'linkSettledBatchToProject|unlinkBatch)\\s*\\(',
    );
    if (pattern.hasMatch(source)) {
      markers.add('TimingExternalWorkStore write action call');
    }
  }

  for (final importerName in _externalWorkImporterVariableNames(source)) {
    final escapedName = RegExp.escape(importerName);
    if (RegExp('$escapedName\\s*\\.\\s*importParsed\\s*\\(').hasMatch(source)) {
      markers.add('ProjectExternalWorkImporter import write call');
    }
  }

  if (source.contains(
    'SqfliteExternalWorkRecordRepository'
    '.insertRecordWithExecutor(',
  )) {
    markers.add('ExternalWorkRecordRepository executor insert call');
  }
  if (source.contains('.unlinkByProjectIdWithExecutor(') &&
      source.contains('SqfliteExternalWorkRecordRepository')) {
    markers.add('ExternalWorkRecordRepository executor unlink call');
  }

  return markers.toList()..sort();
}

final Map<String, RegExp> _directProjectWriteOffTableWritePatterns = {
  'sqflite project_write_offs table CRUD call': RegExp(
    r'\.\s*(insert|update|delete)\s*\(\s*'
    r'(project_write_offs|sqfliteprojectwriteoffrepository\.table)\b',
  ),
  'raw SQL project_write_offs write': RegExp(
    r'\b(rawinsert|rawupdate|rawdelete|execute)\s*\(\s*(?:r)?\s*'
    r'(insert\s+into|update|delete\s+from)\s+project_write_offs(?:\b|_)',
  ),
};

final Map<String, RegExp> _directExternalWorkTableWritePatterns = {
  'sqflite external_work_records table CRUD call': RegExp(
    r'\.\s*(insert|update|delete)\s*\(\s*'
    r'(external_work_records|sqfliteexternalworkrecordrepository\.table)\b',
  ),
  'raw SQL external_work_records write': RegExp(
    r'\b(rawinsert|rawupdate|rawdelete|execute)\s*\(\s*(?:r)?\s*'
    r'(insert\s+into|update|delete\s+from)\s+external_work_records(?:\b|_)',
  ),
};

final RegExp _tableVariableCrudPattern = RegExp(
  r'\.\s*(insert|update|delete)\s*\(\s*_?table\b',
);

Set<String> _repositoryVariableNames(
  String source, {
  required List<String> typedNames,
  required String constructedName,
}) {
  final names = <String>{};
  final typeAlternation = typedNames.map(RegExp.escape).join('|');
  final typedPattern = RegExp('\\b(?:$typeAlternation)\\??\\s+([A-Za-z_]\\w*)');
  final constructedPattern = RegExp(
    '\\b(?:final\\s+|var\\s+|static\\s+const\\s+|const\\s+)?'
    '([A-Za-z_]\\w*)\\s*=\\s*$constructedName\\s*\\(',
  );

  for (final match in typedPattern.allMatches(source)) {
    names.add(match.group(1)!);
  }
  for (final match in constructedPattern.allMatches(source)) {
    names.add(match.group(1)!);
  }
  return names;
}

Set<String> _timingExternalWorkStoreVariableNames(String source) {
  final names = <String>{};
  final typedStorePattern = RegExp(
    '\\bTimingExternalWorkStore\\??\\s+([A-Za-z_]\\w*)',
  );
  final readStorePattern = RegExp(
    '\\b(?:final\\s+)?([A-Za-z_]\\w*)\\s*=\\s*'
    r'(?:context\.(?:read|watch)<TimingExternalWorkStore\??>\(\)|'
    r'_readStore\(\))',
  );

  for (final match in typedStorePattern.allMatches(source)) {
    names.add(match.group(1)!);
  }
  for (final match in readStorePattern.allMatches(source)) {
    names.add(match.group(1)!);
  }
  return names;
}

Set<String> _externalWorkImporterVariableNames(String source) {
  final names = <String>{};
  final typedImporterPattern = RegExp(
    '\\bProjectExternalWorkImporter\\??\\s+([A-Za-z_]\\w*)',
  );
  final constructedImporterPattern = RegExp(
    '\\b(?:final\\s+|var\\s+)?([A-Za-z_]\\w*)\\s*=\\s*'
    'ProjectExternalWorkImporter\\s*\\(',
  );

  for (final match in typedImporterPattern.allMatches(source)) {
    names.add(match.group(1)!);
  }
  for (final match in constructedImporterPattern.allMatches(source)) {
    names.add(match.group(1)!);
  }
  return names;
}

String _read(String path) {
  return File('${Directory.current.path}/$path').readAsStringSync();
}

List<File> _libDartFiles() {
  return Directory('${Directory.current.path}/lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

String _relativePath(File file) {
  final root = '${Directory.current.path}/';
  return file.path.startsWith(root)
      ? file.path.substring(root.length)
      : file.path;
}

String _normalizeWriteSource(String source) {
  return source
      .toLowerCase()
      .replaceAll('"', '')
      .replaceAll("'", '')
      .replaceAll('`', '');
}

void _expectRegisteredWritePaths({
  required String label,
  required Map<String, List<String>> actual,
  required Map<String, String> registered,
  required String suggestion,
}) {
  final expected = registered.keys.toSet();
  final actualPaths = actual.keys.toSet();

  expect(
    actualPaths.difference(expected),
    isEmpty,
    reason:
        'Unregistered $label production write path(s) detected.\n'
        '${_describeUnexpected(actual, expected)}\n\n$suggestion',
  );
  expect(
    expected.difference(actualPaths),
    isEmpty,
    reason:
        'Registered $label write/exemption path(s) no longer contain write '
        'markers. Remove stale entries only after keeping coverage/deferred '
        'classification explicit.\n'
        '${_describeMissing(actualPaths, registered)}',
  );
}

String _describeUnexpected(
  Map<String, List<String>> actual,
  Set<String> expected,
) {
  final unexpected = actual.keys.toSet().difference(expected).toList()..sort();
  if (unexpected.isEmpty) return 'No unexpected paths.';
  return unexpected
      .map((path) => '- $path: ${actual[path]!.join(', ')}')
      .join('\n');
}

String _describeMissing(
  Set<String> actualPaths,
  Map<String, String> registered,
) {
  final missing = registered.keys.toSet().difference(actualPaths).toList()
    ..sort();
  if (missing.isEmpty) return 'No stale registrations.';
  return missing.map((path) => '- $path: ${registered[path]}').join('\n');
}

void _expectAllContains(String source, Iterable<String> snippets) {
  for (final snippet in snippets) {
    expect(
      source,
      contains(snippet),
      reason: 'Missing source marker: $snippet',
    );
  }
}

void _expectInOrder(String source, Iterable<String> snippets) {
  var cursor = -1;
  for (final snippet in snippets) {
    final index = source.indexOf(snippet, cursor + 1);
    expect(index, isNot(-1), reason: 'Missing ordered marker: $snippet');
    expect(
      index,
      greaterThan(cursor),
      reason: 'Source marker is out of order: $snippet',
    );
    cursor = index;
  }
}

String _sliceBetween(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  expect(start, isNot(-1), reason: 'Missing slice start: $startMarker');
  final end = source.indexOf(endMarker, start + startMarker.length);
  expect(end, isNot(-1), reason: 'Missing slice end: $endMarker');
  return source.substring(start, end);
}

class _CoverageStrategy {
  const _CoverageStrategy({
    required this.projectWriteOffCoverageCompleteForKnownProductionPaths,
    required this.projectStatusCoverageCompleteForKnownSettlementPaths,
    required this.externalWorkCoverageCompleteForKnownProductionPaths,
    required this.externalWorkResetCovered,
    required this.externalWorkImportCovered,
    required this.externalWorkLinkUnlinkDeleteCovered,
    required this.restoreReconcileRequiredBeforeCloudPush,
    required this.syncManagerOrderingOrTransactionGroupRequiredBeforeCloudPush,
    required this.pendingUploadDeleteFoldingRequiredBeforeCloudPush,
    required this.projectFullLifecycleOrBaselineStrategyRequiredBeforeCloudPush,
    required this.cloudPushReady,
  });

  final bool projectWriteOffCoverageCompleteForKnownProductionPaths;
  final bool projectStatusCoverageCompleteForKnownSettlementPaths;
  final bool externalWorkCoverageCompleteForKnownProductionPaths;
  final bool externalWorkResetCovered;
  final bool externalWorkImportCovered;
  final bool externalWorkLinkUnlinkDeleteCovered;
  final bool restoreReconcileRequiredBeforeCloudPush;
  final bool syncManagerOrderingOrTransactionGroupRequiredBeforeCloudPush;
  final bool pendingUploadDeleteFoldingRequiredBeforeCloudPush;
  final bool projectFullLifecycleOrBaselineStrategyRequiredBeforeCloudPush;
  final bool cloudPushReady;
}
