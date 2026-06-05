import '../../core/operations/operation_access_control.dart';
import '../../core/operations/operation_actor_type.dart';

/// R5.25: traceability metadata for `sync_outbox` payloads.
///
/// Every enqueued payload carries a top-level `payload_schema_version` and an
/// `actor` object so a future cloud sync can version the wire format and trace
/// who produced each change, without baking that into the business `record`.

/// Current sync payload wire-format version. Bump only on a real wire change.
const int kSyncPayloadSchemaVersion = 1;

/// Documented owner-app fallback actor used when a write path has not yet
/// threaded an explicit [ActorContext] into the sync chain.
///
/// This is NOT a silent default: every current production write is a
/// device-owner manual operation (consistent with the enqueuers' hardcoded
/// `source: 'owner_app'`), so the fallback is an `owner` actor. Its `actorId`
/// is null because the persisted device owner id is not yet threaded from the
/// composition root into the sync chain (deferred — see R5.25 report). The
/// `actor` parameter on the enqueuers lets callers/tests inject the real
/// ActorContext, and future driver/agent/MCP write paths will pass their own.
final ActorContext ownerAppSyncActor = ActorContext(
  actorType: OperationActorType.owner,
);

/// Returns [actor] when provided, otherwise the [ownerAppSyncActor] fallback.
ActorContext resolveSyncActor(ActorContext? actor) =>
    actor ?? ownerAppSyncActor;

/// Builds the top-level `actor` payload object. Always includes all three keys
/// (`session_id` may be null) so the wire shape is stable.
Map<String, Object?> syncActorPayload(ActorContext actor) {
  return {
    'type': actor.actorType.wireName,
    'id': actor.actorId,
    'session_id': actor.sessionId,
  };
}
