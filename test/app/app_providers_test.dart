import 'package:asset_ledger/app/app_providers.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/data/repositories/account_project_merge_repository.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/fuel_repository.dart';
import 'package:asset_ledger/data/repositories/maintenance_repository.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/repositories/project_rate_repository.dart';
import 'package:asset_ledger/data/repositories/project_write_off_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/data/services/account_project_merge_service.dart';
import 'package:asset_ledger/data/services/project_resolver.dart';
import 'package:asset_ledger/features/account/domain/repositories/project_settlement_repository.dart';
import 'package:asset_ledger/features/account/state/account_store.dart';
import 'package:asset_ledger/features/account/use_cases/project_settlement_use_case.dart';
import 'package:asset_ledger/features/device/state/device_store.dart';
import 'package:asset_ledger/features/external_work/import_preview/use_cases/confirm_external_work_import_use_case.dart';
import 'package:asset_ledger/features/external_work/import_preview/use_cases/prepare_external_work_import_preview_use_case.dart';
import 'package:asset_ledger/features/fuel/state/fuel_store.dart';
import 'package:asset_ledger/features/maintenance/state/maintenance_store.dart';
import 'package:asset_ledger/features/timing/state/timing_store.dart';
import 'package:asset_ledger/features/timing/use_cases/timing_merge_dissolve_port.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'AppProviders exposes repositories and reuses startup store instances',
    (WidgetTester tester) async {
      final bundle = AppProviders.build();

      late DeviceRepository deviceRepository;
      late TimingRepository timingRepository;
      late FuelRepository fuelRepository;
      late MaintenanceRepository maintenanceRepository;
      late ProjectRepository projectRepository;
      late ProjectResolver projectResolver;
      late AccountPaymentRepository accountPaymentRepository;
      late ProjectRateRepository projectRateRepository;
      late ProjectWriteOffRepository projectWriteOffRepository;
      late ProjectSettlementRepository projectSettlementRepository;
      late ProjectSettlementUseCase projectSettlementUseCase;
      late AccountProjectMergeRepository accountProjectMergeRepository;
      late AccountProjectMergeService accountProjectMergeService;
      late TimingMergeDissolvePort timingMergeDissolvePort;
      late ExternalWorkImportPreviewPreparer externalWorkPreviewPreparer;
      late ExternalWorkImportConfirmer externalWorkImportConfirmer;
      late DeviceStore deviceStore;
      late TimingStore timingStore;
      late FuelStore fuelStore;
      late MaintenanceStore maintenanceStore;
      late AccountStore accountStore;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MultiProvider(
            providers: bundle.providers,
            child: Builder(
              builder: (context) {
                deviceRepository = context.read<DeviceRepository>();
                timingRepository = context.read<TimingRepository>();
                fuelRepository = context.read<FuelRepository>();
                maintenanceRepository = context.read<MaintenanceRepository>();
                projectRepository = context.read<ProjectRepository>();
                projectResolver = context.read<ProjectResolver>();
                accountPaymentRepository = context
                    .read<AccountPaymentRepository>();
                projectRateRepository = context.read<ProjectRateRepository>();
                projectWriteOffRepository = context
                    .read<ProjectWriteOffRepository>();
                projectSettlementRepository = context
                    .read<ProjectSettlementRepository>();
                projectSettlementUseCase = context
                    .read<ProjectSettlementUseCase>();
                accountProjectMergeRepository = context
                    .read<AccountProjectMergeRepository>();
                accountProjectMergeService = context
                    .read<AccountProjectMergeService>();
                timingMergeDissolvePort = context
                    .read<TimingMergeDissolvePort>();
                externalWorkPreviewPreparer = context
                    .read<ExternalWorkImportPreviewPreparer>();
                externalWorkImportConfirmer = context
                    .read<ExternalWorkImportConfirmer>();
                deviceStore = context.read<DeviceStore>();
                timingStore = context.read<TimingStore>();
                fuelStore = context.read<FuelStore>();
                maintenanceStore = context.read<MaintenanceStore>();
                accountStore = context.read<AccountStore>();
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(deviceRepository, isA<DeviceRepository>());
      expect(timingRepository, isA<TimingRepository>());
      expect(fuelRepository, isA<FuelRepository>());
      expect(maintenanceRepository, isA<MaintenanceRepository>());
      expect(projectRepository, isA<ProjectRepository>());
      expect(projectResolver, isA<ProjectResolver>());
      expect(accountPaymentRepository, isA<AccountPaymentRepository>());
      expect(projectRateRepository, isA<ProjectRateRepository>());
      expect(projectWriteOffRepository, isA<ProjectWriteOffRepository>());
      expect(projectSettlementRepository, isA<ProjectSettlementRepository>());
      expect(projectSettlementUseCase, isA<ProjectSettlementUseCase>());
      expect(
        accountProjectMergeRepository,
        isA<AccountProjectMergeRepository>(),
      );
      expect(accountProjectMergeService, isA<AccountProjectMergeService>());
      expect(timingMergeDissolvePort, isA<TimingMergeDissolvePort>());
      expect(
        externalWorkPreviewPreparer,
        isA<PrepareExternalWorkImportPreviewUseCase>(),
      );
      expect(
        externalWorkImportConfirmer,
        isA<ConfirmExternalWorkImportUseCase>(),
      );

      expect(identical(deviceStore, bundle.deviceStore), isTrue);
      expect(identical(timingStore, bundle.timingStore), isTrue);
      expect(identical(fuelStore, bundle.fuelStore), isTrue);
      expect(identical(maintenanceStore, bundle.maintenanceStore), isTrue);
      expect(identical(accountStore, bundle.accountStore), isTrue);
    },
  );
}
