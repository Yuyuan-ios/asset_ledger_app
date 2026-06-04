import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('account payment sync coverage invariant', () {
    test('AccountPaymentSyncEnqueuer owns the row-level payload contract', () {
      final source = _read(
        'lib/infrastructure/local/account/account_payment_sync_enqueuer.dart',
      );

      _expectAllContains(source, const [
        'class AccountPaymentSyncEnqueuer',
        'enqueueWithExecutor(',
        'upsertWithExecutor(',
        "'entity_type': entityType",
        "'entity_id': entityId",
        "'operation': operation",
        "'record': payment.toMap()",
        'payloadHash: entry.payloadHash',
        'syncStatus: status',
      ]);
      expect(
        source,
        contains('StateError'),
        reason:
            'The sync helper must keep rejecting unsaved account_payment rows.',
      );
    });

    test('LocalAccountPaymentWriteUseCase remains the sync-aware account '
        'payment write coordinator', () {
      final source = _read(
        'lib/infrastructure/local/account/local_account_payment_write_use_case.dart',
      );

      _expectAllContains(source, const [
        'AccountPaymentSyncEnqueuer',
        'Future<int> create(AccountPayment payment)',
        'Future<void> update(AccountPayment payment)',
        'Future<void> deleteById(int id)',
        'Future<List<AccountPayment>> createBatch(',
        'Future<List<AccountPayment>> replaceBatch({',
        'Future<int> deleteBatch(String batchId)',
        'SyncStatus.pendingUpload',
        'SyncStatus.pendingUpdate',
        'SyncStatus.pendingDelete',
        "operation: 'create'",
        "operation: 'update'",
        "operation: 'delete'",
        '_syncEnqueuer.enqueue(',
        '_paymentRepository.validateMergeBatchReplacement(',
      ]);
      expect(
        source,
        isNot(contains('SqfliteAccountPaymentRepository()')),
        reason:
            'replaceBatch must keep using the injected repository instead of '
            'constructing a repo-only path.',
      );
      expect(
        source,
        isNot(contains("'record': payment.toMap()")),
        reason:
            'The use case should delegate payload/hash construction to '
            'AccountPaymentSyncEnqueuer.',
      );
    });

    test(
      'settlement payment insert remains covered by AccountPaymentSyncEnqueuer',
      () {
        final source = _read(
          'lib/infrastructure/local/account/local_project_settlement_repository.dart',
        );

        _expectAllContains(source, const [
          'AccountPaymentSyncEnqueuer',
          '_accountPaymentSyncEnqueuer.enqueue(',
          'payment.copyWith(id: paymentId)',
          "operation: 'create'",
          'status: SyncStatus.pendingUpload',
          'AppDatabase.inTransaction',
        ]);
        _expectInOrder(source, const [
          'if (paymentFen > 0)',
          'paymentId = await txn.insert',
          '_accountPaymentSyncEnqueuer.enqueue(',
          'if (writeOffFen > 0)',
        ]);
        expect(
          _occurrences(source, '_accountPaymentSyncEnqueuer.enqueue('),
          1,
          reason:
              'Only the settlement payment insert is covered in R5.7; write-off '
              'delete/revoke paths must not silently grow account_payment '
              'delete enqueue behavior in R5.8.',
        );
        expect(
          source,
          isNot(contains("operation: 'delete'")),
          reason:
              'ProjectWriteOff and settlement revoke/delete sync are deferred.',
        );
        expect(
          source,
          isNot(contains('SyncStatus.pendingDelete')),
          reason:
              'ProjectWriteOff and settlement revoke/delete sync are deferred.',
        );
      },
    );

    test('production wiring keeps AccountPaymentWriteUseCase', () {
      final providers = _read('lib/app/providers/account_merge_providers.dart');
      final controller = _read(
        'lib/features/account/application/controllers/account_action_controller.dart',
      );
      final store = _read(
        'lib/features/account/state/account_payment_store.dart',
      );
      final createMerged = _read(
        'lib/features/account/use_cases/create_merged_payment_use_case.dart',
      );
      final updateMerged = _read(
        'lib/features/account/use_cases/update_merged_payment_batch_use_case.dart',
      );
      final deleteMerged = _read(
        'lib/features/account/use_cases/delete_merged_payment_batch_use_case.dart',
      );

      _expectAllContains(providers, const [
        'final accountPaymentWriteUseCase = LocalAccountPaymentWriteUseCase(',
        'AccountPaymentStore(',
        'writeUseCase: accountPaymentWriteUseCase',
        'paymentWriteUseCase: accountPaymentWriteUseCase',
      ]);
      _expectAllContains(controller, const [
        'final AccountPaymentWriteUseCase? _paymentWriteUseCase;',
        'paymentWriteUseCase,',
        'writeUseCase: _paymentWriteUseCase',
      ]);
      expect(
        _occurrences(controller, 'writeUseCase: _paymentWriteUseCase'),
        3,
        reason:
            'Create/update/delete merged payment use cases must all receive the '
            'sync-aware write use case from the production controller wiring.',
      );
      _expectAllContains(store, const [
        'AccountPaymentWriteUseCase? writeUseCase',
        'writeUseCase.create(payment)',
        'writeUseCase.update(payment)',
        'writeUseCase.deleteById(id)',
        '_repository.insert(payment)',
        '_repository.update(payment)',
        '_repository.deleteById(id)',
      ]);
      _expectAllContains(createMerged, const [
        'AccountPaymentWriteUseCase? writeUseCase',
        'writeUseCase.createBatch(allocations)',
        '_repository.insertAllInTransaction(allocations)',
      ]);
      _expectAllContains(updateMerged, const [
        'AccountPaymentWriteUseCase? writeUseCase',
        'writeUseCase.replaceBatch(',
        '_repository.replaceMergeBatchInTransaction(',
      ]);
      _expectAllContains(deleteMerged, const [
        'AccountPaymentWriteUseCase? writeUseCase',
        'writeUseCase.deleteBatch(batchId)',
        '_repository.deleteByMergeBatchId(batchId)',
      ]);
    });

    test('unknown account payment production writes must be registered', () {
      final actual = <String>{
        for (final file in _libDartFiles())
          if (_hasAccountPaymentWriteMarker(_read(file))) file,
      };
      final expected = _registeredAccountPaymentWriteFiles.keys.toSet();

      expect(
        actual.difference(expected),
        isEmpty,
        reason:
            'Unregistered account_payments production write paths must be wired '
            'through AccountPaymentWriteUseCase or AccountPaymentSyncEnqueuer, '
            'or added to this invariant allowlist with an explicit exemption.\n'
            '${_describeUnexpected(actual, expected)}',
      );
      expect(
        expected.difference(actual),
        isEmpty,
        reason:
            'A registered account_payments write/exemption path no longer '
            'contains write markers. Remove stale allowlist entries only after '
            'checking the coverage invariant is still represented.\n'
            '${_describeMissing(actual, expected)}',
      );
    });

    test(
      'restore and migration account payment writes stay explicit exemptions',
      () {
        final backupTables = _read(
          'lib/data/services/backup/backup_tables.dart',
        );
        final restore = _read(
          'lib/data/services/backup/local_restore_service.dart',
        );

        expect(
          backupTables,
          contains("'account_payments'"),
          reason:
              'Restore keeps account_payments in the backup table set, but restore '
              'reconcile is deferred and must remain an explicit exemption here.',
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
            reason: 'Missing deferred account_payments exemption file: $path',
          );
        }
      },
    );
  });
}

