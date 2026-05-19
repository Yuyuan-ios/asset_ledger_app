part of 'recent_records_pattern.dart';

List<Widget> buildTimingRecentRecordSlivers({
  required List<TimingRecord> records,
  required Map<int, Device> deviceById,
  required Map<int, String> deviceIndexById,
  required Set<String> locallyRemovedKeys,
  required Set<String> expandedAggregateKeys,
  required ValueChanged<String> onToggleAggregate,
  ValueChanged<TimingRecord>? onTapRecord,
}) {
  final visibleRecords = records
      .where((record) => !locallyRemovedKeys.contains(_recordKey(record)))
      .toList();

  if (visibleRecords.isEmpty) {
    return const <Widget>[
      SliverToBoxAdapter(child: AppRecentRecordsEmptyState()),
    ];
  }

  final displaySections = _buildRecordDisplaySections(visibleRecords);

  return <Widget>[
    for (final section in displaySections) ...[
      SliverPersistentHeader(
        pinned: true,
        delegate: PinnedHeaderDelegate(
          height: _dateHeaderExtent,
          child: _SliverDateGroupHeader(
            ymd: section.ymd,
            aggregateSection: section.aggregate,
            aggregateExpanded:
                section.aggregate != null &&
                expandedAggregateKeys.contains(section.aggregate!.key),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: _RecordGroupCard(
          rows: _buildTimingRecordRows(
            section: section,
            expandedAggregateKeys: expandedAggregateKeys,
            onToggleAggregate: onToggleAggregate,
            deviceById: deviceById,
            deviceIndexById: deviceIndexById,
            onTapRecord: onTapRecord,
          ),
        ),
      ),
    ],
  ];
}

const double _dateHeaderExtent =
    (TimingTokens.dateHeaderFontSize * TimingTokens.dateHeaderLineHeight) +
    TimingTokens.recordDividerThickness +
    TimingTokens.recordDividerThickness;
const double _dateHeaderDividerHorizontalInset = 12;
const Color _dateHeaderDividerColor = Color(0x66D9D9D9);

List<Widget> _buildTimingRecordRows({
  required _RecordDisplaySection section,
  required Set<String> expandedAggregateKeys,
  required ValueChanged<String> onToggleAggregate,
  required Map<int, Device> deviceById,
  required Map<int, String> deviceIndexById,
  required ValueChanged<TimingRecord>? onTapRecord,
}) {
  final aggregate = section.aggregate;
  if (aggregate != null) {
    final expanded = expandedAggregateKeys.contains(aggregate.key);
    return <Widget>[
      _RecordRow(
        record: aggregate.summaryRecord,
        device: deviceById[aggregate.deviceId],
        deviceIndexText: deviceIndexById[aggregate.deviceId] ?? '?',
        subtitleEmphasis: deviceIndexById[aggregate.deviceId] ?? '?',
        subtitleSecondary: ' 工时调整',
        bottomRightOverride:
            '误差 ${FormatUtils.meter(aggregate.meterError)}，累计 ${FormatUtils.hours(aggregate.totalHours)}',
        onTap: () => onToggleAggregate(aggregate.key),
      ),
      if (expanded)
        ...aggregate.records.map(
          (record) => _RecordRow(
            record: record,
            device: deviceById[record.deviceId],
            deviceIndexText: deviceIndexById[record.deviceId] ?? '?',
            hideAvatar: true,
            titleOverride: FormatUtils.date(record.startDate),
            subtitleOverride: deviceById[record.deviceId] == null
                ? deviceIndexById[record.deviceId] ?? '?'
                : '${deviceById[record.deviceId]!.brand}${deviceIndexById[record.deviceId] ?? '?'}',
            subtitleEmphasized: false,
            bottomRightOverride: record.isBreaking
                ? '破碎 ${FormatUtils.hours(record.hours)}'
                : FormatUtils.hours(record.hours),
            onTap: onTapRecord == null ? null : () => onTapRecord(record),
          ),
        ),
    ];
  }

  return section.records
      .map(
        (record) => _RecordRow(
          record: record,
          device: deviceById[record.deviceId],
          deviceIndexText: deviceIndexById[record.deviceId] ?? '?',
          onTap: onTapRecord == null ? null : () => onTapRecord(record),
        ),
      )
      .toList();
}

const double _recordGroupRadius = 8;
const double _recordInnerDividerLeftInset =
    TimingTokens.recordRowPaddingLeft +
    TimingTokens.recordAvatarSize +
    TimingTokens.recordAvatarRightGap;
const Color _recordInnerDividerColor = Color(0x99D9D9D9);

class _RecordGroupCard extends StatelessWidget {
  const _RecordGroupCard({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_recordGroupRadius),
      child: ColoredBox(
        color: SheetColors.background,
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index += 1) ...[
              if (index > 0) const _RecordInnerDivider(),
              rows[index],
            ],
          ],
        ),
      ),
    );
  }
}

class _RecordInnerDivider extends StatelessWidget {
  const _RecordInnerDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: _recordInnerDividerLeftInset),
      child: Divider(
        height: TimingTokens.recordDividerThickness,
        thickness: TimingTokens.recordDividerThickness,
        color: _recordInnerDividerColor,
      ),
    );
  }
}

class _SliverDateGroupHeader extends StatelessWidget {
  const _SliverDateGroupHeader({
    required this.ymd,
    this.aggregateSection,
    this.aggregateExpanded = false,
  });

  final int ymd;
  final _AggregateRecordSection? aggregateSection;
  final bool aggregateExpanded;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final aggregate = aggregateSection;

    return ColoredBox(
      color: AppColors.scaffoldBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: TimingTokens.dateHeaderLeftInset,
            ),
            child: Text(
              aggregate == null
                  ? FormatUtils.date(ymd)
                  : '${FormatUtils.date(ymd)} (${aggregateExpanded ? '已展开' : '已聚合'})',
              style: textTheme.bodySmall?.copyWith(
                fontSize: TimingTokens.dateHeaderFontSize,
                color: AppColors.textPrimary,
                height: TimingTokens.dateHeaderLineHeight,
              ),
            ),
          ),
          const _DateHeaderBoundaryDivider(),
        ],
      ),
    );
  }
}

class _DateHeaderBoundaryDivider extends StatelessWidget {
  const _DateHeaderBoundaryDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      indent: _dateHeaderDividerHorizontalInset,
      endIndent: _dateHeaderDividerHorizontalInset,
      height: TimingTokens.recordDividerThickness,
      thickness: TimingTokens.recordDividerThickness,
      color: _dateHeaderDividerColor,
    );
  }
}
