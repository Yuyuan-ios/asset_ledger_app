import 'package:flutter/material.dart';

import '../../components/feedback/store_error_banner.dart';
import '../layout/phone_page_layout.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';

class TimingHomePattern extends StatelessWidget {
  const TimingHomePattern({
    super.key,
    required this.header,
    required this.chart,
    required this.recordsTitle,
    required this.records,
    required this.loading,
    this.error,
    this.onRetry,
  });

  final Widget header;
  final Widget chart;
  final Widget recordsTitle;
  final Widget records;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

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
              basePadding: TimingTokens.homePageHorizontalPadding,
            );

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                children: [
                  header,
                  const SizedBox(height: TimingTokens.homeHeaderBottomGap),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (loading)
                            const Padding(
                              padding: EdgeInsets.only(
                                bottom: TimingTokens.homeLoadingBottomGap,
                              ),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          if (error != null && error!.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: TimingTokens.homeErrorBottomGap,
                              ),
                              child: StoreErrorBanner(
                                message: error!,
                                onRetry: loading ? null : onRetry,
                              ),
                            ),
                          chart,
                          const SizedBox(height: TimingTokens.homeChartTopGap),
                          recordsTitle,
                          const SizedBox(
                            height: TimingTokens.homeRecordsTitleTopGap,
                          ),
                          records,
                          const SizedBox(height: TimingTokens.homeBottomGap),
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
