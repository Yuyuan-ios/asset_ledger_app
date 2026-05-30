import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../data/repositories/account_project_merge_repository.dart';
import '../../data/repositories/device_repository.dart';
import '../../data/repositories/project_rate_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/operation_audit_log_repository.dart';
import '../../data/repositories/timing_calculation_history_repository.dart';
import '../../data/repositories/timing_repository.dart';
import '../../data/services/project_resolver.dart';
import '../../core/operations/operation_transaction_runner.dart';
import '../../features/timing/operations/save_timing_record_operation_command.dart';
import '../../features/timing/use_cases/save_timing_record_with_impact_use_case.dart';
import '../../infrastructure/local/account/project_settlement_impact_service.dart';
import '../../infrastructure/local/operations/local_operation_transaction_runner.dart';
import '../../infrastructure/local/timing/local_save_timing_record_with_impact_use_case.dart';

/// Timing-save composition slice: the cross-domain save-impact use case
/// (Step 3 of the 9.5 cleanup plan).
///
/// 与 [TimingDeleteProviders] 平行：构造一个事务化的保存计时入口，
/// 把"保存计时 + 解除合并 + 撤销结清"统一在同一个 sqflite 事务内执行。
class TimingSaveProviders {
  TimingSaveProviders._({
    required this.saveUseCase,
    required this.operationCommand,
    required this.auditRepository,
    required this.transactionRunner,
    required this.providers,
  });

  final SaveTimingRecordWithImpactUseCase saveUseCase;
  final SaveTimingRecordOperationCommand operationCommand;
  final OperationAuditLogRepository auditRepository;
  final OperationTransactionRunner transactionRunner;
  final List<SingleChildWidget> providers;

  factory TimingSaveProviders.build({
    required ProjectResolver projectResolver,
  }) {
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
    final auditRepository = SqfliteOperationAuditLogRepository();
    const transactionRunner = LocalOperationTransactionRunner();
    final operationCommand = SaveTimingRecordOperationCommand(
      auditRepository: auditRepository,
      transactionRunner: transactionRunner,
    );
    return TimingSaveProviders._(
      saveUseCase: saveUseCase,
      operationCommand: operationCommand,
      auditRepository: auditRepository,
      transactionRunner: transactionRunner,
      providers: [
        Provider<OperationAuditLogRepository>.value(value: auditRepository),
        Provider<OperationTransactionRunner>.value(value: transactionRunner),
        Provider<SaveTimingRecordOperationCommand>.value(
          value: operationCommand,
        ),
        Provider<SaveTimingRecordWithImpactUseCase>.value(value: saveUseCase),
      ],
    );
  }
}
