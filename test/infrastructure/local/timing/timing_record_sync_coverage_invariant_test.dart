import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('timing record sync coverage invariant', () {
    test('timing record save path remains sync covered', () {
      final source = _read(
        'lib/infrastructure/local/timing/local_save_timing_record_with_impact_use_case.dart',
      );

      _expectAllContains(source, const [
        'class LocalSaveTimingRecordWithImpactUseCase',
        'SyncOutboxRepository? syncOutboxRepository',
        'EntitySyncMetaRepository? entitySyncMetaRepository',
        'ProjectSyncEnqueuer? projectSyncEnqueuer',
        'LocalSyncOutboxRepository()',
        'LocalEntitySyncMetaRepository()',
        'ProjectSyncEnqueuer(',
        "static const String _timingRecordEntityType = 'timing_record';",
        'AppDatabase.inTransaction',
        'executeWithExecutor(',
        '_saveRecordWithExecutor(',
        'applyRevocations(',
        'SyncTransactionGroup.create()',
        '_enqueueSyncForSavedRecord(',
        '_enqueueRevokedProjectUpdate(',
        '_projectSyncEnqueuer.enqueueUpdate(',
        '_syncOutboxRepository.enqueueWithExecutor(',
        '_entitySyncMetaRepository.upsertWithExecutor(',
        "final operation = isEditing ? 'update' : 'create';",
        // R5.25 payload schema version + actor traceability + updated_by.
        "'payload_schema_version': kSyncPayloadSchemaVersion",
        "'actor': syncActorPayload(resolvedActor)",
        'updatedBy: resolvedActor.actorId',
        "'entity_type': _timingRecordEntityType",
        "'entity_id': entityId",
        "'operation': operation",
        "'record': savedRecord.toMap(",
        'transactionGroupId: group?.id',
        'localSequence: group?.nextSequence()',
        'transactionGroupId: group.id',
        'localSequence: group.nextSequence()',
        'SyncStatus.pendingUpdate',
        'SyncStatus.pendingUpload',
        'payloadHash: entry.payloadHash',
        'insertWithExecutor(',
        'updateWithExecutor(',
      ]);
      _expectInOrder(source, const [
        'AppDatabase.inTransaction',
        'executeWithExecutor(',
      ]);
      _expectInOrder(source, const [
        '_saveRecordWithExecutor(',
        'applyRevocations(',
        '_enqueueSyncForSavedRecord(',
        '_enqueueRevokedProjectUpdate(',
        'return SaveTimingRecordWithImpactResult(',
      ]);
      expect(
        source,
        isNot(contains('SqfliteTimingRepository()')),
        reason:
            'The save coordinator must keep using its injected timing repository.',
      );
    });

    test('timing record delete path remains sync covered', () {
      final source = _read(
        'lib/infrastructure/local/timing/local_delete_timing_record_with_impact_use_case.dart',
      );

      _expectAllContains(source, const [
        'class LocalDeleteTimingRecordWithImpactUseCase',
        'SyncOutboxRepository? syncOutboxRepository',
        'EntitySyncMetaRepository? entitySyncMetaRepository',
        'ProjectWriteOffSyncEnqueuer? projectWriteOffSyncEnqueuer',
        'ProjectSyncEnqueuer? projectSyncEnqueuer',
        'ExternalWorkSyncEnqueuer? externalWorkSyncEnqueuer',
        'LocalSyncOutboxRepository()',
        'LocalEntitySyncMetaRepository()',
        'ProjectWriteOffSyncEnqueuer(',
        'ProjectSyncEnqueuer(',
        'ExternalWorkSyncEnqueuer(',
        "static const String _timingRecordEntityType = 'timing_record';",
        'AppDatabase.inTransaction',
        'executeDeleteWithImpact(',
        '_timingRepository.findByIdWithExecutor(',
        '_timingRepository.deleteByIdWithExecutor(',
        'listByProjectIdWithExecutor(',
        'deleteByIdWithExecutor(',
        '_projectWriteOffSyncEnqueuer.enqueueDelete(',
        '_projectRepository.restoreActiveWithExecutor(',
        '_enqueueProjectUpdate(',
        '_projectRepository.findByIdWithExecutor(',
        '_projectSyncEnqueuer.enqueueUpdate(',
        'listByLinkedProjectIdWithExecutor(txn, projectId)',
        'unlinkByProjectIdWithExecutor(',
        '_externalWorkSyncEnqueuer.enqueueUpdate(',
        '_enqueueSyncForDeletedRecord(',
        '_syncOutboxRepository.enqueueWithExecutor(',
        '_entitySyncMetaRepository.upsertWithExecutor(',
        "operation: 'delete'",
        "'entity_type': _timingRecordEntityType",
        "'entity_id': entityId",
        "'operation': 'delete'",
        "'record': deletedRecord.toMap()",
        'SyncStatus.pendingDelete',
        'payloadHash: entry.payloadHash',
      ]);
      _expectInOrder(source, const [
        'AppDatabase.inTransaction',
        '_timingRepository.findByIdWithExecutor(',
        'if (isLast && paymentCount > 0)',
        '_timingRepository.deleteByIdWithExecutor(',
        'listByProjectIdWithExecutor(',
        '_projectWriteOffSyncEnqueuer.enqueueDelete(',
        '_projectRepository.restoreActiveWithExecutor(',
        '_enqueueProjectUpdate(',
        'listByLinkedProjectIdWithExecutor(txn, projectId)',
        'unlinkByProjectIdWithExecutor(',
        '_externalWorkSyncEnqueuer.enqueueUpdate(',
        '_enqueueSyncForDeletedRecord(',
        'return TimingRecordDeleteOutcome(',
      ]);

      final analyzeImpact = _sliceBetween(
        source,
        'Future<TimingRecordDeleteImpact> analyzeImpact(',
        'Future<TimingRecordDeleteOutcome> executeDeleteWithImpact(',
      );
      _expectNoSyncWrites(
        analyzeImpact,
        context: 'analyzeImpact must remain read-only',
      );
    });

    test('token aware save path does not fork around sync covered save', () {
      final saveUseCase = _read(
        'lib/features/timing/use_cases/save_timing_record_use_case.dart',
      );
      final confirmAdapter = _read(
        'lib/features/timing/operations/save_timing_record_operation_confirm_adapter.dart',
      );
      final command = _read(
        'lib/features/timing/operations/save_timing_record_operation_command.dart',
      );
      final providers = _read('lib/app/providers/timing_save_providers.dart');

      _expectAllContains(saveUseCase, const [
        'Future<SaveTimingRecordResult> executeWithToken({',
        'final svc = previewService;',
        'final adapter = confirmAdapter;',
        'svc.previewWithToken(',
        'adapter.executeConfirmedWithToken(',
        'executeSaveWithExecutor: (executor) async {',
        'await _withImpact.executeWithExecutor(',
      ]);
      _expectInOrder(saveUseCase, const [
        'svc.previewWithToken(',
        'adapter.executeConfirmedWithToken(',
        'await _withImpact.executeWithExecutor(',
      ]);
      expect(
        _occurrences(saveUseCase, 'await _withImpact.executeWithExecutor('),
        2,
        reason:
            'Token-aware and legacy save paths must keep sharing the same sync-covered withImpact executor path.',
      );

      _expectAllContains(confirmAdapter, const [
        'executeConfirmedWithToken({',
        'command.executeConfirmedInTransaction(',
        'claimForConsumeWithExecutor(',
        'return executeSaveWithExecutor(executor);',
      ]);
      _expectAllContains(command, const [
        'executeConfirmedInTransaction({',
        'runner.run((executor) async {',
        'final businessResult = await executeSaveWithExecutor(executor);',
        'await repo.insertWithExecutor(executor, log);',
      ]);
      _expectAllContains(providers, const [
        'final withImpact = LocalSaveTimingRecordWithImpactUseCase(',
        'final saveUseCase = SaveTimingRecordUseCase(',
        'withImpact: withImpact',
        'previewService: previewService',
        'confirmAdapter: confirmAdapter',
      ]);

      expect(
        _timingRecordWriteMarkers(saveUseCase),
        isEmpty,
        reason:
            'SaveTimingRecordUseCase must orchestrate, not write timing_records directly.',
      );
      expect(
        _timingRecordWriteMarkers(confirmAdapter),
        isEmpty,
        reason:
            'Confirm adapter must claim token and delegate business writes, not write timing_records directly.',
      );
    });

    test('preview and analyzer paths do not enqueue timing record sync', () {
      final paths = const {
        'analyzer':
            'lib/features/timing/operations/save_timing_record_operation_analyzer.dart',
        'preview adapter':
            'lib/features/timing/operations/save_timing_record_operation_preview_adapter.dart',
        'preview service':
            'lib/features/timing/operations/save_timing_record_preview_service.dart',
        'preview token issuer':
            'lib/features/timing/operations/save_timing_record_preview_token_issuer.dart',
      };

      for (final entry in paths.entries) {
        final source = _read(entry.value);
        _expectNoSyncWrites(
          source,
          context: '${entry.key} must not enqueue sync',
        );
        expect(
          _timingRecordWriteMarkers(source),
          isEmpty,
          reason:
              '${entry.value} must not write timing_records; preview/analyze may read only.',
        );
      }
    });

    test('unknown timing record production writes must be registered', () {
      final actual = <String, List<String>>{
        for (final file in _libDartFiles())
          if (_timingRecordWriteMarkers(_read(file)).isNotEmpty)
            file: _timingRecordWriteMarkers(_read(file)),
      };
      final expected = _registeredTimingRecordWriteFiles.keys.toSet();
      final actualPaths = actual.keys.toSet();

      expect(
        actualPaths.difference(expected),
        isEmpty,
        reason:
            'Unregistered timing_records production write paths must be wired through '
            'LocalSaveTimingRecordWithImpactUseCase or '
            'LocalDeleteTimingRecordWithImpactUseCase, or added to this invariant '
            'allowlist with an explicit restore/migration/fallback exemption.\n'
            '${_describeUnexpected(actual, expected)}',
      );
      expect(
        expected.difference(actualPaths),
        isEmpty,
        reason:
            'A registered timing_records write/exemption path no longer contains '
            'write markers. Remove stale allowlist entries only after checking the '
            'coverage invariant is still represented.\n'
            '${_describeMissing(actualPaths, expected)}',
      );
    });

    test('timing record direct write detector recognizes common write shapes', () {
      const writeExamples = {
        'executor.insert literal':
            "await executor.insert('timing_records', data);",
        'db.update uppercase literal':
            'await db.update("TIMING_RECORDS", data);',
        'database.delete quoted literal':
            "await database.delete('\"timing_records\"', where: 'id = ?');",
        'txn.insert repository table':
            'await txn.insert(SqfliteTimingRepository._table, data);',
        'table const write':
            "const _table = 'timing_records'; await client.insert(_table, row);",
        'raw insert lowercase':
            "await db.rawInsert('insert into timing_records (id) values (?)');",
        'raw update uppercase':
            "await db.rawUpdate('UPDATE TIMING_RECORDS SET hours = ?');",
        'raw delete mixed case':
            "await db.rawDelete('Delete From \"timing_records\" WHERE id = ?');",
        'execute raw insert':
            "await db.execute('INSERT INTO timing_records (id) VALUES (1)');",
        'repository save':
            'final TimingRepository repository; await repository.save(record);',
        'repository executor update':
            'final SqfliteTimingRepository timingRepository; '
            'await timingRepository.updateWithExecutor(txn, record);',
        'constructed repository delete':
            'final repo = SqfliteTimingRepository(); await repo.deleteById(id);',
      };

      for (final entry in writeExamples.entries) {
        expect(
          _timingRecordWriteMarkers(entry.value),
          isNotEmpty,
          reason: 'Detector missed ${entry.key}: ${entry.value}',
        );
      }

      const nonWrites = [
        "await executor.insert('account_payments', data);",
        "await db.rawInsert('INSERT INTO project_write_offs (id) VALUES (1)');",
        'final AccountPaymentRepository repository; '
            'await repository.deleteByIdWithExecutor(txn, id);',
        'final TimingRepository repository; '
            'await repository.countByProjectId(projectId);',
        'final SqfliteTimingRepository repository; '
            'await repository.findByIdWithExecutor(txn, id);',
      ];

      for (final source in nonWrites) {
        expect(
          _timingRecordWriteMarkers(source),
          isEmpty,
          reason: 'Detector should ignore non timing_records writes: $source',
        );
      }
    });

    test(
      'restore and migration timing record writes stay explicit exemptions',
      () {
        final backupTables = _read(
          'lib/data/services/backup/backup_tables.dart',
        );
        final restore = _read(
          'lib/data/services/backup/local_restore_service.dart',
        );

        expect(
          backupTables,
          contains("'timing_records'"),
          reason:
              'Restore keeps timing_records in the backup table set, but restore reconcile is deferred.',
        );
        _expectAllContains(restore, const [
          'for (final tableName in BackupRestoreTables.insertOrder)',
          'batch.insert(',
          'tableName,',
          'row,',
        ]);
        for (final path in _deferredRestoreAndMigrationExemptions) {
          expect(
            File(path).existsSync(),
            isTrue,
            reason: 'Missing deferred timing_records exemption file: $path',
          );
        }
      },
    );
  });
}

