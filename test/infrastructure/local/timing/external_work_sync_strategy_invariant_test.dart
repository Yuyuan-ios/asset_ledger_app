import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('external work sync strategy invariant', () {
    test('external work model supports row level sync with reset still deferred', () {
      final model = _read('lib/data/models/external_work_record.dart');
      final schema = _read('lib/data/db/schema/external_work_schema.dart');
      final repository = _read(
        'lib/data/repositories/external_work_record_repository.dart',
      );
      final syncEnqueuer = _read(
        'lib/infrastructure/local/timing/external_work_sync_enqueuer.dart',
      );
      final timingDelete = _read(
        'lib/infrastructure/local/timing/local_delete_timing_record_with_impact_use_case.dart',
      );
      final productionSourceOutsideCoveredSyncPaths = _libDartFiles()
          .where(
            (file) => !_externalWorkSyncEnqueuerAllowedFiles.contains(
              _relativePath(file),
            ),
          )
          .map((file) => _read(_relativePath(file)))
          .join('\n');

      _expectAllContains(model, const [
        'class ExternalWorkRecord',
        'enum ExternalWorkRecordStatus { active, ignored, archived, voided }',
        'enum ExternalWorkRecordKind { hours, rent }',
        'ExternalWorkRecord copyWith({',
        'Map<String, Object?> toMap()',
        'Map<String, Object?> toUncheckedMap()',
        'static ExternalWorkRecord fromMap(Map<String, Object?> map)',
        "'id': id",
        "'import_batch_id': importBatchId",
        "'source_share_id': sourceShareId",
        "'source_record_uuid': sourceRecordUuid",
        "'source_installation_uuid': sourceInstallationUuid",
        "'origin_fingerprint': originFingerprint",
        "'work_date': workDate",
        "'hours_milli': hoursMilli",
        "'amount_fen': amountFen",
        "'project_received_fen': projectReceivedFen",
        "'linked_project_id': linkedProjectId",
        "'record_kind': recordKind.name",
        "'status': status.name",
        "'created_at': createdAt",
        "'updated_at': updatedAt",
        "id: reader.requiredString('id')",
        "linkedProjectId: reader.optionalString('linked_project_id')",
        'recordKind: externalWorkRecordKindFromName',
        'status: parseExternalStatus<ExternalWorkRecordStatus>',
      ]);
      _expectAllContains(schema, const [
        'CREATE TABLE IF NOT EXISTS external_work_records',
        'id TEXT PRIMARY KEY',
        'import_batch_id TEXT NOT NULL',
        'source_share_id TEXT NOT NULL',
        'source_record_uuid TEXT NOT NULL',
        'source_installation_uuid TEXT NOT NULL',
        'origin_fingerprint TEXT NOT NULL',
        'work_date INTEGER NOT NULL',
        'hours_milli INTEGER NOT NULL CHECK (hours_milli >= 0)',
        'amount_fen INTEGER NOT NULL CHECK (amount_fen >= 0)',
        'project_received_fen INTEGER NOT NULL DEFAULT 0',
        'linked_project_id TEXT',
        "record_kind TEXT NOT NULL DEFAULT 'hours'",
        "status TEXT NOT NULL DEFAULT 'active'",
        'created_at TEXT NOT NULL',
        'updated_at TEXT NOT NULL',
        'REFERENCES external_import_batches(id) ON DELETE RESTRICT',
        'REFERENCES projects(id) ON DELETE RESTRICT',
      ]);
      _expectAllContains(repository, const [
        "static const String table = 'external_work_records';",
        'ExternalWorkSyncEnqueuer syncEnqueuer = const ExternalWorkSyncEnqueuer()',
        'final ExternalWorkSyncEnqueuer _syncEnqueuer;',
        'ExternalWorkRecord.fromMap',
        'record.toMap()',
        'await _syncEnqueuer.enqueueDelete(txn, record: snapshot);',
        'await _enqueueBatchUpdates(txn, batchId: normalizedBatchId);',
        'await _syncEnqueuer.enqueueUpdate(executor, record: snapshot);',
      ]);
      _expectAllContains(syncEnqueuer, const [
        'class ExternalWorkSyncEnqueuer',
        "static const String entityType = 'external_work_record';",
        'enqueueCreate(',
        'enqueueUpdate(',
        'enqueueDelete(',
      ]);
      _expectAllContains(timingDelete, const [
        'ExternalWorkSyncEnqueuer? externalWorkSyncEnqueuer',
        'final ExternalWorkSyncEnqueuer _externalWorkSyncEnqueuer;',
        'listByLinkedProjectIdWithExecutor(txn, projectId)',
        'unlinkByProjectIdWithExecutor(',
        'await _externalWorkSyncEnqueuer.enqueueUpdate(',
      ]);

      expect(
        productionSourceOutsideCoveredSyncPaths,
        isNot(contains('ExternalWorkSyncEnqueuer(')),
        reason:
            'ExternalWorkSyncEnqueuer usage must stay in registered covered '
            'production paths. New ordinary production writes should use the '
            'repository/use-case transaction boundary, and new cross-aggregate '
            'paths must be explicitly classified before wiring sync.',
      );
    });

    test(
      'external work future strategy keeps reset as the remaining blocker',
      () {
        expect(
          _externalWorkSyncStrategy.externalWorkEntityType,
          'external_work_record',
        );
        expect(_externalWorkSyncStrategy.linkAndUnlinkAreUpdates, isTrue);
        expect(_externalWorkSyncStrategy.bulkImportUsesRowLevelCreates, isTrue);
        expect(
          _externalWorkSyncStrategy
              .resetRequiresExternalWorkUpdateProjectWriteOffDeleteAndProjectUpdate,
          isTrue,
        );
        expect(
          _externalWorkSyncStrategy.externalWorkResetIsCloudPushBlocker,
          isTrue,
        );
        expect(_externalWorkSyncStrategy.externalWorkHelperImplemented, isTrue);
        expect(
          _externalWorkSyncStrategy.externalWorkImportOutboxCovered,
          isTrue,
        );
        expect(
          _externalWorkSyncStrategy.externalWorkOrdinaryLinkOutboxCovered,
          isTrue,
        );
        expect(
          _externalWorkSyncStrategy.externalWorkOrdinaryUnlinkOutboxCovered,
          isTrue,
        );
        expect(
          _externalWorkSyncStrategy.externalWorkDeleteOutboxCovered,
          isTrue,
        );
        expect(
          _externalWorkSyncStrategy
              .timingDeleteCascadeExternalWorkUnlinkCovered,
          isTrue,
        );
        expect(
          _externalWorkSyncStrategy.externalWorkAllProductionOutboxCovered,
          isFalse,
        );
        expect(_externalWorkSyncStrategy.externalWorkResetCovered, isFalse);
        expect(
          _externalWorkSyncStrategy.restoreRequiresReconcileBeforePush,
          isTrue,
        );
        expect(
          _externalWorkSyncStrategy
              .requiresOrderingOrTransactionGroupBeforeCloudPush,
          isTrue,
        );
        expect(
          _externalWorkSyncStrategy.singleProjectSettlementCovered,
          isTrue,
        );
        expect(_externalWorkSyncStrategy.mergedSettlementCovered, isTrue);
        expect(
          _externalWorkSyncStrategy.timingDeleteSettlementCascadeCovered,
          isTrue,
        );
      },
    );

    test(
      'external work production writes are registered as covered or deferred',
      () {
        final actual = <String, List<String>>{};
        for (final file in _libDartFiles()) {
          final relativePath = _relativePath(file);
          final markers = _externalWorkWriteMarkers(file.readAsStringSync());
          if (markers.isNotEmpty) {
            actual[relativePath] = markers;
          }
        }

        final expected = _registeredExternalWorkWriteFiles.keys.toSet();
        final actualPaths = actual.keys.toSet();

        expect(
          actualPaths.difference(expected),
          isEmpty,
          reason:
              'Unregistered external_work_records production write path(s) must '
              'be explicitly classified. Route new production writes through '
              'ExternalWorkSyncEnqueuer inside their transaction, or register '
              'restore/migration/deferred paths here with a narrow '
              'exemption.\n${_describeUnexpected(actual, expected)}',
        );
        expect(
          expected.difference(actualPaths),
          isEmpty,
          reason:
              'Registered external_work_records write/exemption path(s) no '
              'longer contain write markers. Remove stale entries only after '
              'checking the deferred sync boundary remains explicit.\n'
              '${_describeMissing(actualPaths, expected)}',
        );
      },
    );

    test('external work direct write detector recognizes common write shapes', () {
      const writeExamples = {
        'executor insert literal':
            "await executor.insert('external_work_records', data);",
        'db update uppercase literal':
            'await db.update("EXTERNAL_WORK_RECORDS", data);',
        'database delete quoted literal':
            "await database.delete('\"external_work_records\"', "
            "where: 'id = ?');",
        'client insert repository table':
            'await client.insert(SqfliteExternalWorkRecordRepository.table, row);',
        'table const write':
            "const table = 'external_work_records'; "
            'await executor.update(table, values);',
        'raw insert lowercase':
            "await db.rawInsert('insert into external_work_records (id) values (?)');",
        'raw update uppercase':
            "await db.rawUpdate('UPDATE EXTERNAL_WORK_RECORDS SET status = ?');",
        'raw delete mixed case':
            "await db.rawDelete('Delete From \"external_work_records\" WHERE id = ?');",
        'execute raw insert':
            "await db.execute('INSERT INTO external_work_records (id) VALUES (1)');",
        'repository insert with executor':
            'await SqfliteExternalWorkRecordRepository.insertRecordWithExecutor(txn, record);',
        'repository direct link':
            'final ExternalWorkRecordRepository repository; '
            'await repository.linkBatchToProject(importBatchId: id, '
            'projectId: projectId, updatedAt: now);',
        'store delete':
            'final TimingExternalWorkStore store; await store.deleteByBatchId(id);',
        'import confirm':
            'final ProjectExternalWorkImporter importer; '
            'await importer.importParsed(parsed);',
      };

      for (final entry in writeExamples.entries) {
        expect(
          _externalWorkWriteMarkers(entry.value),
          isNotEmpty,
          reason: 'Detector missed ${entry.key}: ${entry.value}',
        );
      }

      const nonWrites = [
        "await executor.insert('account_payments', data);",
        "await db.rawInsert('INSERT INTO timing_records (id) VALUES (1)');",
        'final ExternalWorkRecordRepository repository; '
            'await repository.listByBatchId(batchId);',
        'final SqfliteExternalWorkRecordRepository repository; '
            'await repository.countLinkedBatchesByProjectId(projectId);',
        'await executor.query("external_work_records", where: "id = ?");',
        'final ProjectExternalWorkImporter importer; '
            'await importer.buildPreview(parsed);',
      ];

      for (final source in nonWrites) {
        expect(
          _externalWorkWriteMarkers(source),
          isEmpty,
          reason:
              'Detector should ignore non external_work_records writes: '
              '$source',
        );
      }
    });

    test(
      'external work settlement reset remains an explicit cross aggregate blocker',
      () {
        final repository = _read(
          'lib/data/repositories/external_work_record_repository.dart',
        );
        final statusInvariant = _read(
          'test/infrastructure/local/account/project_settlement_status_sync_strategy_invariant_test.dart',
        );
        final resetSlice = _sliceBetween(
          repository,
          '@override\n  Future<int> linkBatchToProjectWithSettlementReset({',
          '@override\n  Future<int> unlinkBatch({',
        );

        _expectAllContains(resetSlice, const [
          'AppDatabase.inTransaction<int>((txn) async {',
          'linkBatchToProjectWithExecutor(',
          'SqfliteProjectWriteOffRepository.table',
          "where: 'project_id = ?'",
          'SqfliteProjectRepository.table',
          'Project.fromMap(projectRows.single)',
          'project.status == ProjectStatus.settled',
          'SqfliteProjectRepository.upsertWithExecutor(',
          'status: ProjectStatus.active',
          'settledAt: null',
          'settledSnapshot: null',
        ]);
        _expectInOrder(resetSlice, const [
          'linkBatchToProjectWithExecutor(',
          'SqfliteProjectWriteOffRepository.table',
          'Project.fromMap(projectRows.single)',
          'ProjectStatus.active',
          'return linked;',
        ]);
        expect(
          resetSlice,
          isNot(contains('ExternalWorkSyncEnqueuer')),
          reason:
              'Settlement reset ExternalWork body update is still deferred.',
        );
        expect(
          resetSlice,
          isNot(contains('ProjectWriteOffSyncEnqueuer')),
          reason:
              'Reset deletes write-offs today, but this repository path has no sync enqueuer yet.',
        );
        expect(
          resetSlice,
          isNot(contains('ProjectSyncEnqueuer')),
          reason:
              'Reset restores project status today, but Cloud push ordering is deferred.',
        );

        _expectAllContains(statusInvariant, const [
          'externalWorkSettlementResetIsDeferred: true',
          'mustCoverExternalWorkSettlementReset: true',
          'external work settlement reset deferred coverage path',
        ]);
      },
    );

    test(
      'external work import preview stays read only and confirm create is covered',
      () {
        final prepareUseCase = _read(
          'lib/features/external_work/import_preview/use_cases/prepare_external_work_import_preview_use_case.dart',
        );
        final duplicateChecker = _read(
          'lib/data/share/jztshare/project_external_work_duplicate_checker.dart',
        );
        final importer = _read(
          'lib/data/share/jztshare/project_external_work_importer.dart',
        );
        final confirmUseCase = _read(
          'lib/features/external_work/import_preview/use_cases/confirm_external_work_import_use_case.dart',
        );
        final viewModel = _read(
          'lib/features/external_work/import_preview/view_model/external_work_import_preview_view_model.dart',
        );

        _expectAllContains(prepareUseCase, const [
          'parseProjectExternalWorkShare',
          '_importer.buildPreview(parsed)',
        ]);
        expect(
          _externalWorkWriteMarkers(prepareUseCase),
          isEmpty,
          reason:
              'PrepareExternalWorkImportPreviewUseCase must parse and preview only.',
        );

        _expectAllContains(duplicateChecker, const [
          'Future<ExternalWorkImportPreview> buildPreview(',
          'Future<ExternalWorkImportPreview> buildPreviewWithExecutor(',
          'executor.query(',
          "'external_work_records'",
        ]);
        expect(
          _externalWorkWriteMarkers(duplicateChecker),
          isEmpty,
          reason:
              'Duplicate preview may query external_work_records but not write.',
        );

        _expectAllContains(importer, const [
          'ExternalWorkSyncEnqueuer syncEnqueuer = const ExternalWorkSyncEnqueuer()',
          'final ExternalWorkSyncEnqueuer _syncEnqueuer;',
          'Future<ProjectExternalWorkImportResult> importParsed(',
          'AppDatabase.inTransaction<void>((txn) async {',
          'SqfliteExternalImportRepository.insertBatchWithExecutor(',
          'SqfliteExternalWorkRecordRepository.insertRecordWithExecutor(',
          'await _syncEnqueuer.enqueueCreate(txn, record: record);',
        ]);
        _expectAllContains(confirmUseCase, const [
          'class ConfirmExternalWorkImportUseCase',
          '_importer.importParsed(session.parsed)',
        ]);
        _expectAllContains(viewModel, const [
          'Future<void> prepare(String content) async',
          'Future<void> confirmImport() async',
          '_preparePreview.execute(content)',
          '_confirmImport.execute(session)',
        ]);
      },
    );

    test(
      'restore and migration external work writes remain explicit exemptions',
      () {
        final backupTables = _read(
          'lib/data/services/backup/backup_tables.dart',
        );
        final restore = _read(
          'lib/data/services/backup/local_restore_service.dart',
        );
        final validator = _read(
          'lib/data/services/backup/backup_validator.dart',
        );
        final migration019 = _read('lib/data/db/migrations/migration_019.dart');
        final migration020 = _read('lib/data/db/migrations/migration_020.dart');
        final migration021 = _read('lib/data/db/migrations/migration_021.dart');

        _expectAllContains(backupTables, const [
          "'external_work_records'",
          "'external_import_batches'",
          'static const List<String> clearOrder',
          'static const List<String> insertOrder',
        ]);
        _expectInOrder(backupTables, const [
          'static const List<String> clearOrder',
          "'external_work_records'",
          "'external_import_batches'",
          'static const List<String> insertOrder',
          "'external_import_batches'",
          "'external_work_records'",
        ]);
        _expectAllContains(restore, const [
          'for (final tableName in BackupRestoreTables.clearOrder)',
          'batch.delete(tableName)',
          'for (final tableName in BackupRestoreTables.insertOrder)',
          'batch.insert(',
          'tableName,',
          'row,',
        ]);
        _expectAllContains(validator, const [
          'external_work_records.linked_project_id',
          '_detachOrphanExternalWorkLinks',
        ]);
        _expectAllContains(migration019, const [
          'CREATE TABLE external_work_records__v19',
          'INSERT INTO external_work_records__v19',
          'FROM external_work_records',
          'DROP TABLE external_work_records',
          'RENAME TO external_work_records',
        ]);
        _expectAllContains(migration020, const [
          'ALTER TABLE external_work_records',
          'ADD COLUMN project_received_fen',
        ]);
        _expectAllContains(migration021, const [
          'external_work_records',
          'FK',
          'onUpgrade',
        ]);

        for (final path in _deferredRestoreAndMigrationExemptions) {
          expect(
            File(path).existsSync(),
            isTrue,
            reason: 'Missing deferred ExternalWork exemption file: $path',
          );
        }
      },
    );

    test(
      'external work reset still requires ordering or transaction group before cloud push',
      () {
        final syncSchema = _read('lib/data/db/schema/sync_schema.dart');
        final syncRepositories = _read(
          'lib/infrastructure/sync/sync_repositories.dart',
        );
        final syncManager = _read('lib/infrastructure/sync/sync_manager.dart');

        _expectAllContains(syncSchema, const [
          'CREATE TABLE IF NOT EXISTS sync_outbox',
          'entity_type TEXT NOT NULL',
          'entity_id TEXT NOT NULL',
          'operation TEXT NOT NULL',
          'payload_json TEXT NOT NULL',
          'payload_hash TEXT NOT NULL',
          'created_at TEXT NOT NULL',
        ]);
        expect(syncSchema, isNot(contains('transaction_id')));
        expect(syncSchema, isNot(contains('local_sequence')));

        _expectAllContains(syncRepositories, const [
          'Future<List<SyncOutboxEntry>> listPending({int limit = 50})',
          "orderBy: 'created_at ASC'",
        ]);
        _expectAllContains(syncManager, const [
          'Future<int> pushPending({int limit = 50}) async',
          'final pending = await _outboxRepository.listPending(limit: limit)',
          'for (final entry in pending)',
          "path: '/sync/outbox'",
        ]);
        expect(
          syncManager,
          isNot(contains('transaction_id')),
          reason:
              'ExternalWork reset spans ExternalWork, ProjectWriteOff, and Project. '
              'Cloud push needs explicit ordering/grouping before this blocker '
              'can be considered covered.',
        );
      },
    );
  });
}

