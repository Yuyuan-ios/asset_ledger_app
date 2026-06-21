import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// R5.25-Hardening: source-level invariant guarding that every production
/// write path is wired to a SyncActorProvider backed by AppIdentityService.
///
/// The runtime tests (`owner_actor_threading_sync_payload_test`,
/// `timing_owner_actor_threading_test`) verify the actor reaches the payload;
/// this file pins the *wiring*, so a future composition-root edit that drops
/// the threading regresses noisily instead of silently.
///
/// Rules enforced:
/// 1. `lib/infrastructure/sync/sync_actor.dart` declares the
///    `SyncActorProvider` typedef and keeps `ownerAppSyncActor` documented
///    as a legacy/test fallback (NOT a production default).
/// 2. Every covered production write path declares a `SyncActorProvider?
///    actorProvider` constructor parameter and routes it through
///    `resolveSyncActor` / the enqueuer `actor:` parameter.
/// 3. Every composition-root slice that owns a covered write path takes an
///    `ActorContext? actorContext` parameter and threads it via
///    `actorProvider: ...` into the use case / repository.
/// 4. `lib/app/app_providers.dart` actually passes `identity.actorContext`
///    into every slice that owns a covered write path.
/// 5. The `ownerAppSyncActor` fallback identifier only appears inside the
///    sync helper itself (production code must not branch on it).
void main() {
  group('sync_actor helper seam', () {
    test('SyncActorProvider typedef is declared on the helper', () {
      final source = _read('lib/infrastructure/sync/sync_actor.dart');
      expect(
        source,
        contains('typedef SyncActorProvider = ActorContext Function();'),
        reason:
            'SyncActorProvider must exist as the typed injection seam shared '
            'by infrastructure-layer write paths.',
      );
      expect(
        source,
        contains('final ActorContext ownerAppSyncActor'),
        reason:
            'ownerAppSyncActor must remain the documented legacy/test fallback.',
      );
      expect(
        source,
        contains('R5.25-Hardening'),
        reason:
            'The helper must document the composition-root → write-path '
            'actor injection seam (R5.25-Hardening).',
      );
    });

    test('ownerAppSyncActor is only *executed* inside sync_actor.dart '
        '(doc-comments referencing the fallback are allowed)', () {
      final offenders = <String>[];
      for (final file in _libDartFiles()) {
        if (file.endsWith('lib/infrastructure/sync/sync_actor.dart')) {
          continue;
        }
        final source = _read(file);
        if (_containsOwnerAppSyncActorIdentifier(source)) {
          offenders.add(file);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Only sync_actor.dart may *evaluate* the ownerAppSyncActor '
            'fallback. Production code must depend on the threaded '
            'SyncActorProvider so a missing actor surfaces in '
            'payload.actor.id / updated_by instead of being silently '
            'masked. (Doc-comment references in production code are '
            'allowed for explaining the fallback.)',
      );
    });
  });

  group('production write paths declare actorProvider', () {
    const writePaths = <String>[
      'lib/infrastructure/local/timing/'
          'local_save_timing_record_with_impact_use_case.dart',
      'lib/infrastructure/local/timing/'
          'local_delete_timing_record_with_impact_use_case.dart',
      'lib/infrastructure/local/account/'
          'local_account_payment_write_use_case.dart',
      'lib/infrastructure/local/account/'
          'local_project_device_rate_write_use_case.dart',
      'lib/infrastructure/local/account/'
          'local_project_settlement_repository.dart',
      'lib/infrastructure/local/fuel/local_fuel_log_write_use_case.dart',
      'lib/infrastructure/local/maintenance/'
          'local_maintenance_record_write_use_case.dart',
      'lib/data/repositories/external_work_record_repository.dart',
      'lib/data/share/jztshare/project_external_work_importer.dart',
    ];

    for (final path in writePaths) {
      test('$path declares SyncActorProvider? actorProvider', () {
        final source = _read(path);
        expect(
          source,
          contains('SyncActorProvider? actorProvider'),
          reason:
              '$path must accept a SyncActorProvider so the composition root '
              'can thread the persisted owner ActorContext.',
        );
        expect(source, contains("import '"));
        expect(
          source.contains('sync_actor.dart'),
          isTrue,
          reason:
              '$path must import sync_actor.dart (SyncActorProvider typedef + '
              'resolveSyncActor / syncActorPayload helpers).',
        );
        expect(
          source,
          contains('_actorProvider'),
          reason:
              '$path must persist the provider as a field so each write call '
              'evaluates it (sessionId / future delegated scope may change).',
        );
      });
    }

    test(
      'timing save/delete inline outbox uses resolveSyncActor(provider call)',
      () {
        final save = _read(
          'lib/infrastructure/local/timing/'
          'local_save_timing_record_with_impact_use_case.dart',
        );
        final del = _read(
          'lib/infrastructure/local/timing/'
          'local_delete_timing_record_with_impact_use_case.dart',
        );
        final timingEnqueuer = _read(
          'lib/infrastructure/local/timing/timing_record_sync_enqueuer.dart',
        );
        // Save: evaluates the provider once, then shares that actor across the
        // timing row and any project restore rows in the same transaction group.
        expect(
          save,
          contains('final actor = _actorProvider?.call();'),
          reason:
              'Timing save must evaluate the threaded SyncActorProvider at '
              'the write boundary, not use a hard-coded null.',
        );
        final saveActorPasses = 'actor: actor'.allMatches(save).length;
        expect(
          saveActorPasses,
          greaterThanOrEqualTo(2),
          reason:
              'Timing save must pass the same provider-resolved actor into '
              'the timing and project restore enqueue paths.',
        );
        expect(
          save,
          contains('_timingRecordSyncEnqueuer.enqueueUpdate('),
          reason:
              'Timing save must delegate row-level sync payload writes through '
              'the timing enqueuer.',
        );
        expect(save, contains('_timingRecordSyncEnqueuer.enqueueCreate('));
        // Delete: passes the actor through to _enqueueSyncForDeletedRecord and
        // the cascade enqueuers in the same transaction.
        expect(
          del,
          contains('_actorProvider?.call()'),
          reason:
              'Timing delete cascade must evaluate the provider so every '
              'enqueue (writeOff / project / external work / timing) carries '
              'the same actor.',
        );
        expect(
          del,
          contains('_timingRecordSyncEnqueuer.enqueueDelete('),
          reason:
              'Timing delete must delegate row-level sync payload writes '
              'through the timing enqueuer.',
        );
        expect(
          timingEnqueuer,
          contains('resolveSyncActor(actor)'),
          reason:
              'Timing enqueuer must wrap the provider-resolved actor through '
              'resolveSyncActor, preserving the legacy fallback.',
        );
        expect(
          timingEnqueuer,
          contains('syncActorPayload(resolvedActor)'),
          reason:
              'Timing enqueuer must carry the resolved actor into the payload.',
        );
        expect(
          timingEnqueuer,
          contains('updatedBy: resolvedActor.actorId'),
          reason:
              'Timing enqueuer must mirror the resolved actor into metadata.',
        );
      },
    );
  });

  group('composition-root slices thread the persisted owner actor', () {
    const compositionSlices = <String>[
      'lib/app/providers/account_merge_providers.dart',
      'lib/app/providers/device_fleet_providers.dart',
      'lib/app/providers/external_work_providers.dart',
      'lib/app/providers/timing_delete_providers.dart',
      'lib/app/providers/timing_save_providers.dart',
    ];

    for (final path in compositionSlices) {
      test('$path accepts an ActorContext and threads it into write paths', () {
        final source = _read(path);
        expect(
          source,
          contains('ActorContext'),
          reason:
              '$path must import / accept ActorContext from the identity slice.',
        );
        expect(
          source,
          contains('actorContext'),
          reason: '$path must take an actorContext build parameter.',
        );
        expect(
          source,
          contains('actorProvider'),
          reason:
              '$path must thread the actor through an actorProvider closure '
              'into use-case / repository constructors.',
        );
      });
    }

    test(
      'app_providers wires identity.actorContext into every covered slice',
      () {
        final source = _read('lib/app/app_providers.dart');
        for (final slice in const [
          'AccountMergeProviders.build',
          'DeviceFleetProviders.build',
          'ExternalWorkProviders.build',
          'TimingDeleteProviders.build',
          'TimingSaveProviders.build',
        ]) {
          expect(
            source,
            contains(slice),
            reason: 'app_providers must call $slice',
          );
        }
        // Each covered slice must receive actorContext: identity.actorContext.
        final passes = 'actorContext: identity.actorContext'
            .allMatches(source)
            .length;
        expect(
          passes,
          greaterThanOrEqualTo(5),
          reason:
              'app_providers must thread identity.actorContext into '
              'AccountMergeProviders / DeviceFleetProviders / '
              'ExternalWorkProviders / TimingDeleteProviders / '
              'TimingSaveProviders.',
        );
      },
    );
  });
}

String _read(String relativePath) {
  return File('${Directory.current.path}/$relativePath').readAsStringSync();
}

/// Strips Dart `//` line comments and `/* */` block comments, then asks
/// whether the surviving source contains the `ownerAppSyncActor` identifier.
/// Comments are allowed to reference the fallback for documentation.
bool _containsOwnerAppSyncActorIdentifier(String source) {
  final stripped = StringBuffer();
  var i = 0;
  while (i < source.length) {
    if (i + 1 < source.length && source[i] == '/' && source[i + 1] == '/') {
      // Skip to end of line.
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (i + 1 < source.length && source[i] == '/' && source[i + 1] == '*') {
      i += 2;
      while (i + 1 < source.length &&
          !(source[i] == '*' && source[i + 1] == '/')) {
        i++;
      }
      i = (i + 1 < source.length) ? i + 2 : source.length;
      continue;
    }
    stripped.write(source[i]);
    i++;
  }
  return stripped.toString().contains('ownerAppSyncActor');
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
