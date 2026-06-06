import '../../core/operations/operation_access_control.dart';
import '../../core/operations/operation_actor_type.dart';

/// R5.25: traceability metadata for `sync_outbox` payloads.
///
/// Every enqueued payload carries a top-level `payload_schema_version` and an
/// `actor` object so a future cloud sync can version the wire format and trace
/// who produced each change, without baking that into the business `record`.

/// Current sync payload wire-format version. Bump only on a real wire change.
const int kSyncPayloadSchemaVersion = 1;

/// R5.25-Hardening: composition-root → write-path actor injection seam.
///
/// Production write paths (account_payment / project / project_write_off /
/// external_work / timing_record) take a [SyncActorProvider] from the
/// composition root. The provider returns the device-owner [ActorContext]
/// resolved from `AppIdentityService.instance.currentActorContext()`, so
/// `payload.actor.id` and `entity_sync_meta.updated_by` carry the persisted
/// owner id (R5.21) instead of falling back to the null-id helper below.
///
/// Tests inject a fixed [ActorContext] via the same seam.
///
/// Kept as a typedef (not a class) so it can be passed through constructors
/// without forcing infrastructure code to import app-layer identity. The
/// signature is synchronous because [AppIdentityService.currentActorContext]
/// is synchronous after the one-shot `initialize()` in `main.dart`.
typedef SyncActorProvider = ActorContext Function();

/// Documented owner-app fallback actor used as a legacy/test bridge when no
/// [SyncActorProvider] has been threaded into a write path.
///
/// NOT a silent production default: the production composition root (see
/// `lib/app/providers/*`) threads an `AppIdentityService`-backed provider into
/// every covered write path so the `actor.id` reaches the outbox payload and
/// `entity_sync_meta.updated_by`. This fallback exists for:
/// - legacy tests that pre-date the R5.25-Hardening provider seam,
/// - the rare deferred path that has not yet been threaded.
///
/// The fallback keeps `actorType=owner` because every current production write
/// is a device-owner manual operation (consistent with the enqueuers'
/// hardcoded `source: 'owner_app'`); `actorId` is intentionally null so a
/// production regression that drops the provider is visible in the payload
/// and meta rows (and caught by
/// `production_owner_actor_provider_invariant_test`).
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
