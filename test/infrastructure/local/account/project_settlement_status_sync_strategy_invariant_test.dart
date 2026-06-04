import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('project settlement status sync strategy invariant', () {
    test('project model keeps status and settlement snapshot fields', () {
      final projectModel = _read('lib/data/models/project.dart');
      final projectSchema = _read('lib/data/db/schema/project_schema.dart');

      _expectAllContains(projectModel, const [
        'enum ProjectStatus { active, settled, archived, voided }',
        'final ProjectStatus status;',
        'final String? settledAt;',
        'final String? settledSnapshot;',
        'status: status ?? this.status',
        'settledAt: identical(settledAt, _sentinel)',
        '? this.settledAt',
        ': settledAt as String?',
        'settledSnapshot: identical(settledSnapshot, _sentinel)',
        '? this.settledSnapshot',
        ': settledSnapshot as String?',
        "'status': status.name",
        "'settled_at': settledAt",
        "'settled_snapshot': settledSnapshot",
        "status: _parseStatus(map['status']),",
        "settledAt: map['settled_at'] as String?,",
        "settledSnapshot: map['settled_snapshot'] as String?,",
      ]);

      _expectAllContains(projectSchema, const [
        'CREATE TABLE projects',
        "status TEXT NOT NULL DEFAULT 'active'",
        'settled_at TEXT',
        'settled_snapshot TEXT',
        'idx_projects_active_legacy_key',
        "WHERE status = 'active'",
      ]);
    });

    test('registered project settlement status paths keep strategy markers', () {
      final projectRepository = _read(
        'lib/data/repositories/project_repository.dart',
      );
      final settlementRepository = _read(
        'lib/infrastructure/local/account/local_project_settlement_repository.dart',
      );
      final impactService = _read(
        'lib/infrastructure/local/account/project_settlement_impact_service.dart',
      );
      final timingSaveUseCase = _read(
        'lib/infrastructure/local/timing/local_save_timing_record_with_impact_use_case.dart',
      );
      final timingDeleteUseCase = _read(
        'lib/infrastructure/local/timing/local_delete_timing_record_with_impact_use_case.dart',
      );
      final externalWorkRepository = _read(
        'lib/data/repositories/external_work_record_repository.dart',
      );

      _expectAllContains(projectRepository, const [
        'static Future<void> upsertWithExecutor(',
        "'status': project.status.name",
        "'settled_at': project.settledAt",
        "'settled_snapshot': project.settledSnapshot",
        'Future<bool> restoreActiveWithExecutor(',
        "ProjectStatus.active.name",
        'settledAt: null',
        'settledSnapshot: null',
      ]);

      _expectAllContains(settlementRepository, const [
        'Future<ProjectSettlementResult> settle(',
        'Future<ProjectSettlementResult> settleMerged(',
        'Future<DeleteProjectWriteOffResult> deleteWriteOff(',
        'Future<DeleteProjectWriteOffResult> deleteMergedWriteOffs(',
        'Future<RevokeProjectSettlementStatusResult> revokeSettlementStatus(',
        'Future<RevokeProjectSettlementStatusResult> revokeMergedSettlementStatus(',
        'ProjectWriteOffSyncEnqueuer',
        'ProjectSyncEnqueuer',
        '_projectWriteOffSyncEnqueuer.enqueueCreate',
        '_projectWriteOffSyncEnqueuer.enqueueDelete',
        '_projectSyncEnqueuer.enqueueUpdate',
        'status: ProjectStatus.settled',
        'settledAt: request.createdAtIso',
        'status: ProjectStatus.active',
        'settledAt: null',
        'settledSnapshot: null',
      ]);

      _expectAllContains(impactService, const [
        'enum ProjectSettlementImpactReason',
        'editTiming',
        'deleteTiming',
        'Future<ProjectSettlementRevocationResult> applyRevocations(',
        'restoreActiveWithExecutor(',
        'ProjectSettlementRevocationResult(',
      ]);

      _expectAllContains(timingSaveUseCase, const [
        'ProjectSettlementImpactService',
        'applyRevocations(',
        'ProjectSettlementImpactReason.editTiming',
      ]);

      _expectAllContains(timingDeleteUseCase, const [
        'executeDeleteWithImpact(',
        'ProjectWriteOffSyncEnqueuer',
        'ProjectSyncEnqueuer',
        'listByProjectIdWithExecutor(',
        'deleteByIdWithExecutor(',
        '_projectWriteOffSyncEnqueuer.enqueueDelete',
        'restoreActiveWithExecutor(',
        '_projectSyncEnqueuer.enqueueUpdate',
        'settlementRevoked',
      ]);

      _expectAllContains(externalWorkRepository, const [
        'Future<int> linkBatchToProjectWithSettlementReset(',
        'SqfliteProjectWriteOffRepository.table',
        'status: ProjectStatus.active',
        'settledAt: null',
        'settledSnapshot: null',
      ]);
    });

    test('payment only settlement proves ProjectWriteOff is not sufficient', () {
      final settlementRepository = _read(
        'lib/infrastructure/local/account/local_project_settlement_repository.dart',
      );
      final settlementTests = _read(
        'test/features/account/use_cases/project_settlement_use_case_test.dart',
      );

      _expectInOrder(settlementRepository, const [
        'if (paymentFen > 0)',
        '_accountPaymentSyncEnqueuer.enqueue(',
        'if (writeOffFen > 0)',
        '_projectWriteOffSyncEnqueuer.enqueueCreate',
        'final settled = remainingFenAfter <= 0;',
        'status: ProjectStatus.settled',
        'settledAt: request.createdAtIso',
        '_enqueueProjectUpdate(txn, request.projectId)',
      ]);

      _expectAllContains(settlementTests, const [
        'settles a project with a full cash payment',
        'writeOffAmount: 0',
        'expect(await _writeOffCount(db), 0)',
        'expect(await _projectStatus(db), ProjectStatus.settled)',
        'ProjectSyncEnqueuer.entityType',
      ]);
    });

    test('revoke settlement status remains a status only mutation', () {
      final settlementRepository = _read(
        'lib/infrastructure/local/account/local_project_settlement_repository.dart',
      );
      final settlementTests = _read(
        'test/features/account/use_cases/project_settlement_use_case_test.dart',
      );
      final revokeSlice = _sliceBetween(
        settlementRepository,
        'Future<RevokeProjectSettlementStatusResult> revokeSettlementStatus(',
        'Future<RevokeProjectSettlementStatusResult> revokeMergedSettlementStatus(',
      );

      _expectAllContains(revokeSlice, const [
        'writeOffCount',
        'if (writeOffCount > 0)',
        'shouldRestoreActive',
        'status: ProjectStatus.active',
        'settledAt: null',
        'settledSnapshot: null',
        '_enqueueProjectUpdate(txn, request.projectId)',
      ]);
      expect(revokeSlice, isNot(contains('_projectWriteOffSyncEnqueuer')));
      expect(revokeSlice, isNot(contains('await txn.delete(')));
      expect(
        revokeSlice,
        isNot(contains('_accountPaymentSyncEnqueuer.enqueue(')),
      );
      expect(revokeSlice, isNot(contains('SyncStatus.pendingDelete')));

      _expectAllContains(settlementTests, const [
        'revokes settled status without changing payments or write-offs',
        'rejects settled status revoke when write-off records still exist',
        'expect(await _paymentCount(db), 1)',
        'expect(await _projectStatus(db), ProjectStatus.active)',
      ]);
    });

    test('ProjectWriteOff outbox alone is not Cloud push complete', () {
      expect(_settlementStatusStrategy.projectStatusIsCloudPushBlocker, isTrue);
      expect(
        _settlementStatusStrategy.projectWriteOffAloneIsInsufficient,
        isTrue,
      );
      expect(_settlementStatusStrategy.recommendedProjectEntityType, 'project');
      expect(
        _settlementStatusStrategy.recommendedProjectStatusOperation,
        'update',
      );
      expect(
        _settlementStatusStrategy.requiresSameTransactionWithSettlementCluster,
        isTrue,
      );
      expect(_settlementStatusStrategy.singleProjectStatusIsCovered, isTrue);
      expect(_settlementStatusStrategy.mergedProjectStatusIsCovered, isTrue);
      expect(_settlementStatusStrategy.mustCoverPaymentOnlySettlement, isTrue);
      expect(_settlementStatusStrategy.mustCoverStatusOnlyRevoke, isTrue);
      expect(
        _settlementStatusStrategy.timingDeleteCascadeRestoreIsCovered,
        isTrue,
      );
      expect(
        _settlementStatusStrategy.externalWorkSettlementResetIsDeferred,
        isTrue,
      );
      expect(
        _settlementStatusStrategy.mustCoverTimingDeleteCascadeRestore,
        isTrue,
      );
      expect(
        _settlementStatusStrategy.mustCoverExternalWorkSettlementReset,
        isTrue,
      );
    });

    test(
      'project settlement status direct write detector recognizes patterns',
      () {
        final examples = <String, bool>{
          '''
        await SqfliteProjectRepository.upsertWithExecutor(
          txn,
          project.copyWith(
            status: ProjectStatus.settled,
            settledAt: now,
          ),
        );
        ''':
              true,
          '''
        await repository.restoreActiveWithExecutor(
          txn,
          projectId: projectId,
          updatedAt: now,
        );
        ''':
              true,
          '''
        await db.update('projects', {
          'status': ProjectStatus.active.name,
          'settled_at': null,
        });
        ''':
              true,
          '''
        await db.rawUpdate('UPDATE projects SET status = ?, settled_at = NULL');
        ''':
              true,
          '''
        await executor.rawUpdate('update PROJECTS set settled_snapshot = null');
        ''':
              true,
          '''
        await db.update('account_payments', {'amount': 100});
        ''':
              false,
          '''
        Project(
          id: 1,
          status: ProjectStatus.active,
          createdAt: now,
          updatedAt: now,
        );
        ''':
              false,
          '''
        Future<void> revokeSettlementStatus(int projectId);
        ''':
              false,
        };

        for (final entry in examples.entries) {
          final reason = 'source:\n${entry.key}';
          expect(
            _projectSettlementStatusWriteMarkers(entry.key).isNotEmpty,
            entry.value,
            reason: reason,
          );
        }
      },
    );

    test(
      'unknown project settlement status writes must be registered in the invariant allowlist',
      () {
        final actual = <String, List<String>>{};
        for (final file in _libDartFiles()) {
          final relativePath = _relativePath(file);
          final markers = _projectSettlementStatusWriteMarkers(
            file.readAsStringSync(),
          );
          if (markers.isNotEmpty) {
            actual[relativePath] = markers;
          }
        }

        final unexpected =
            actual.keys
                .where(
                  (path) => !_registeredProjectSettlementStatusWriteFiles
                      .containsKey(path),
                )
                .toList()
              ..sort();
        final missing =
            _registeredProjectSettlementStatusWriteFiles.keys
                .where((path) => !actual.containsKey(path))
                .toList()
              ..sort();

        expect(
          unexpected,
          isEmpty,
          reason: _unexpectedStatusWriteMessage(actual, unexpected),
        );
        expect(
          missing,
          isEmpty,
          reason: _missingStatusWriteMessage(actual, missing),
        );
      },
    );
  });
}

