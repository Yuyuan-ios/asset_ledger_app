import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../data/repositories/account_payment_repository.dart';
import '../../data/repositories/account_project_merge_repository.dart';
import '../../data/repositories/external_work_record_repository.dart';
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
  TimingDeleteProviders._({required this.deleteUseCase, required this.providers});

  final DeleteTimingRecordWithImpactUseCase deleteUseCase;
  final List<SingleChildWidget> providers;

  factory TimingDeleteProviders.build() {
    final deleteUseCase = LocalDeleteTimingRecordWithImpactUseCase(
      timingRepository: SqfliteTimingRepository(),
      paymentRepository: SqfliteAccountPaymentRepository(),
      mergeRepository: SqfliteAccountProjectMergeRepository(),
      externalWorkRecordRepository: SqfliteExternalWorkRecordRepository(),
      writeOffRepository: SqfliteProjectWriteOffRepository(),
      projectRepository: SqfliteProjectRepository(),
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
