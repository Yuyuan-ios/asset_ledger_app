import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../data/repositories/account_project_merge_repository.dart';
import '../../data/repositories/device_repository.dart';
import '../../data/repositories/project_rate_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/operation_audit_log_repository.dart';
import '../../data/repositories/operation_token_repository.dart';
import '../../data/repositories/timing_calculation_history_repository.dart';
import '../../data/repositories/timing_repository.dart';
import '../../data/services/project_resolver.dart';
import '../../core/operations/operation_access_control.dart';
import '../../core/operations/operation_actor_type.dart';
import '../../core/operations/operation_transaction_runner.dart';
import '../../features/timing/operations/save_timing_record_operation_analyzer.dart';
import '../../features/timing/operations/save_timing_record_operation_command.dart';
import '../../features/timing/operations/save_timing_record_operation_confirm_adapter.dart';
import '../../features/timing/operations/save_timing_record_operation_preview_adapter.dart';
import '../../features/timing/operations/save_timing_record_preview_service.dart';
import '../../features/timing/operations/save_timing_record_preview_token_issuer.dart';
import '../../features/timing/state/timing_store.dart';
import '../../features/timing/use_cases/save_timing_record_use_case.dart';
import '../../features/timing/use_cases/save_timing_record_with_impact_use_case.dart';
import '../../infrastructure/local/account/project_settlement_impact_service.dart';
import '../../infrastructure/local/operations/local_operation_transaction_runner.dart';
import '../../infrastructure/local/timing/local_save_timing_record_with_impact_use_case.dart';

/// Timing-save composition slice: the cross-domain save-impact use case
/// (Step 3 of the 9.5 cleanup plan).
///
/// R4.1：正式生产接入 token-aware save 路径。
/// - [SaveTimingRecordUseCase] 默认注入 previewService / confirmAdapter / actorContext
/// - 保存路径走 executeWithToken()（previewWithToken → executeConfirmedWithToken）
/// - 保留旧 [SaveTimingRecordWithImpactUseCase] + [SaveTimingRecordOperationCommand]
///   供下游测试和后向兼容
class TimingSaveProviders {
  TimingSaveProviders._({
    required this.saveUseCase,
    required this.legacySaveUseCase,
    required this.operationCommand,
    required this.auditRepository,
    required this.transactionRunner,
    required this.previewService,
    required this.confirmAdapter,
    required this.providers,
  });

  final SaveTimingRecordUseCase saveUseCase;
  final SaveTimingRecordWithImpactUseCase legacySaveUseCase;
  final SaveTimingRecordOperationCommand operationCommand;
  final OperationAuditLogRepository auditRepository;
  final OperationTransactionRunner transactionRunner;
  final SaveTimingRecordPreviewService previewService;
  final SaveTimingRecordOperationConfirmAdapter confirmAdapter;
  final List<SingleChildWidget> providers;

  factory TimingSaveProviders.build({
    required ProjectResolver projectResolver,
    ActorContext? actorContext,
  }) {
    // --- 基础 repository（R1–R3） ---
    final projectRepository = SqfliteProjectRepository();
    final impactService = ProjectSettlementImpactService(
      projectRepository: projectRepository,
    );
    final timingRepository = SqfliteTimingRepository();
    final timingCalcHistoryRepository =
        SqfliteTimingCalculationHistoryRepository();
    final mergeRepository = SqfliteAccountProjectMergeRepository();
    final deviceRepository = SqfliteDeviceRepository();
    final projectRateRepository = SqfliteProjectRateRepository();
    final auditRepository = SqfliteOperationAuditLogRepository();
    final tokenRepository = SqfliteOperationTokenRepository();
    const transactionRunner = LocalOperationTransactionRunner();

    // --- actor 注入 ---
    final resolvedActorContext =
        actorContext ?? ActorContext(actorType: OperationActorType.owner);
    // R5.25-Hardening: thread the resolved owner ActorContext (from
    // AppIdentityService via IdentityProviders) into the sync-covered save
    // path so payload.actor.id and entity_sync_meta.updated_by carry the
    // persisted owner id instead of falling back to ownerAppSyncActor.
    ActorContext actorProvider() => resolvedActorContext;

    // --- 低层同步用例 ---
    final withImpact = LocalSaveTimingRecordWithImpactUseCase(
      timingRepository: timingRepository,
      timingCalculationHistoryRepository: timingCalcHistoryRepository,
      mergeRepository: mergeRepository,
      deviceRepository: deviceRepository,
      projectRateRepository: projectRateRepository,
      projectRepository: projectRepository,
      projectResolver: projectResolver,
      impactService: impactService,
      actorProvider: actorProvider,
    );

    // --- OperationCommand（R3 已支持 actorContext） ---
    final operationCommand = SaveTimingRecordOperationCommand(
      auditRepository: auditRepository,
      transactionRunner: transactionRunner,
      actorContext: resolvedActorContext,
    );

    // --- R4 token-aware 基础设施 ---
    final analyzer = SaveTimingRecordOperationAnalyzer(
      command: operationCommand,
      timingRepository: timingRepository,
      mergeRepository: mergeRepository,
      deviceRepository: deviceRepository,
      projectRateRepository: projectRateRepository,
      projectRepository: projectRepository,
    );
    final previewAdapter = SaveTimingRecordOperationPreviewAdapter(
      analyzer: analyzer,
    );
    final tokenIssuer = SaveTimingRecordPreviewTokenIssuer(
      tokenRepository: tokenRepository,
      tokenIdFactory: () => 'token-${DateTime.now().microsecondsSinceEpoch}',
      tokenTtl: const Duration(minutes: 5),
    );
    final previewService = SaveTimingRecordPreviewService(
      previewAdapter: previewAdapter,
      tokenIssuer: tokenIssuer,
    );
    final confirmAdapter = SaveTimingRecordOperationConfirmAdapter(
      analyzer: analyzer,
      command: operationCommand,
      auditRepository: auditRepository,
      tokenRepository: tokenRepository,
    );

    // --- 生产 SaveTimingRecordUseCase（R4.1：默认走 token-aware） ---
    final timingStore = TimingStore(timingRepository);
    final saveUseCase = SaveTimingRecordUseCase(
      timingStore: timingStore,
      withImpact: withImpact,
      command: operationCommand,
      analyzer: analyzer,
      previewService: previewService,
      confirmAdapter: confirmAdapter,
      actorContext: resolvedActorContext,
    );

    return TimingSaveProviders._(
      saveUseCase: saveUseCase,
      legacySaveUseCase: withImpact,
      operationCommand: operationCommand,
      auditRepository: auditRepository,
      transactionRunner: transactionRunner,
      previewService: previewService,
      confirmAdapter: confirmAdapter,
      providers: [
        Provider<OperationAuditLogRepository>.value(value: auditRepository),
        Provider<OperationTransactionRunner>.value(value: transactionRunner),
        Provider<SaveTimingRecordOperationCommand>.value(
          value: operationCommand,
        ),
        Provider<SaveTimingRecordWithImpactUseCase>.value(value: withImpact),
        Provider<SaveTimingRecordPreviewService>.value(value: previewService),
        Provider<SaveTimingRecordOperationConfirmAdapter>.value(
          value: confirmAdapter,
        ),
        Provider<SaveTimingRecordUseCase>.value(value: saveUseCase),
      ],
    );
  }
}
