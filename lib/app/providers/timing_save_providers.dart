import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../data/repositories/account_project_merge_repository.dart';
import '../../data/repositories/device_repository.dart';
import '../../data/repositories/project_rate_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/timing_calculation_history_repository.dart';
import '../../data/repositories/timing_repository.dart';
import '../../data/services/project_resolver.dart';
import '../../features/timing/use_cases/save_timing_record_with_impact_use_case.dart';
import '../../infrastructure/local/account/project_settlement_impact_service.dart';
import '../../infrastructure/local/timing/local_save_timing_record_with_impact_use_case.dart';

/// Timing-save composition slice: the cross-domain save-impact use case
/// (Step 3 of the 9.5 cleanup plan).
///
/// 与 [TimingDeleteProviders] 平行：构造一个事务化的保存计时入口，
/// 把"保存计时 + 解除合并 + 撤销结清"统一在同一个 sqflite 事务内执行。
class TimingSaveProviders {
  TimingSaveProviders._({required this.saveUseCase, required this.providers});

  final SaveTimingRecordWithImpactUseCase saveUseCase;
  final List<SingleChildWidget> providers;

  factory TimingSaveProviders.build({required ProjectResolver projectResolver}) {
    final projectRepository = SqfliteProjectRepository();
    final impactService = ProjectSettlementImpactService(
      projectRepository: projectRepository,
    );
    final saveUseCase = LocalSaveTimingRecordWithImpactUseCase(
      timingRepository: SqfliteTimingRepository(),
      timingCalculationHistoryRepository:
          SqfliteTimingCalculationHistoryRepository(),
      mergeRepository: SqfliteAccountProjectMergeRepository(),
      deviceRepository: SqfliteDeviceRepository(),
      projectRateRepository: SqfliteProjectRateRepository(),
      projectResolver: projectResolver,
      impactService: impactService,
    );
    return TimingSaveProviders._(
      saveUseCase: saveUseCase,
      providers: [
        Provider<SaveTimingRecordWithImpactUseCase>.value(value: saveUseCase),
      ],
    );
  }
}