const _externalWorkSyncStrategy = _ExternalWorkSyncStrategy(
  externalWorkEntityType: 'external_work_record',
  linkAndUnlinkAreUpdates: true,
  bulkImportUsesRowLevelCreates: true,
  resetRequiresExternalWorkUpdateProjectWriteOffDeleteAndProjectUpdate: true,
  externalWorkResetIsCloudPushBlocker: true,
  externalWorkHelperImplemented: true,
  externalWorkImportOutboxCovered: true,
  externalWorkOrdinaryLinkOutboxCovered: true,
  externalWorkOrdinaryUnlinkOutboxCovered: true,
  externalWorkDeleteOutboxCovered: true,
  timingDeleteCascadeExternalWorkUnlinkCovered: true,
  externalWorkAllProductionOutboxCovered: false,
  externalWorkResetCovered: false,
  restoreRequiresReconcileBeforePush: true,
  requiresOrderingOrTransactionGroupBeforeCloudPush: true,
  singleProjectSettlementCovered: true,
  mergedSettlementCovered: true,
  timingDeleteSettlementCascadeCovered: true,
);

const Set<String> _externalWorkSyncEnqueuerAllowedFiles = {
  'lib/infrastructure/local/timing/external_work_sync_enqueuer.dart',
  'lib/data/share/jztshare/project_external_work_importer.dart',
  'lib/data/repositories/external_work_record_repository.dart',
  'lib/infrastructure/local/timing/local_delete_timing_record_with_impact_use_case.dart',
};

