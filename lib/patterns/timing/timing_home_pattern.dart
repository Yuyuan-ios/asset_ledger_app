import 'package:flutter/material.dart';

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
  });

  final Widget header;
  final Widget chart;
  final Widget recordsTitle;
  final Widget records;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth =
                constraints.maxWidth > TimingTokens.homeMaxContainerWidthTrigger
                ? TimingTokens.homeFixedContentWidth
                : constraints.maxWidth;

            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TimingTokens.homePageHorizontalPadding,
                    0,
                    TimingTokens.homePageHorizontalPadding,
                    0,
                  ),
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
                                  child: Text(
                                    error!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: TimingTokens.homeErrorFontSize,
                                    ),
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
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