const Map<String, String> _registeredAccountPaymentWriteFiles = {
  // Covered production entry: single-row and merged-batch writes enqueue
  // account_payment outbox/meta in the same transaction.
  'lib/infrastructure/local/account/local_account_payment_write_use_case.dart':
      'covered by AccountPaymentSyncEnqueuer',

  // Covered production entry: settlement payment insert calls
  // AccountPaymentSyncEnqueuer inside the settlement transaction.
  'lib/infrastructure/local/account/local_project_settlement_repository.dart':
      'covered by AccountPaymentSyncEnqueuer',

  // Low-level infrastructure is allowed to contain raw CRUD. Production writes
  // must reach it through LocalAccountPaymentWriteUseCase or the settlement
  // repository coverage point above.
  'lib/data/repositories/account_payment_repository.dart':
      'low-level repository CRUD',

  // Production wiring/fallback files. Provider/controller tests above assert
  // that production construction injects AccountPaymentWriteUseCase; the direct
  // repository fallbacks remain legacy/test-only deferred behavior for now.
  'lib/features/account/state/account_payment_store.dart':
      'legacy fallback guarded by production writeUseCase injection',
  'lib/features/account/use_cases/create_merged_payment_use_case.dart':
      'legacy fallback guarded by production writeUseCase injection',
  'lib/features/account/use_cases/update_merged_payment_batch_use_case.dart':
      'legacy fallback guarded by production writeUseCase injection',
  'lib/features/account/use_cases/delete_merged_payment_batch_use_case.dart':
      'legacy fallback guarded by production writeUseCase injection',

  // Timing delete uses the account payment repository for impact analysis; the
  // direct write marker in this file belongs to timing record deletion.
  'lib/infrastructure/local/timing/local_delete_timing_record_with_impact_use_case.dart':
      'account payment read dependency; timing delete write marker',

  // Schema/migration account_payments writes are historical data movement and
  // intentionally outside row-level sync coverage.
  'lib/data/db/migrations/migration_018.dart': 'migration exemption',
  'lib/data/db/migrations/project_foreign_key_migration.dart':
      'migration exemption',
  'lib/data/db/migrations/project_identity_migration.dart':
      'migration exemption',
};