const _settlementStatusStrategy = _SettlementStatusStrategy(
  projectStatusIsCloudPushBlocker: true,
  projectWriteOffAloneIsInsufficient: true,
  recommendedProjectEntityType: 'project',
  recommendedProjectStatusOperation: 'update',
  requiresSameTransactionWithSettlementCluster: true,
  singleProjectStatusIsCovered: true,
  mergedProjectStatusIsCovered: true,
  mustCoverPaymentOnlySettlement: true,
  mustCoverStatusOnlyRevoke: true,
  timingDeleteCascadeRestoreIsCovered: true,
  externalWorkSettlementResetIsDeferred: true,
  mustCoverTimingDeleteCascadeRestore: true,
  mustCoverExternalWorkSettlementReset: true,
);

const _registeredProjectSettlementStatusWriteFiles = <String, String>{
  // Low-level project persistence. Future sync coverage should wrap this layer
  // with an enqueuer instead of deleting these executor APIs.
  'lib/data/repositories/project_repository.dart':
      'low-level projects status persistence',

  // Main settlement cluster. Single-project and merged settlement status writes
  // are sync-covered here; ExternalWork status reset remains deferred outside
  // this repository.
  'lib/infrastructure/local/account/local_project_settlement_repository.dart':
      'single and merged project settlement status writes',

  // Shared timing impact helper that restores settled projects to active when
  // timing edits/deletes invalidate previous settlement status.
  'lib/infrastructure/local/account/project_settlement_impact_service.dart':
      'timing impact status restore helper',

  // Timing save uses ProjectSettlementImpactService inside the save transaction.
  'lib/infrastructure/local/timing/local_save_timing_record_with_impact_use_case.dart':
      'timing edit status restore transaction entry',

  // Timing delete deletes write-offs and restores project status in the same
  // delete transaction, then enqueues ProjectWriteOff delete and Project update.
  'lib/infrastructure/local/timing/local_delete_timing_record_with_impact_use_case.dart':
      'timing delete cascade sync-covered transaction entry',

  // External work relink is a deferred sync coverage path. It resets settlement
  // status and write-offs today, so future Project.status sync must cover it.
  'lib/data/repositories/external_work_record_repository.dart':
      'external work settlement reset deferred coverage path',

  // Migration/schema backfill is not a production write path. It remains an
  // explicit exemption so it is not mistaken for sync-covered business logic.
  'lib/data/db/migrations/project_identity_migration.dart':
      'migration project status backfill exemption',
};

