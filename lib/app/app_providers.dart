import 'package:provider/single_child_widget.dart';

import '../features/account/state/account_payment_store.dart';
import '../features/account/state/account_store.dart';
import '../features/account/state/project_rate_store.dart';
import '../features/device/state/device_store.dart';
import '../features/fuel/state/fuel_store.dart';
import '../features/maintenance/state/maintenance_store.dart';
import '../features/timing/state/timing_external_work_store.dart';
import '../features/timing/state/timing_store.dart';
import 'providers/account_merge_providers.dart';
import 'providers/device_fleet_providers.dart';
import 'providers/external_work_providers.dart';
import 'providers/identity_providers.dart';
import 'providers/project_providers.dart';
import 'providers/timing_delete_providers.dart';
import 'providers/timing_providers.dart';
import 'providers/timing_save_providers.dart';

/// Aggregates the per-domain composition slices into a single bundle.
/// Each slice owns construction of its own instances and providers;
/// this root only composes them.
class AppProviders {
  static AppProviderBundle build() {
    final deviceFleet = DeviceFleetProviders.build();
    final identity = IdentityProviders.build();
    final project = ProjectProviders.build();
    final timing = TimingProviders.build(
      projectResolver: project.projectResolver,
    );
    // R5.25-Hardening: thread the persisted owner ActorContext (resolved by
    // IdentityProviders from AppIdentityService.currentActorContext) into
    // every write slice that enqueues sync_outbox payloads, so payload.actor.id
    // and entity_sync_meta.updated_by carry the persisted owner id instead of
    // falling back to ownerAppSyncActor.
    final accountMerge = AccountMergeProviders.build(
      actorContext: identity.actorContext,
    );
    final externalWork = ExternalWorkProviders.build(
      actorContext: identity.actorContext,
    );
    final timingDelete = TimingDeleteProviders.build(
      actorContext: identity.actorContext,
    );
    final timingSave = TimingSaveProviders.build(
      projectResolver: project.projectResolver,
      actorContext: identity.actorContext,
    );

    return AppProviderBundle(
      deviceStore: deviceFleet.deviceStore,
      timingStore: timing.timingStore,
      fuelStore: deviceFleet.fuelStore,
      maintenanceStore: deviceFleet.maintenanceStore,
      paymentStore: accountMerge.paymentStore,
      projectRateStore: accountMerge.projectRateStore,
      accountStore: accountMerge.accountStore,
      timingExternalWorkStore: externalWork.timingExternalWorkStore,
      providers: [
        ...deviceFleet.providers,
        ...identity.providers,
        ...project.providers,
        ...timing.providers,
        ...accountMerge.providers,
        ...externalWork.providers,
        ...timingDelete.providers,
        ...timingSave.providers,
      ],
    );
  }
}

class AppProviderBundle {
  final DeviceStore deviceStore;
  final TimingStore timingStore;
  final FuelStore fuelStore;
  final MaintenanceStore maintenanceStore;
  final AccountPaymentStore paymentStore;
  final ProjectRateStore projectRateStore;
  final AccountStore accountStore;
  final TimingExternalWorkStore timingExternalWorkStore;
  final List<SingleChildWidget> providers;

  const AppProviderBundle({
    required this.deviceStore,
    required this.timingStore,
    required this.fuelStore,
    required this.maintenanceStore,
    required this.paymentStore,
    required this.projectRateStore,
    required this.accountStore,
    required this.timingExternalWorkStore,
    required this.providers,
  });
}
