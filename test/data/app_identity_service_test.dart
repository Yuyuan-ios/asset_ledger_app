import 'package:flutter_test/flutter_test.dart';

import 'package:asset_ledger/app/identity/app_identity_service.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/core/operations/operation_access_control.dart';

void main() {
  group('AppIdentityService', () {
    test('currentActorContext returns owner actorType', () {
      final ctx = AppIdentityService.instance.currentActorContext();
      expect(
        ctx.actorType,
        OperationActorType.owner,
        reason: 'device owner session type must be owner',
      );
    });

    test('actorId is non-null UUID format', () {
      final ctx = AppIdentityService.instance.currentActorContext();
      expect(ctx.actorId, isNotNull, reason: 'actorId must not be null');

      final actorId = ctx.actorId!;
      // UUID regex: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
      final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      expect(
        actorId,
        matches(uuidPattern),
        reason: 'actorId must be a valid UUID format',
      );
    });

    test('sessionId defaults to null', () {
      final ctx = AppIdentityService.instance.currentActorContext();
      expect(
        ctx.sessionId,
        isNull,
        reason: 'local device sessionId should be null by default',
      );
    });

    test('singleton returns same ownerId on repeated calls', () {
      final ctx1 = AppIdentityService.instance.currentActorContext();
      final ctx2 = AppIdentityService.instance.currentActorContext();
      expect(
        ctx1.actorId,
        ctx2.actorId,
        reason: 'singleton must return the same ownerId for same session',
      );
    });

    test('currentDeviceId reuses the persisted app identity', () {
      final service = AppIdentityService.instance;
      expect(
        service.currentDeviceId,
        service.currentActorContext().actorId,
        reason: 'sync device registration must reuse app_identity',
      );
    });

    test('ActorContext structure aligns with core model', () {
      final ctx = AppIdentityService.instance.currentActorContext();
      // Verify it's a valid ActorContext that can be used in preview flow
      expect(
        ctx,
        isA<ActorContext>(),
        reason: 'must return a valid ActorContext instance',
      );
      expect(
        ctx.actorType.wireName,
        'owner',
        reason: 'wireName must be owner for data/audit compatibility',
      );
    });
  });
}
