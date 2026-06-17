import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../core/operations/operation_access_control.dart';
import '../../data/repositories/account_payment_repository.dart';
import '../../data/repositories/account_project_merge_repository.dart';
import '../../data/repositories/device_repository.dart';
import '../../data/repositories/external_work_record_repository.dart';
import '../../data/repositories/fuel_repository.dart';
import '../../data/repositories/maintenance_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/project_write_off_repository.dart';
import '../../data/repositories/timing_repository.dart';
import '../../features/timing/use_cases/delete_timing_record_with_impact_use_case.dart';
import '../../infrastructure/local/timing/local_delete_timing_record_with_impact_use_case.dart';

/// Timing-delete composition slice: the cross-domain delete-impact use case.
///
/// Repositories are stateless wrappers over the shared [AppDatabase] singleton,
/// so this slice constructs its own instances rather than threading them across
/// the timing / account / external-work slices.
class TimingDeleteProviders {
  TimingDeleteProviders._({
    required this.deleteUseCase,
    required this.providers,
  });

  final DeleteTimingRecordWithImpactUseCase deleteUseCase;
  final List<SingleChildWidget> providers;

  factory TimingDeleteProviders.build({ActorContext? actorContext}) {
    // R5.25-Hardening: thread the persisted owner ActorContext into both the
    // delete use case (timing_record delete + cascade enqueues) and the
    // external work repository it consults (which itself enqueues on its own
    // mutation paths). The repo here is local to this slice — see
    // ExternalWorkProviders for the slice that wires the *shared* repo.
    final actorProvider = actorContext == null ? null : () => actorContext;
    final deleteUseCase = LocalDeleteTimingRecordWithImpactUseCase(
      timingRepository: SqfliteTimingRepository(),
      paymentRepository: SqfliteAccountPaymentRepository(),
      mergeRepository: SqfliteAccountProjectMergeRepository(),
      deviceRepository: SqfliteDeviceRepository(),
      externalWorkRecordRepository: SqfliteExternalWorkRecordRepository(
        actorProvider: actorProvider,
      ),
      fuelRepository: SqfliteFuelRepository(),
      maintenanceRepository: SqfliteMaintenanceRepository(),
      writeOffRepository: SqfliteProjectWriteOffRepository(),
      projectRepository: SqfliteProjectRepository(),
      actorProvider: actorProvider,
    );
    return TimingDeleteProviders._(
      deleteUseCase: deleteUseCase,
      providers: [
        Provider<DeleteTimingRecordWithImpactUseCase>.value(
          value: deleteUseCase,
        ),
      ],
    );
  }
}
