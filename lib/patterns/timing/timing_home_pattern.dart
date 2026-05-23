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

class _TimingHomePatternState extends State<TimingHomePattern>
    with SingleTickerProviderStateMixin {
  final Set<String> _locallyRemovedRecordKeys = <String>{};
  final Set<String> _expandedAggregateKeys = <String>{};
  final Set<String> _expandedExternalWorkAggregateKeys = <String>{};

  static const double _recordsHeaderHeight =
      (TimingTokens.recordsTitleFontSize *
          TimingTokens.recordsTitleLineHeight) +
      TimingTokens.homeRecordsTitleTopGap;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.recordsSection.index,
    );
    _tabController.addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// TabBarView 滑动 / 胶囊 animateTo 都会更新 index（滑动到中点即更新），
  /// 回写父级 section 以同步胶囊高亮。idempotent。
  void _handleTabChanged() {
    final section = TimingRecordsSection.values[_tabController.index];
    if (section != widget.recordsSection) {
      widget.onRecordsSectionChanged(section);
    }
  }

  /// 胶囊点击：动画切换 TabBarView（→ _handleTabChanged 回写父级 section）。
  void _selectSection(TimingRecordsSection section) {
    if (_tabController.index != section.index) {
      _tabController.animateTo(section.index);
    }
  }

  @override
  void didUpdateWidget(covariant TimingHomePattern oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pruneRecordState();
    // 父级（外部）改 section 时，保证 TabBarView 跟随。
    if (widget.recordsSection.index != _tabController.index) {
      _tabController.animateTo(widget.recordsSection.index);
    }
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

    final currentExternalWorkAggregateKeys = timingExternalWorkAggregateKeys(
      widget.externalWorkItems,
    );
    _expandedExternalWorkAggregateKeys.removeWhere(
      (key) => !currentExternalWorkAggregateKeys.contains(key),
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

  void _toggleExternalWorkAggregate(String key) {
    setState(() {
      if (_expandedExternalWorkAggregateKeys.contains(key)) {
        _expandedExternalWorkAggregateKeys.remove(key);
      } else {
        _expandedExternalWorkAggregateKeys.add(key);
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

            // 底部导航栏（router extendBody:true）悬浮在内容之上，每页列表预留
            // 清空高度，保证最后一条记录不被底栏遮挡。
            final bottomSpacer =
                NavigationTokens.barHeight +
                MediaQuery.viewPaddingOf(context).bottom +
                TimingTokens.homeBottomGap;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                children: [
                  widget.header,
                  const SizedBox(height: TimingTokens.homeHeaderBottomGap),
                  Expanded(
                    child: NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) {
                        return [
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
                                  onRetry: widget.loading
                                      ? null
                                      : widget.onRetry,
                                ),
                              ),
                            ),
                          // 图表随列表上滑收起（在 header 区，非吸顶）。
                          SliverToBoxAdapter(child: widget.chart),
                          const SliverToBoxAdapter(
                            child: SizedBox(
                              height: TimingTokens.homeChartTopGap,
                            ),
                          ),
                          // 胶囊标题栏：吸顶。用 OverlapAbsorber 把重叠量交给内层注入。
                          SliverOverlapAbsorber(
                            handle:
                                NestedScrollView.sliverOverlapAbsorberHandleFor(
                                  context,
                                ),
                            sliver: SliverPersistentHeader(
                              pinned: true,
                              delegate: PinnedHeaderDelegate(
                                height: _recordsHeaderHeight,
                                child: ColoredBox(
                                  color: AppColors.scaffoldBg,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      bottom:
                                          TimingTokens.homeRecordsTitleTopGap,
                                    ),
                                    child: _RecordsAreaHeader(
                                      title: widget.recordsTitle,
                                      selectedSection: widget.recordsSection,
                                      onSectionChanged: _selectSection,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ];
                      },
                      body: TabBarView(
                        controller: _tabController,
                        children: [
                          _RecordsTabBody(
                            storageKey: const PageStorageKey<String>(
                              'timing-recent-tab',
                            ),
                            bottomSpacer: bottomSpacer,
                            slivers: buildTimingRecentRecordSlivers(
                              records: widget.records,
                              deviceById: widget.deviceById,
                              deviceIndexById: widget.deviceIndexById,
                              locallyRemovedKeys: _locallyRemovedRecordKeys,
                              expandedAggregateKeys: _expandedAggregateKeys,
                              onToggleAggregate: _toggleAggregate,
                              onTapRecord: widget.onTapRecord,
                            ),
                          ),
                          _RecordsTabBody(
                            storageKey: const PageStorageKey<String>(
                              'timing-external-tab',
                            ),
                            bottomSpacer: bottomSpacer,
                            slivers: buildTimingExternalWorkRecordSlivers(
                              items: widget.externalWorkItems,
                              expandedAggregateKeys:
                                  _expandedExternalWorkAggregateKeys,
                              onToggleAggregate: _toggleExternalWorkAggregate,
                              onTapRecord: widget.onTapExternalWorkRecord,
                              onImportShareFile: widget.onImportExternalWork,
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

/// NestedScrollView 的单个 tab 内容：独立 CustomScrollView。
/// 顶部用 SliverOverlapInjector 注入外层吸顶胶囊的重叠量，保证首条内容不被
/// 吸顶标题遮挡；其后原样放入本 tab 的 slivers（含日期吸顶 / 聚合），末尾追加
/// 底部导航清空高度。PageStorageKey 保留各 tab 纵向滚动位置。
class _RecordsTabBody extends StatelessWidget {
  const _RecordsTabBody({
    required this.storageKey,
    required this.slivers,
    required this.bottomSpacer,
  });

  final Key storageKey;
  final List<Widget> slivers;
  final double bottomSpacer;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: storageKey,
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        ...slivers,
        SliverToBoxAdapter(
          child: SizedBox(
            key: const Key('timing-home-bottom-navigation-spacer'),
            height: bottomSpacer,
          ),
        ),
      ],
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
