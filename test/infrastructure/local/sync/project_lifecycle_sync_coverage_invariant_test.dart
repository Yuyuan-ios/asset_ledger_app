import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// R5.26-A: source-level invariant that locks Project full lifecycle outbox
/// coverage.
///
/// - ProjectSyncEnqueuer now covers create / update / delete (not update-only).
/// - The production project CREATE path (timing-save resolve-or-create) enqueues
///   a project create outbox in the same transaction.
/// - There is NO production project DELETE path today, so enqueueDelete stays
///   unwired (exercised by tests only). This invariant pins that fact so a
///   future reviewer does not mistake the unwired delete for a coverage gap,
///   and so a newly-added project row-delete must consciously wire the outbox.
void main() {
  group('ProjectSyncEnqueuer covers the full lifecycle', () {
    final enqueuer = _read(
      'lib/infrastructure/local/account/project_sync_enqueuer.dart',
    );

    test('declares enqueueCreate / enqueueUpdate / enqueueDelete', () {
      expect(enqueuer, contains('Future<void> enqueueCreate('));
      expect(enqueuer, contains('Future<void> enqueueUpdate('));
      expect(enqueuer, contains('Future<void> enqueueDelete('));
    });

    test('each operation maps to the correct pending meta status', () {
      // create → pendingUpload, update → pendingUpdate, delete → pendingDelete.
      expect(enqueuer, contains("operation: 'create'"));
      expect(enqueuer, contains('status: SyncStatus.pendingUpload'));
      expect(enqueuer, contains("operation: 'update'"));
      expect(enqueuer, contains('status: SyncStatus.pendingUpdate'));
      expect(enqueuer, contains("operation: 'delete'"));
      expect(enqueuer, contains('status: SyncStatus.pendingDelete'));
    });

    test('payload carries schema version + actor + clean record; meta '
        'updated_by from the actor (R5.25 contract)', () {
      expect(
        enqueuer,
        contains("'payload_schema_version': kSyncPayloadSchemaVersion"),
      );
      expect(enqueuer, contains("'actor': syncActorPayload(resolvedActor)"));
      expect(enqueuer, contains("'record': project.toMap()"));
      expect(enqueuer, contains('updatedBy: resolvedActor.actorId'));
      // version/actor are top-level, never inside the business record.
      final versionIdx =
          enqueuer.indexOf("'payload_schema_version':");
      final recordIdx = enqueuer.indexOf("'record':");
      expect(versionIdx, greaterThanOrEqualTo(0));
      expect(recordIdx, greaterThan(versionIdx));
    });

    test('class doc no longer claims update-only / "does not claim '
        'lifecycle coverage"', () {
      expect(
        enqueuer.contains('does not claim'),
        isFalse,
        reason: 'R5.26-A added create/delete; the update-only caveat is stale.',
      );
      expect(enqueuer, contains('R5.26-A'));
    });
  });

  group('production project CREATE path is wired', () {
    final saveUseCase = _read(
      'lib/infrastructure/local/timing/'
      'local_save_timing_record_with_impact_use_case.dart',
    );

    test('timing-save resolve surfaces the created project and enqueues a '
        'project create outbox in the same cluster', () {
      // The resolver result carries the brand-new project ...
      expect(saveUseCase, contains('createdProject'));
      expect(saveUseCase, contains('result.created ? result.project : null'));
      // ... and a create outbox is enqueued (FK prerequisite, in a group).
      expect(saveUseCase, contains('_projectSyncEnqueuer.enqueueCreate('));
      expect(
        saveUseCase,
        contains('createdProject != null || settlementRevoked'),
        reason: 'a new project OR a revocation promotes the save to a cluster.',
      );
    });

    test('the create enqueue happens before the timing enqueue (causal FK '
        'order)', () {
      final createIdx = saveUseCase.indexOf('_projectSyncEnqueuer.enqueueCreate(');
      final timingIdx = saveUseCase.indexOf('_enqueueSyncForSavedRecord(');
      expect(createIdx, greaterThanOrEqualTo(0));
      expect(timingIdx, greaterThan(createIdx),
          reason: 'project create must be enqueued before the timing row.');
    });
  });

  group('no production project DELETE path (delete enqueuer stays unwired)', () {
    test('no lib file performs a row-level delete of the projects table', () {
      final offenders = <String>[];
      for (final file in _libDartFiles()) {
        final source = _read(file);
        if (_projectsRowDeletePattern.hasMatch(source)) {
          offenders.add(file);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'No business flow deletes a project row today, so '
            'ProjectSyncEnqueuer.enqueueDelete is intentionally not wired into '
            'production. If a real project delete/archive path is added, it '
            'MUST enqueue a project delete outbox in the same transaction and '
            'this invariant must be updated together.\n${offenders.join('\n')}',
      );
    });

    test('enqueueDelete is not called on any ProjectSyncEnqueuer in lib', () {
      // Precisely match `projectSyncEnqueuer.enqueueDelete(` /
      // `_projectSyncEnqueuer.enqueueDelete(` — NOT the write-off / external
      // work enqueuers' own enqueueDelete (those identifiers do not contain the
      // exact `projectSyncEnqueuer` token).
      final callers = <String>[];
      for (final file in _libDartFiles()) {
        if (file.endsWith(
          'lib/infrastructure/local/account/project_sync_enqueuer.dart',
        )) {
          continue; // the declaration itself
        }
        if (_projectEnqueuerDeleteCallPattern.hasMatch(_read(file))) {
          callers.add(file);
        }
      }
      expect(
        callers,
        isEmpty,
        reason:
            'ProjectSyncEnqueuer.enqueueDelete must remain unwired until a real '
            'project delete path exists. Wiring it without a business delete '
            'would be dead code.\n${callers.join('\n')}',
      );
    });
  });
}

String _read(String relativePath) {
  return File('${Directory.current.path}/$relativePath').readAsStringSync();
}

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

/// Matches a row-level delete targeting the `projects` table (not
/// `project_write_offs` / `project_device_rates` / `project_*`), via either
/// `executor.delete('projects', ...)` / `SqfliteProjectRepository.table` or a
/// raw `DELETE FROM projects`. DROP TABLE / migration table rebuilds are not
/// matched (those are schema operations, not business row deletes).
final RegExp _projectsRowDeletePattern = RegExp(
  r"(?:\.delete\(\s*'projects'"
  r"|\.delete\(\s*SqfliteProjectRepository\.table"
  r"|rawDelete\(\s*'?\s*DELETE\s+FROM\s+projects(?![A-Za-z0-9_])"
  r"|DELETE\s+FROM\s+projects(?![A-Za-z0-9_]))",
  caseSensitive: false,
);

/// Matches `enqueueDelete(` invoked on a ProjectSyncEnqueuer field/param
/// (`projectSyncEnqueuer` / `_projectSyncEnqueuer`). The leading
/// non-identifier lookbehind keeps `_projectWriteOffSyncEnqueuer.enqueueDelete`
/// and `_externalWorkSyncEnqueuer.enqueueDelete` out (those tokens do not
/// contain the exact `projectSyncEnqueuer` substring anyway).
final RegExp _projectEnqueuerDeleteCallPattern = RegExp(
  r'(?<![A-Za-z0-9_])_?[Pp]rojectSyncEnqueuer\s*\.\s*enqueueDelete\s*\(',
);