const Set<String> _deferredRestoreAndMigrationExemptions = {
  'lib/data/services/backup/backup_tables.dart',
  'lib/data/services/backup/local_restore_service.dart',
  'lib/data/db/migrations/migration_018.dart',
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

bool _hasAccountPaymentWriteMarker(String source) {
  final hasAccountPaymentMarker =
      source.contains('account_payments') ||
      source.contains('SqfliteAccountPaymentRepository') ||
      source.contains('AccountPaymentRepository');
  if (!hasAccountPaymentMarker) {
    return false;
  }

  return const [
    'insertWithExecutor(',
    'insertAllWithExecutor(',
    'updateWithExecutor(',
    'deleteByIdWithExecutor(',
    'deleteByMergeBatchIdWithExecutor(',
    '.insert(payment)',
    '.update(payment)',
    '.deleteById(id)',
    'insertAllInTransaction(',
    'replaceMergeBatchInTransaction(',
    'deleteByMergeBatchId(',
    'txn.insert(',
    'batch.insert(',
    'db.insert(',
    'db.update(',
    'db.delete(',
    'INSERT INTO account_payments',
    'UPDATE account_payments',
    'DELETE FROM account_payments',
  ].any(source.contains);
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

int _occurrences(String source, String needle) =>
    RegExp(RegExp.escape(needle)).allMatches(source).length;

String _describeUnexpected(Set<String> actual, Set<String> expected) {
  final unexpected = actual.difference(expected).toList()..sort();
  if (unexpected.isEmpty) {
    return 'No unexpected account_payments write paths.';
  }
  return 'Unexpected paths:\n${unexpected.join('\n')}';
}

String _describeMissing(Set<String> actual, Set<String> expected) {
  final missing = expected.difference(actual).toList()..sort();
  if (missing.isEmpty) {
    return 'No stale account_payments allowlist paths.';
  }
  return 'Missing paths:\n${missing.join('\n')}';
}