final _settledStatusWritePattern = RegExp(
  r'status\s*:\s*ProjectStatus\.settled',
);
final _activeStatusRestorePattern = RegExp(
  r'status\s*:\s*ProjectStatus\.active[\s\S]{0,280}'
  r'(settledAt\s*:\s*null|settledSnapshot\s*:\s*null)',
);
final _projectRepositoryStatusMapPattern = RegExp(
  r"""['"]status['"]\s*:\s*project\.status\.name""",
);
final _projectTableUpdatePattern = RegExp(
  r'\.\s*update\s*\(\s*(sqfliteprojectrepository\.table|projects)\b'
  r'[\s\S]{0,420}(status|settled_at|settled_snapshot)',
);
final _projectRawSqlUpdatePattern = RegExp(
  r'(rawupdate|execute)\s*\(\s*update\s+projects\b'
  r'[\s\S]{0,420}(status|settled_at|settled_snapshot)',
);

List<String> _projectSettlementStatusWriteMarkers(String source) {
  final normalized = _normalizeSource(source);
  final markers = <String>{};

  if (source.contains('restoreActiveWithExecutor(')) {
    markers.add('restoreActiveWithExecutor');
  }
  if (source.contains('applyRevocations(') &&
      source.contains('ProjectSettlementImpactReason.')) {
    markers.add('ProjectSettlementImpactService.applyRevocations');
  }
  if (_settledStatusWritePattern.hasMatch(source)) {
    markers.add('ProjectStatus.settled write');
  }
  if (_activeStatusRestorePattern.hasMatch(source)) {
    markers.add('ProjectStatus.active settlement restore');
  }
  if (_projectRepositoryStatusMapPattern.hasMatch(source)) {
    markers.add('project repository status map write');
  }
  if (_projectTableUpdatePattern.hasMatch(normalized)) {
    markers.add('projects table status update');
  }
  if (_projectRawSqlUpdatePattern.hasMatch(normalized)) {
    markers.add('raw projects status SQL update');
  }

  return markers.toList()..sort();
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

String _normalizeSource(String source) {
  return source
      .toLowerCase()
      .replaceAll('"', '')
      .replaceAll("'", '')
      .replaceAll('`', '');
}

void _expectAllContains(String source, List<String> snippets) {
  for (final snippet in snippets) {
    expect(source, contains(snippet), reason: 'Missing snippet: $snippet');
  }
}

void _expectInOrder(String source, List<String> snippets) {
  var cursor = 0;
  for (final snippet in snippets) {
    final index = source.indexOf(snippet, cursor);
    expect(
      index,
      isNonNegative,
      reason: 'Missing ordered snippet after offset $cursor: $snippet',
    );
    cursor = index + snippet.length;
  }
}

String _sliceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing slice start: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing slice end: $end');
  return source.substring(startIndex, endIndex);
}

