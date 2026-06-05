import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// R5.25: every production outbox payload construction site must include the
/// top-level `payload_schema_version` and `actor` fields. This source-level
/// invariant guards against a new/changed enqueue path silently omitting them.
void main() {
  // All known sites that build a sync_outbox payload map.
  const payloadSites = <String>[
    'lib/infrastructure/local/account/account_payment_sync_enqueuer.dart',
    'lib/infrastructure/local/account/project_sync_enqueuer.dart',
    'lib/infrastructure/local/account/project_write_off_sync_enqueuer.dart',
    'lib/infrastructure/local/timing/external_work_sync_enqueuer.dart',
    'lib/infrastructure/local/timing/'
        'local_save_timing_record_with_impact_use_case.dart',
    'lib/infrastructure/local/timing/'
        'local_delete_timing_record_with_impact_use_case.dart',
  ];

  for (final path in payloadSites) {
    test('$path includes payload_schema_version and actor in its payload', () {
      final source = _read(path);

      expect(
        source.contains("'payload_schema_version': kSyncPayloadSchemaVersion"),
        isTrue,
        reason: '$path payload must carry payload_schema_version (R5.25).',
      );
      expect(
        source.contains("'actor': syncActorPayload("),
        isTrue,
        reason: '$path payload must carry the actor object (R5.25).',
      );
      // updated_by traceability is written from the resolved actor id.
      expect(
        source.contains('updatedBy: resolvedActor.actorId') ||
            source.contains('updatedBy: resolvedActor.actorId,'),
        isTrue,
        reason: '$path must write entity_sync_meta.updated_by from the actor.',
      );
      // The version/actor are top-level keys, placed before the business
      // `record`, never inside it.
      final versionIdx = source.indexOf("'payload_schema_version':");
      final recordIdx = source.indexOf("'record':");
      expect(versionIdx, greaterThanOrEqualTo(0));
      expect(recordIdx, greaterThan(versionIdx));
    });
  }

  test('sync_actor helper pins schema version to 1', () {
    final helper = _read('lib/infrastructure/sync/sync_actor.dart');
    expect(helper, contains('const int kSyncPayloadSchemaVersion = 1;'));
    expect(helper, contains("'type': actor.actorType.wireName"));
    expect(helper, contains("'id': actor.actorId"));
    expect(helper, contains("'session_id': actor.sessionId"));
  });
}

String _read(String relativePath) {
  return File('${Directory.current.path}/$relativePath').readAsStringSync();
}