const Map<String, String> _registeredExternalWorkWriteFiles = {
  // Low-level ExternalWork persistence plus sync-covered public ordinary
  // link/unlink/delete methods. Executor writes remain infrastructure-only and
  // are not considered covered production entry points by themselves.
  'lib/data/repositories/external_work_record_repository.dart':
      'low-level ExternalWork CRUD, covered ordinary writes, and reset path',

  // Import confirm performs row-level ExternalWork creates inside one local
  // transaction and is covered by ExternalWorkSyncEnqueuer create outbox/meta.
  'lib/data/share/jztshare/project_external_work_importer.dart':
      'sync-covered bulk import create path',
  'lib/features/external_work/import_preview/use_cases/confirm_external_work_import_use_case.dart':
      'sync-covered import confirm entry',

  // Production store/view actions mutate ordinary ExternalWork link, unlink,
  // and delete through sync-covered repository methods. The settled reset
  // branch remains a Cloud-push blocker until ordering/grouping is designed.
  'lib/features/timing/state/timing_external_work_store.dart':
      'covered ordinary store writes plus deferred reset entry',
  'lib/features/timing/view/timing_page.dart':
      'covered ordinary view actions plus deferred reset entry',

  // Timing delete sync-covers TimingRecord, ProjectWriteOff, Project, and
  // ExternalWork unlink side effects in one transaction.
  'lib/infrastructure/local/timing/local_delete_timing_record_with_impact_use_case.dart':
      'sync-covered external work unlink in timing delete cascade',

  // Migration data movement is historical/schema work, not a production write
  // path. Keep it explicit so it is not mistaken for row-level sync coverage.
  'lib/data/db/migrations/migration_019.dart': 'migration exemption',
};