String _unexpectedStatusWriteMessage(
  Map<String, List<String>> actual,
  List<String> unexpected,
) {
  if (unexpected.isEmpty) {
    return '';
  }

  final details = unexpected
      .map((path) => '- $path: ${actual[path]!.join(', ')}')
      .join('\n');
  return '''
Unexpected project settlement status write path(s):
$details

Project.status/settled_at/settled_snapshot mutations are Cloud-push blockers.
Register intentional restore/migration/deferred paths in this invariant, or
route production settlement status changes through ProjectSyncEnqueuer in the
same transaction as the settlement cluster.
''';
}

String _missingStatusWriteMessage(
  Map<String, List<String>> actual,
  List<String> missing,
) {
  if (missing.isEmpty) {
    return '';
  }

  final known = actual.entries
      .map((entry) => '- ${entry.key}: ${entry.value.join(', ')}')
      .join('\n');
  final missingDetails = missing
      .map(
        (path) =>
            '- $path: ${_registeredProjectSettlementStatusWriteFiles[path]}',
      )
      .join('\n');
  return '''
Registered project settlement status write path(s) were not detected:
$missingDetails

Detected paths:
$known

If a path was intentionally removed, update this executable strategy inventory
and keep the Project.status Cloud-push gap explicit.
''';
}

