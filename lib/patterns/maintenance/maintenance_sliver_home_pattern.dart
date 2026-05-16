import 'package:flutter/material.dart';

import '../../components/feedback/store_error_banner.dart';
import '../../components/layout/pinned_header_delegate.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/fuel_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';
import '../layout/phone_page_layout.dart';

class MaintenanceSliverHomePattern extends StatelessWidget {
  const MaintenanceSliverHomePattern({
    super.key,
    required this.header,
    required this.summary,
    required this.recordsTitle,
    required this.records,
    required this.loading,
    this.error,
    this.onRetry,
  });

  final Widget header;
  final Widget summary;
  final Widget recordsTitle;
  final Widget records;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  static const double _recordsHeaderHeight =
      (TimingTokens.recordsTitleFontSize *
          TimingTokens.recordsTitleLineHeight) +
      FuelTokens.recordsTitleTopGap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = PhonePageLayout.resolveHorizontalPadding(
              constraints.maxWidth,
              basePadding: FuelTokens.homePageHorizontalPadding,
            );

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                children: [
                  header,
                  const SizedBox(height: FuelTokens.homeHeaderBottomGap),
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        if (loading)
                          const SliverToBoxAdapter(
                            child: Column(
                              children: [
                                LinearProgressIndicator(),
                                SizedBox(
                                  height: FuelTokens.homeLoadingBottomGap,
                                ),
                              ],
                            ),
                          ),
                        if (error != null && error!.trim().isNotEmpty)
                          SliverToBoxAdapter(
                            child: Column(
                              children: [
                                StoreErrorBanner(
                                  message: error!,
                                  onRetry: loading ? null : onRetry,
                                ),
                                const SizedBox(
                                  height: FuelTokens.homeErrorBottomGap,
                                ),
                              ],
                            ),
                          ),
                        SliverToBoxAdapter(child: summary),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: FuelTokens.homeSectionGap),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: PinnedHeaderDelegate(
                            height: _recordsHeaderHeight,
                            child: ColoredBox(
                              color: AppColors.scaffoldBg,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: FuelTokens.recordsTitleTopGap,
                                ),
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: recordsTitle,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(child: records),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: FuelTokens.homeListBottomGap),
                        ),
                      ],
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