const Map<String, String> _registeredTimingRecordWriteFiles = {
  // Covered production save entry: timing_record create/update enqueue
  // outbox/meta in the same transaction as the business save and impacts.
  'lib/infrastructure/local/timing/local_save_timing_record_with_impact_use_case.dart':
      'covered save create/update path',

  // Covered production delete entry: timing_record delete enqueues outbox/meta
  // in the same transaction as delete and cascade impact handling.
  'lib/infrastructure/local/timing/local_delete_timing_record_with_impact_use_case.dart':
      'covered delete path',

  // Low-level infrastructure is allowed to contain raw CRUD. Production writes
  // must reach it through the covered save/delete coordinators above.
  'lib/data/repositories/timing_repository.dart': 'low-level repository CRUD',

  // Legacy/fallback store writes remain deferred. Production save/delete flows
  // are guarded above through provider wiring and use-case orchestration.
  'lib/features/timing/state/timing_store.dart':
      'legacy fallback guarded by production use-case wiring',

  // Schema/migration timing_records writes are historical data movement and
  // intentionally outside row-level sync coverage.
  'lib/data/db/migrations/project_foreign_key_migration.dart':
      'migration exemption',
  'lib/data/db/migrations/project_identity_migration.dart':
      'migration exemption',
  // R5.26-B3：income_fen additive 迁移回填（UPDATE timing_records SET income_fen）
  // 是历史数据移动，刻意在 row-level sync 覆盖之外。
  'lib/data/db/migrations/migration_029.dart': 'migration exemption',
  // S2/v33：unit / quantity_scaled additive 迁移回填（UPDATE timing_records
  // SET unit / quantity_scaled）同为历史数据移动，刻意在 row-level sync 覆盖之外。
  'lib/data/db/migrations/migration_033.dart': 'migration exemption',
  // v34：income_fen NOT NULL 表重建（INSERT…SELECT / DROP / RENAME）是
  // 历史数据移动，刻意在 row-level sync 覆盖之外。
  'lib/data/db/migrations/migration_034.dart': 'migration exemption',
  // v36：unit NOT NULL 表重建同为历史数据移动，刻意在 row-level sync
  // 覆盖之外。
  'lib/data/db/migrations/migration_036.dart': 'migration exemption',
};

