import 'package:asset_ledger/app/app_providers.dart';
import 'package:asset_ledger/app/providers/timing_save_providers.dart';
import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/core/operations/operation_transaction_runner.dart';
import 'package:asset_ledger/data/repositories/operation_audit_log_repository.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/services/project_resolver.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_command.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_operation_confirm_adapter.dart';
import 'package:asset_ledger/features/timing/operations/save_timing_record_preview_service.dart';
import 'package:asset_ledger/features/timing/use_cases/save_timing_record_use_case.dart';
import 'package:asset_ledger/features/timing/use_cases/save_timing_record_with_impact_use_case.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'TimingSaveProviders wires token-aware SaveTimingRecordUseCase and legacy path',
    (tester) async {
      final actorContext = ActorContext(
        actorType: OperationActorType.owner,
        actorId: 'owner-provider-test',
      );
      final bundle = TimingSaveProviders.build(
        projectResolver: ProjectResolver(
          projectRepository: SqfliteProjectRepository(),
        ),
        actorContext: actorContext,
      );

      late SaveTimingRecordUseCase saveUseCase;
      late SaveTimingRecordWithImpactUseCase legacyUseCase;
      late SaveTimingRecordOperationCommand command;
      late SaveTimingRecordPreviewService previewService;
      late SaveTimingRecordOperationConfirmAdapter confirmAdapter;
      late OperationAuditLogRepository auditRepository;
      late OperationTransactionRunner transactionRunner;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MultiProvider(
            providers: bundle.providers,
            child: Builder(
              builder: (context) {
                saveUseCase = context.read<SaveTimingRecordUseCase>();
                legacyUseCase = context
                    .read<SaveTimingRecordWithImpactUseCase>();
                command = context.read<SaveTimingRecordOperationCommand>();
                previewService = context.read<SaveTimingRecordPreviewService>();
                confirmAdapter = context
                    .read<SaveTimingRecordOperationConfirmAdapter>();
                auditRepository = context.read<OperationAuditLogRepository>();
                transactionRunner = context.read<OperationTransactionRunner>();
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(saveUseCase, same(bundle.saveUseCase));
      expect(legacyUseCase, same(bundle.legacySaveUseCase));
      expect(command, same(bundle.operationCommand));
      expect(previewService, same(bundle.previewService));
      expect(confirmAdapter, same(bundle.confirmAdapter));
      expect(auditRepository, same(bundle.auditRepository));
      expect(transactionRunner, same(bundle.transactionRunner));

      expect(saveUseCase.previewService, same(previewService));
      expect(saveUseCase.confirmAdapter, same(confirmAdapter));
      expect(saveUseCase.actorContext, same(actorContext));
      expect(saveUseCase.analyzer, isNotNull);
      expect(command.actorContext, same(actorContext));
      expect(previewService.tokenIssuer, isNotNull);
      expect(previewService.tokenIssuer?.tokenTtl, const Duration(minutes: 5));
    },
  );

  testWidgets(
    'AppProviders exposes owner ActorContext and token-aware save use case',
    (tester) async {
      final bundle = AppProviders.build();

      late ActorContext actorContext;
      late SaveTimingRecordUseCase saveUseCase;
      late SaveTimingRecordPreviewService previewService;
      late SaveTimingRecordOperationConfirmAdapter confirmAdapter;
      late SaveTimingRecordOperationCommand command;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MultiProvider(
            providers: bundle.providers,
            child: Builder(
              builder: (context) {
                actorContext = context.read<ActorContext>();
                saveUseCase = context.read<SaveTimingRecordUseCase>();
                previewService = context.read<SaveTimingRecordPreviewService>();
                confirmAdapter = context
                    .read<SaveTimingRecordOperationConfirmAdapter>();
                command = context.read<SaveTimingRecordOperationCommand>();
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(actorContext.actorType, OperationActorType.owner);
      expect(actorContext.actorId, isNotNull);
      expect(actorContext.sessionId, isNull);
      expect(saveUseCase.actorContext, same(actorContext));
      expect(saveUseCase.previewService, same(previewService));
      expect(saveUseCase.confirmAdapter, same(confirmAdapter));
      expect(saveUseCase.analyzer, isNotNull);
      expect(command.actorContext, same(actorContext));
    },
  );
}
