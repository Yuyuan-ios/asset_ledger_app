import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../data/repositories/account_payment_repository.dart';
import '../../data/repositories/account_project_merge_repository.dart';
import '../../data/repositories/project_rate_repository.dart';
import '../../data/services/account_project_merge_service.dart';
import '../../features/account/state/account_filter_store.dart';
import '../../features/account/state/account_payment_store.dart';
import '../../features/account/state/account_store.dart';
import '../../features/account/state/project_rate_store.dart';

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
    final accountProjectMergeRepository =
        SqfliteAccountProjectMergeRepository();
    final accountProjectMergeService = AccountProjectMergeService(
      repository: accountProjectMergeRepository,
    );

    final paymentStore = AccountPaymentStore(accountPaymentRepository);
    final projectRateStore = ProjectRateStore(projectRateRepository);
    final accountStore = AccountStore(
      mergeService: accountProjectMergeService,
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
        Provider<AccountProjectMergeRepository>.value(
          value: accountProjectMergeRepository,
        ),
        Provider<AccountProjectMergeService>.value(
          value: accountProjectMergeService,
        ),
        ChangeNotifierProvider<AccountPaymentStore>.value(value: paymentStore),
        ChangeNotifierProvider<AccountStore>.value(value: accountStore),
        ChangeNotifierProvider<AccountFilterStore>(
          create: (_) => AccountFilterStore(),
        ),
        ChangeNotifierProvider<ProjectRateStore>.value(
          value: projectRateStore,
        ),
      ],
    );
  }
}