const Set<String> _deferredRestoreAndMigrationExemptions = {
  'lib/data/services/backup/backup_tables.dart',
  'lib/data/services/backup/local_restore_service.dart',
  'lib/data/db/migrations/project_foreign_key_migration.dart',
  'lib/data/db/migrations/project_identity_migration.dart',
};

String _read(String relativePath) => File(relativePath).readAsStringSync();

List<String> _libDartFiles() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.path.replaceAll('\\', '/'))
      .toList();
  files.sort();
  return files;
}

List<String> _timingRecordWriteMarkers(String source) {
  final normalizedSource = _normalizeWriteSource(source);
  final markers = <String>{};
  for (final pattern in _directTimingRecordsTableWritePatterns.entries) {
    if (pattern.value.hasMatch(normalizedSource)) {
      markers.add(pattern.key);
    }
  }
  if (_mentionsTimingRecordsTableLiteral(normalizedSource) &&
      _tableVariableCrudPattern.hasMatch(normalizedSource)) {
    markers.add('sqflite timing_records table variable CRUD call');
  }

  for (final repositoryName in _timingRepositoryVariableNames(source)) {
    final escapedName = RegExp.escape(repositoryName);
    final repositoryWritePattern = RegExp(
      '$escapedName\\s*\\.\\s*'
      '(insertWithExecutor|updateWithExecutor|deleteByIdWithExecutor|'
      'saveWithCalculationHistories|deleteByDeviceId|deleteByIds|'
      'insert|update|save|delete|deleteById|replace)\\s*\\(',
    );
    if (repositoryWritePattern.hasMatch(source)) {
      markers.add('TimingRepository direct write call');
    }
  }

  return markers.toList()..sort();
}