const Set<String> _deferredRestoreAndMigrationExemptions = {
  'lib/data/services/backup/backup_tables.dart',
  'lib/data/services/backup/local_restore_service.dart',
  'lib/data/services/backup/backup_validator.dart',
  'lib/data/db/migrations/migration_019.dart',
  'lib/data/db/migrations/migration_020.dart',
  'lib/data/db/migrations/migration_021.dart',
};

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

List<String> _externalWorkWriteMarkers(String source) {
  final normalized = _normalizeWriteSource(source);
  final markers = <String>{};

  for (final pattern in _directExternalWorkTableWritePatterns.entries) {
    if (pattern.value.hasMatch(normalized)) {
      markers.add(pattern.key);
    }
  }
  if (_mentionsExternalWorkRecordsTable(normalized) &&
      _tableVariableCrudPattern.hasMatch(normalized)) {
    markers.add('sqflite external_work_records table variable CRUD call');
  }

  for (final repositoryName in _externalWorkRepositoryVariableNames(source)) {
    final escapedName = RegExp.escape(repositoryName);
    final repositoryWritePattern = RegExp(
      '$escapedName\\s*\\.\\s*'
      '(insertRecord|insertRecords|deleteById|deleteByBatchId|'
      'linkBatchToProject|linkBatchToProjectWithSettlementReset|'
      'unlinkBatch|unlinkByProjectIdWithExecutor|updateLocalFields)\\s*\\(',
    );
    if (repositoryWritePattern.hasMatch(source)) {
      markers.add('ExternalWorkRecordRepository direct write call');
    }
  }

  for (final storeName in _timingExternalWorkStoreVariableNames(source)) {
    final escapedName = RegExp.escape(storeName);
    final storeWritePattern = RegExp(
      '$escapedName\\s*\\.\\s*'
      '(deleteById|deleteByBatchId|linkBatchToProject|'
      'linkSettledBatchToProject|unlinkBatch)\\s*\\(',
    );
    if (storeWritePattern.hasMatch(source)) {
      markers.add('TimingExternalWorkStore write action call');
    }
  }

  for (final importerName in _externalWorkImporterVariableNames(source)) {
    final escapedName = RegExp.escape(importerName);
    final importerWritePattern = RegExp(
      '$escapedName\\s*\\.\\s*importParsed\\s*\\(',
    );
    if (importerWritePattern.hasMatch(source)) {
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

final Map<String, RegExp> _directExternalWorkTableWritePatterns = {
  'sqflite external_work_records table CRUD call': RegExp(
    r'\.\s*(insert|update|delete)\s*\(\s*'
    r'(external_work_records|sqfliteexternalworkrecordrepository\.table)\b',
  ),
  'raw SQL external_work_records write': RegExp(
    r'\b(rawinsert|rawupdate|rawdelete|execute)\s*\(\s*'
    r'(?:r)?\s*(insert\s+into|update|delete\s+from)\s+'
    r'external_work_records(?:\b|_)',
  ),
};

final RegExp _tableVariableCrudPattern = RegExp(
  r'\.\s*(insert|update|delete)\s*\(\s*_?table\b',
);

bool _mentionsExternalWorkRecordsTable(String source) {
  return source.contains('external_work_records');
}

String _normalizeWriteSource(String source) {
  return source
      .toLowerCase()
      .replaceAll('"', '')
      .replaceAll("'", '')
      .replaceAll('`', '');
}

Set<String> _externalWorkRepositoryVariableNames(String source) {
  final names = <String>{};
  final typedRepositoryPattern = RegExp(
    '\\b(?:ExternalWorkRecordRepository|SqfliteExternalWorkRecordRepository)'
    '\\??\\s+([A-Za-z_]\\w*)',
  );
  final constructedRepositoryPattern = RegExp(
    '\\b(?:final\\s+|var\\s+)?([A-Za-z_]\\w*)\\s*=\\s*'
    'SqfliteExternalWorkRecordRepository\\s*\\(',
  );
  final fieldPattern = RegExp(
    '\\bfinal\\s+'
    '(?:ExternalWorkRecordRepository|SqfliteExternalWorkRecordRepository)'
    '\\s+([A-Za-z_]\\w*)',
  );

  for (final match in typedRepositoryPattern.allMatches(source)) {
    names.add(match.group(1)!);
  }
  for (final match in constructedRepositoryPattern.allMatches(source)) {
    names.add(match.group(1)!);
  }
  for (final match in fieldPattern.allMatches(source)) {
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

void _expectAllContains(String source, Iterable<String> snippets) {
  for (final snippet in snippets) {
    expect(
      source,
      contains(snippet),
      reason: 'Missing source marker: $snippet',
    );
  }
}

void _expectInOrder(String source, List<String> snippets) {
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
  expect(start, isNot(-1), reason: 'Missing slice start marker: $startMarker');
  final end = source.indexOf(endMarker, start + startMarker.length);
  expect(end, isNot(-1), reason: 'Missing slice end marker: $endMarker');
  return source.substring(start, end);
}

String _describeUnexpected(
  Map<String, List<String>> actual,
  Set<String> expected,
) {
  final unexpected = actual.keys.toSet().difference(expected).toList()..sort();
  if (unexpected.isEmpty) {
    return 'No unexpected ExternalWork write paths.';
  }
  return 'Unexpected paths:\n${unexpected.map((path) {
    final markers = actual[path]!.join(', ');
    return '$path: $markers';
  }).join('\n')}';
}

String _describeMissing(Set<String> actual, Set<String> expected) {
  final missing = expected.difference(actual).toList()..sort();
  if (missing.isEmpty) {
    return 'No stale ExternalWork allowlist paths.';
  }
  return 'Missing paths:\n${missing.map((path) {
    final reason = _registeredExternalWorkWriteFiles[path];
    return '$path: $reason';
  }).join('\n')}';
}

