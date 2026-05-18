import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../adapters/account_merge_dissolve_adapter.dart';
import '../../data/repositories/account_payment_repository.dart';
import '../../data/repositories/account_project_merge_repository.dart';
import '../../data/repositories/project_write_off_repository.dart';
import '../../data/repositories/project_rate_repository.dart';
import '../../data/services/account_project_merge_service.dart';
import '../../features/account/application/controllers/account_action_controller.dart';
import '../../features/account/domain/repositories/project_settlement_repository.dart';
import '../../features/account/state/account_filter_store.dart';
import '../../features/account/state/account_payment_store.dart';
import '../../features/account/state/account_store.dart';
import '../../features/account/state/project_rate_store.dart';
import '../../features/account/use_cases/project_settlement_use_case.dart';
import '../../features/timing/use_cases/timing_merge_dissolve_port.dart';
import '../../infrastructure/local/account/local_project_settlement_repository.dart';

/// Account + project-merge composition slice: payment / rate / merge
/// repositories, merge service and the account-side stores.
class AccountMergeProviders {
  AccountMergeProviders._({
    required this.paymentStore,
    required this.projectRateStore,
    required this.accountStore,
    required this.providers,
  });

  final AccountPaymentStore paymentStore;
  final ProjectRateStore projectRateStore;
  final AccountStore accountStore;
  final List<SingleChildWidget> providers;

  factory AccountMergeProviders.build() {
    final accountPaymentRepository = SqfliteAccountPaymentRepository();
    final projectRateRepository = SqfliteProjectRateRepository();
    final projectWriteOffRepository = SqfliteProjectWriteOffRepository();
    const projectSettlementRepository = LocalProjectSettlementRepository();
    final accountProjectMergeRepository =
        SqfliteAccountProjectMergeRepository();
    final accountProjectMergeService = AccountProjectMergeService(
      repository: accountProjectMergeRepository,
    );
    final timingMergeDissolvePort = AccountMergeDissolveAdapter(
      accountProjectMergeService,
    );

    final paymentStore = AccountPaymentStore(accountPaymentRepository);
    final projectRateStore = ProjectRateStore(projectRateRepository);
    final accountStore = AccountStore(
      mergeService: accountProjectMergeService,
      writeOffRepository: projectWriteOffRepository,
    );
    final projectSettlementUseCase = ProjectSettlementUseCase(
      repository: projectSettlementRepository,
    );
    final accountActionController = AccountActionController(
      paymentRepository: accountPaymentRepository,
      mergeService: accountProjectMergeService,
      settlementUseCase: projectSettlementUseCase,
    );

    return AccountMergeProviders._(
      paymentStore: paymentStore,
      projectRateStore: projectRateStore,
      accountStore: accountStore,
      providers: [
        Provider<AccountPaymentRepository>.value(
          value: accountPaymentRepository,
        ),
        Provider<ProjectRateRepository>.value(value: projectRateRepository),
        Provider<ProjectWriteOffRepository>.value(
          value: projectWriteOffRepository,
        ),
        Provider<ProjectSettlementRepository>.value(
          value: projectSettlementRepository,
        ),
        Provider<ProjectSettlementUseCase>.value(
          value: projectSettlementUseCase,
        ),
        Provider<AccountActionController>.value(value: accountActionController),
        Provider<AccountProjectMergeRepository>.value(
          value: accountProjectMergeRepository,
        ),
        Provider<AccountProjectMergeService>.value(
          value: accountProjectMergeService,
        ),
        Provider<TimingMergeDissolvePort>.value(value: timingMergeDissolvePort),
        ChangeNotifierProvider<AccountPaymentStore>.value(value: paymentStore),
        ChangeNotifierProvider<AccountStore>.value(value: accountStore),
        ChangeNotifierProvider<AccountFilterStore>(
          create: (_) => AccountFilterStore(),
        ),
        ChangeNotifierProvider<ProjectRateStore>.value(value: projectRateStore),
      ],
    );
  }
}
