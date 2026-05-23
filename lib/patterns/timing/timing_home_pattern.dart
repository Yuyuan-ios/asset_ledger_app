import 'package:flutter/material.dart';

import '../../components/feedback/store_error_banner.dart';
import '../../components/layout/pinned_header_delegate.dart';
import '../../data/models/device.dart';
import '../../data/models/timing_record.dart';
import '../../features/timing/state/timing_external_work_store.dart';
import '../layout/phone_page_layout.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';
import 'external_work_records_pattern.dart';
import 'recent_records_pattern.dart';

enum TimingRecordsSection { recent, externalWork }

class TimingHomePattern extends StatefulWidget {
  const TimingHomePattern({
    super.key,
    required this.header,
    required this.chart,
    required this.recordsTitle,
    required this.recordsSection,
    required this.onRecordsSectionChanged,
    required this.records,
    required this.externalWorkItems,
    required this.deviceById,
    required this.deviceIndexById,
    this.onTapRecord,
    this.onTapExternalWorkRecord,
    this.onImportExternalWork,
    required this.loading,
    this.error,
    this.onRetry,
  });

  final Widget header;
  final Widget chart;
  final Widget recordsTitle;
  final TimingRecordsSection recordsSection;
  final ValueChanged<TimingRecordsSection> onRecordsSectionChanged;
  final List<TimingRecord> records;
  final List<TimingExternalWorkRecordItem> externalWorkItems;
  final Map<int, Device> deviceById;
  final Map<int, String> deviceIndexById;
  final ValueChanged<TimingRecord>? onTapRecord;
  final ValueChanged<TimingExternalWorkRecordItem>? onTapExternalWorkRecord;
  final VoidCallback? onImportExternalWork;
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
                                child: _RecordsAreaHeader(
                                  title: widget.recordsTitle,
                                  selectedSection: widget.recordsSection,
                                  onSectionChanged:
                                      widget.onRecordsSectionChanged,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (widget.recordsSection ==
                            TimingRecordsSection.recent)
                          ...buildTimingRecentRecordSlivers(
                            records: widget.records,
                            deviceById: widget.deviceById,
                            deviceIndexById: widget.deviceIndexById,
                            locallyRemovedKeys: _locallyRemovedRecordKeys,
                            expandedAggregateKeys: _expandedAggregateKeys,
                            onToggleAggregate: _toggleAggregate,
                            onTapRecord: widget.onTapRecord,
                          )
                        else
                          ...buildTimingExternalWorkRecordSlivers(
                            items: widget.externalWorkItems,
                            onTapRecord: widget.onTapExternalWorkRecord,
                            onImportShareFile: widget.onImportExternalWork,
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

class _RecordsAreaHeader extends StatelessWidget {
  const _RecordsAreaHeader({
    required this.title,
    required this.selectedSection,
    required this.onSectionChanged,
  });

  final Widget title;
  final TimingRecordsSection selectedSection;
  final ValueChanged<TimingRecordsSection> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Row(
        children: [
          Expanded(child: title),
          const SizedBox(width: 8),
          _RecordsSectionSwitch(
            selectedSection: selectedSection,
            onSectionChanged: onSectionChanged,
          ),
        ],
      ),
    );
  }
}

class _RecordsSectionSwitch extends StatelessWidget {
  const _RecordsSectionSwitch({
    required this.selectedSection,
    required this.onSectionChanged,
  });

  final TimingRecordsSection selectedSection;
  final ValueChanged<TimingRecordsSection> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7E1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RecordsSectionButton(
              label: '最近记录',
              selected: selectedSection == TimingRecordsSection.recent,
              onTap: () => onSectionChanged(TimingRecordsSection.recent),
            ),
            _RecordsSectionButton(
              label: '项目外协',
              selected: selectedSection == TimingRecordsSection.externalWork,
              onTap: () => onSectionChanged(TimingRecordsSection.externalWork),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordsSectionButton extends StatelessWidget {
  const _RecordsSectionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: selected ? SheetColors.background : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: selected ? null : onTap,
        child: SizedBox(
          height: 16,
          width: 72,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelMedium?.copyWith(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                height: 1,
                color: selected
                    ? AppColors.textPrimary
                    : TimingColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
