import 'package:flutter/material.dart';

import '../../../../components/feedback/store_action_feedback_l10n.dart';
import '../../../../components/feedback/store_error_banner.dart';
import '../../../../components/layout/pinned_header_delegate.dart';
import '../../../../features/account/model/account_view_model.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../../patterns/account/account_overview_card_pattern.dart';
import '../../../../patterns/account/account_project_list_pattern.dart';
import '../../../../patterns/layout/phone_page_layout.dart';
import '../../../../tokens/mapper/account_tokens.dart';
import '../../../../tokens/mapper/core_tokens.dart';
import '../account_page_view_data.dart';

class AccountPageContent extends StatelessWidget {
  const AccountPageContent({
    super.key,
    required this.viewData,
    required this.isCompactProjectList,
    required this.projectAreaTabController,
    required this.onRetryLoad,
    required this.projectAreaHeaderBuilder,
    required this.onOpenProjectDetail,
    required this.onExportProjectTimingWorklog,
    required this.canExportProjectTimingWorklog,
    required this.onOpenExternalWorkDetail,
  });

  final AccountPageViewData viewData;
  final bool isCompactProjectList;
  final TabController projectAreaTabController;
  final VoidCallback onRetryLoad;
  final Widget Function(
    AccountPageViewData viewData, {
    required bool isExternalWork,
  })
  projectAreaHeaderBuilder;
  final ValueChanged<AccountProjectVM> onOpenProjectDetail;
  final Future<void> Function(AccountProjectVM project)
  onExportProjectTimingWorklog;
  final bool Function(AccountProjectVM project) canExportProjectTimingWorklog;
  final ValueChanged<AccountExternalWorkProjectVM> onOpenExternalWorkDetail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = PhonePageLayout.resolveHorizontalPadding(
              constraints.maxWidth,
              basePadding: AccountTokens.homePageHorizontalPadding,
            );
            final bottomSpacer =
                NavigationTokens.barHeight +
                MediaQuery.viewPaddingOf(context).bottom +
                AccountTokens.homeBottomGap;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                children: [
                  const SizedBox(height: AccountTokens.homeTopGap),
                  Expanded(
                    child: NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) {
                        return [
                          if (viewData.loading)
                            const SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  LinearProgressIndicator(),
                                  SizedBox(height: 10),
                                ],
                              ),
                            ),
                          if (viewData.error != null)
                            SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  StoreErrorBanner(
                                    message: localizeStoreActionFeedback(
                                      l10n,
                                      viewData.error!,
                                    ),
                                    onRetry: viewData.loading
                                        ? null
                                        : onRetryLoad,
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: AccountOverviewCard(
                              vm: AccountOverviewVm(
                                totalReceivable:
                                    viewData.computed.totalReceivable,
                                totalReceived: viewData.computed.totalReceived,
                                totalRemaining:
                                    viewData.computed.totalRemaining,
                                totalRatio: viewData.computed.totalRatio,
                                netCashReceived: viewData.netCashReceived,
                                externalCustomerReceivableFen: viewData
                                    .externalReceivableRollup
                                    .externalCustomerReceivableFen,
                                deviceReceivables:
                                    viewData.overviewDeviceReceivables,
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(
                              height: AccountTokens.projectTitleTopGap,
                            ),
                          ),
                        ];
                      },
                      body: TabBarView(
                        controller: projectAreaTabController,
                        children: [
                          _AccountProjectAreaTabBody(
                            storageKey: const PageStorageKey<String>(
                              'account-owned-projects-tab',
                            ),
                            header: projectAreaHeaderBuilder(
                              viewData,
                              isExternalWork: false,
                            ),
                            bottomSpacer: bottomSpacer,
                            child: AccountProjectList(
                              projects: viewData.filteredProjects,
                              isCompact: isCompactProjectList,
                              onTap: onOpenProjectDetail,
                              onExportWorklog: onExportProjectTimingWorklog,
                              canExportWorklog: canExportProjectTimingWorklog,
                            ),
                          ),
                          _AccountProjectAreaTabBody(
                            storageKey: const PageStorageKey<String>(
                              'account-external-work-projects-tab',
                            ),
                            header: projectAreaHeaderBuilder(
                              viewData,
                              isExternalWork: true,
                            ),
                            bottomSpacer: bottomSpacer,
                            child: AccountProjectList(
                              projects: const [],
                              externalWorkProjects:
                                  viewData.filteredExternalWorkProjects,
                              isCompact: isCompactProjectList,
                              onTap: onOpenProjectDetail,
                              onExternalTap: onOpenExternalWorkDetail,
                              emptyText: l10n.accountExternalProjectsEmpty,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AccountProjectAreaTabBody extends StatelessWidget {
  const _AccountProjectAreaTabBody({
    required this.storageKey,
    required this.header,
    required this.child,
    required this.bottomSpacer,
  });

  final Key storageKey;
  final Widget header;
  final Widget child;
  final double bottomSpacer;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: storageKey,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: PinnedHeaderDelegate(
            height: AccountTokens.projectPinnedHeaderHeight,
            child: header,
          ),
        ),
        SliverToBoxAdapter(child: child),
        SliverToBoxAdapter(
          child: SizedBox(
            key: const Key('account-page-bottom-navigation-spacer'),
            height: bottomSpacer,
          ),
        ),
      ],
    );
  }
}