final Map<String, RegExp> _directTimingRecordsTableWritePatterns = {
  'sqflite table CRUD call': RegExp(
    r'\.\s*(insert|update|delete)\s*\(\s*'
    r'(timing_records|sqflitetimingrepository\._table|'
    r'timingrecordstable|timingrecordtable|timingtable)\b',
  ),
  'raw SQL timing_records write': RegExp(
    r'\b(rawinsert|rawupdate|rawdelete|execute)\s*\(\s*'
    r'(?:r)?\s*(insert\s+into|update|delete\s+from)\s+'
    r'timing_records(?:\b|_)',
  ),
};

final RegExp _tableVariableCrudPattern = RegExp(
  r'\.\s*(insert|update|delete)\s*\(\s*_?table\b',
);

bool _mentionsTimingRecordsTableLiteral(String source) {
  return source.contains('timing_records');
}

String _normalizeWriteSource(String source) {
  return source
      .toLowerCase()
      .replaceAll('"', '')
      .replaceAll("'", '')
      .replaceAll('`', '');
}

Set<String> _timingRepositoryVariableNames(String source) {
  final names = <String>{};
  final typedRepositoryPattern = RegExp(
    '\\b(?:TimingRepository|SqfliteTimingRepository)\\??\\s+([A-Za-z_]\\w*)',
  );
  final constructedRepositoryPattern = RegExp(
    '\\b(?:final\\s+|var\\s+)?([A-Za-z_]\\w*)\\s*=\\s*'
    'SqfliteTimingRepository\\s*\\(',
  );

  for (final match in typedRepositoryPattern.allMatches(source)) {
    names.add(match.group(1)!);
  }
  for (final match in constructedRepositoryPattern.allMatches(source)) {
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

void _expectNoSyncWrites(String source, {required String context}) {
  expect(source, isNot(contains('sync_outbox')), reason: context);
  expect(source, isNot(contains('entity_sync_meta')), reason: context);
  expect(source, isNot(contains('enqueueWithExecutor(')), reason: context);
  expect(source, isNot(contains('upsertWithExecutor(')), reason: context);
}

int _occurrences(String source, String needle) =>
    RegExp(RegExp.escape(needle)).allMatches(source).length;

String _describeUnexpected(
  Map<String, List<String>> actual,
  Set<String> expected,
) {
  final unexpected = actual.keys.toSet().difference(expected).toList()..sort();
  if (unexpected.isEmpty) {
    return 'No unexpected timing_records write paths.';
  }
  return 'Unexpected paths:\n${unexpected.map((path) {
    final markers = actual[path]!.join(', ');
    return '$path: $markers';
  }).join('\n')}';
}

String _describeMissing(Set<String> actual, Set<String> expected) {
  final missing = expected.difference(actual).toList()..sort();
  if (missing.isEmpty) {
    return 'No stale timing_records allowlist paths.';
  }
  return 'Missing paths:\n${missing.join('\n')}';
}