class _SettlementStatusStrategy {
  const _SettlementStatusStrategy({
    required this.projectStatusIsCloudPushBlocker,
    required this.projectWriteOffAloneIsInsufficient,
    required this.recommendedProjectEntityType,
    required this.recommendedProjectStatusOperation,
    required this.requiresSameTransactionWithSettlementCluster,
    required this.singleProjectStatusIsCovered,
    required this.mergedProjectStatusIsCovered,
    required this.mustCoverPaymentOnlySettlement,
    required this.mustCoverStatusOnlyRevoke,
    required this.timingDeleteCascadeRestoreIsCovered,
    required this.externalWorkSettlementResetIsDeferred,
    required this.mustCoverTimingDeleteCascadeRestore,
    required this.mustCoverExternalWorkSettlementReset,
  });

  final bool projectStatusIsCloudPushBlocker;
  final bool projectWriteOffAloneIsInsufficient;
  final String recommendedProjectEntityType;
  final String recommendedProjectStatusOperation;
  final bool requiresSameTransactionWithSettlementCluster;
  final bool singleProjectStatusIsCovered;
  final bool mergedProjectStatusIsCovered;
  final bool mustCoverPaymentOnlySettlement;
  final bool mustCoverStatusOnlyRevoke;
  final bool timingDeleteCascadeRestoreIsCovered;
  final bool externalWorkSettlementResetIsDeferred;
  final bool mustCoverTimingDeleteCascadeRestore;
  final bool mustCoverExternalWorkSettlementReset;
}
