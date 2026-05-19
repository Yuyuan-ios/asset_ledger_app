import 'package:flutter/material.dart';

import '../../components/feedback/store_error_banner.dart';
import '../../components/layout/pinned_header_delegate.dart';
import '../../data/models/device.dart';
import '../../data/models/timing_record.dart';
import '../layout/phone_page_layout.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';
import 'recent_records_pattern.dart';

class TimingHomePattern extends StatefulWidget {
  const TimingHomePattern({
    super.key,
    required this.header,
    required this.chart,
    required this.recordsTitle,
    required this.records,
    required this.deviceById,
    required this.deviceIndexById,
    this.onTapRecord,
    required this.loading,
    this.error,
    this.onRetry,
  });

  final Widget header;
  final Widget chart;
  final Widget recordsTitle;
  final List<TimingRecord> records;
  final Map<int, Device> deviceById;
  final Map<int, String> deviceIndexById;
  final ValueChanged<TimingRecord>? onTapRecord;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  State<TimingHomePattern> createState() => _TimingHomePatternState();
}

class _TimingHomePatternState extends State<TimingHomePattern> {
  final Set<String> _locallyRemovedRecordKeys = <String>{};
  final Set<String> _expandedAggregateKeys = <String>{};

  static const double _recordsHeaderHeight =
      (TimingTokens.recordsTitleFontSize *
          TimingTokens.recordsTitleLineHeight) +
      TimingTokens.homeRecordsTitleTopGap;

  @override
  void didUpdateWidget(covariant TimingHomePattern oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pruneRecordState();
  }

  void _pruneRecordState() {
    final currentRecordKeys = timingRecentRecordKeys(widget.records);
    _locallyRemovedRecordKeys.removeWhere(
      (key) => !currentRecordKeys.contains(key),
    );

    final currentAggregateKeys = timingRecentAggregateKeys(
      widget.records,
      _locallyRemovedRecordKeys,
    );
    _expandedAggregateKeys.removeWhere(
      (key) => !currentAggregateKeys.contains(key),
    );
  }

  void _toggleAggregate(String key) {
    setState(() {
      if (_expandedAggregateKeys.contains(key)) {
        _expandedAggregateKeys.remove(key);
      } else {
        _expandedAggregateKeys.add(key);
      }
    });
  }

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
                  widget.header,
                  const SizedBox(height: TimingTokens.homeHeaderBottomGap),
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        if (widget.loading)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: TimingTokens.homeLoadingBottomGap,
                              ),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          ),
                        if (widget.error != null &&
                            widget.error!.trim().isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                bottom: TimingTokens.homeErrorBottomGap,
                              ),
                              child: StoreErrorBanner(
                                message: widget.error!,
                                onRetry: widget.loading ? null : widget.onRetry,
                              ),
                            ),
                          ),
                        SliverToBoxAdapter(child: widget.chart),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: TimingTokens.homeChartTopGap),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: PinnedHeaderDelegate(
                            height: _recordsHeaderHeight,
                            child: ColoredBox(
                              color: AppColors.scaffoldBg,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: TimingTokens.homeRecordsTitleTopGap,
                                ),
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: widget.recordsTitle,
                                ),
                              ),
                            ),
                          ),
                        ),
                        ...buildTimingRecentRecordSlivers(
                          records: widget.records,
                          deviceById: widget.deviceById,
                          deviceIndexById: widget.deviceIndexById,
                          locallyRemovedKeys: _locallyRemovedRecordKeys,
                          expandedAggregateKeys: _expandedAggregateKeys,
                          onToggleAggregate: _toggleAggregate,
                          onTapRecord: widget.onTapRecord,
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: TimingTokens.homeBottomGap),
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