class _ExternalWorkSyncStrategy {
  const _ExternalWorkSyncStrategy({
    required this.externalWorkEntityType,
    required this.linkAndUnlinkAreUpdates,
    required this.bulkImportUsesRowLevelCreates,
    required this.resetRequiresExternalWorkUpdateProjectWriteOffDeleteAndProjectUpdate,
    required this.externalWorkResetIsCloudPushBlocker,
    required this.externalWorkHelperImplemented,
    required this.externalWorkImportOutboxCovered,
    required this.externalWorkOrdinaryLinkOutboxCovered,
    required this.externalWorkOrdinaryUnlinkOutboxCovered,
    required this.externalWorkDeleteOutboxCovered,
    required this.timingDeleteCascadeExternalWorkUnlinkCovered,
    required this.externalWorkAllProductionOutboxCovered,
    required this.externalWorkResetCovered,
    required this.restoreRequiresReconcileBeforePush,
    required this.requiresOrderingOrTransactionGroupBeforeCloudPush,
    required this.singleProjectSettlementCovered,
    required this.mergedSettlementCovered,
    required this.timingDeleteSettlementCascadeCovered,
  });

  final String externalWorkEntityType;
  final bool linkAndUnlinkAreUpdates;
  final bool bulkImportUsesRowLevelCreates;
  final bool
  resetRequiresExternalWorkUpdateProjectWriteOffDeleteAndProjectUpdate;
  final bool externalWorkResetIsCloudPushBlocker;
  final bool externalWorkHelperImplemented;
  final bool externalWorkImportOutboxCovered;
  final bool externalWorkOrdinaryLinkOutboxCovered;
  final bool externalWorkOrdinaryUnlinkOutboxCovered;
  final bool externalWorkDeleteOutboxCovered;
  final bool timingDeleteCascadeExternalWorkUnlinkCovered;
  final bool externalWorkAllProductionOutboxCovered;
  final bool externalWorkResetCovered;
  final bool restoreRequiresReconcileBeforePush;
  final bool requiresOrderingOrTransactionGroupBeforeCloudPush;
  final bool singleProjectSettlementCovered;
  final bool mergedSettlementCovered;
  final bool timingDeleteSettlementCascadeCovered;
}
