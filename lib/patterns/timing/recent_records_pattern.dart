import 'package:flutter/material.dart';

import '../../data/models/device.dart';
import '../../data/models/timing_record.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';
import '../../core/utils/format_utils.dart';
import '../../components/avatars/app_device_avatar.dart';
import '../../components/feedback/app_records_empty_hint.dart';
import '../../components/layout/pinned_header_delegate.dart';
import '../../features/account/model/project_title_formatter.dart';

part 'timing_recent_records_slivers.dart';

String _recordKey(TimingRecord r) {
  return 'timing-${r.id ?? '${r.startDate}-${r.deviceId}-${r.contact}-${r.site}'}';
}

String _aggregateKey(List<TimingRecord> records) {
  final first = records.first;
  final segmentStartId =
      first.id ??
      '${first.startDate}-${first.startMeter}-${first.endMeter}-${first.hours}';
  return 'aggregate-${first.deviceId}-${first.contact}-${first.site}-$segmentStartId';
}

Set<String> timingRecentRecordKeys(List<TimingRecord> records) {
  return records.map(_recordKey).toSet();
}

String timingRecentRecordKey(TimingRecord record) {
  return _recordKey(record);
}

Set<String> timingRecentAggregateKeys(
  List<TimingRecord> records,
  Set<String> locallyRemovedKeys,
) {
  final visibleRecords = records
      .where((record) => !locallyRemovedKeys.contains(_recordKey(record)))
      .toList();
  return _buildAggregateSections(
    visibleRecords,
  ).map((section) => section.key).toSet();
}

int timingRecentTopLevelRecordCount(
  List<TimingRecord> records, [
  Set<String> locallyRemovedKeys = const <String>{},
]) {
  final visibleRecords = records
      .where((record) => !locallyRemovedKeys.contains(_recordKey(record)))
      .toList();

  return _buildRecordDisplaySections(visibleRecords).fold<int>(
    0,
    (count, section) =>
        count + (section.aggregate == null ? section.records.length : 1),
  );
}

bool shouldShowDurationForTimingRecord(TimingRecord record) {
  if (record.type != TimingType.rent) return true;
  return record.hours > 0;
}

List<_RecordDisplaySection> _buildRecordDisplaySections(
  List<TimingRecord> visibleRecords,
) {
  final aggregateSections = _buildAggregateSections(visibleRecords);
  final aggregateRecordKeys = <String>{
    for (final section in aggregateSections)
      for (final record in section.records) _recordKey(record),
  };
  final singleRecords = visibleRecords
      .where((record) => !aggregateRecordKeys.contains(_recordKey(record)))
      .toList();

  final groupedSingles = <int, List<TimingRecord>>{};
  final cutoffSingleSections = <_RecordDisplaySection>[];
  for (final record in singleRecords) {
    if (_shouldShowAllocationCutoffRange(record)) {
      cutoffSingleSections.add(
        _RecordDisplaySection.singles(
          ymd: record.startDate,
          records: [record],
          headerOverride: _dateRangeText(record),
        ),
      );
      continue;
    }
    groupedSingles
        .putIfAbsent(record.startDate, () => <TimingRecord>[])
        .add(record);
  }

  return <_RecordDisplaySection>[
    for (final entry in groupedSingles.entries)
      _RecordDisplaySection.singles(ymd: entry.key, records: entry.value),
    ...cutoffSingleSections,
    for (final section in aggregateSections)
      _RecordDisplaySection.aggregate(section),
  ]..sort((a, b) {
    final byDate = b.ymd.compareTo(a.ymd);
    if (byDate != 0) return byDate;
    return b.sortId.compareTo(a.sortId);
  });
}

bool _shouldShowAllocationCutoffRange(TimingRecord record) {
  if (record.type != TimingType.hours) return false;
  final cutoff = record.allocationCutoffDate;
  if (cutoff == null) return false;
  final endYmd = _tryInclusiveDisplayEndYmd(cutoff);
  if (endYmd == null) return false;
  return endYmd >= record.startDate;
}

String _dateRangeText(TimingRecord record) {
  if (!_shouldShowAllocationCutoffRange(record)) {
    return FormatUtils.date(record.startDate);
  }
  final endYmd = _tryInclusiveDisplayEndYmd(record.allocationCutoffDate!);
  if (endYmd == null) return FormatUtils.date(record.startDate);
  return '${FormatUtils.date(record.startDate)} - ${_compactRangeEndText(record.startDate, endYmd)}';
}

int? _tryInclusiveDisplayEndYmd(int exclusiveCutoffYmd) {
  try {
    final exclusive = FormatUtils.dateFromYmd(exclusiveCutoffYmd);
    return FormatUtils.ymdFromDate(exclusive.subtract(const Duration(days: 1)));
  } on ArgumentError {
    return null;
  }
}

String _compactRangeEndText(int startYmd, int endYmd) {
  final start = FormatUtils.dateFromYmd(startYmd);
  final end = FormatUtils.dateFromYmd(endYmd);
  if (start.year != end.year) return FormatUtils.date(endYmd);
  final month = end.month.toString().padLeft(2, '0');
  final day = end.day.toString().padLeft(2, '0');
  return '$month.$day';
}

List<_AggregateRecordSection> _buildAggregateSections(
  List<TimingRecord> records,
) {
  final recordsByDevice = <int, List<TimingRecord>>{};
  for (final record in records) {
    recordsByDevice
        .putIfAbsent(record.deviceId, () => <TimingRecord>[])
        .add(record);
  }

  final sections = <_AggregateRecordSection>[];
  for (final deviceRecords in recordsByDevice.values) {
    final sortedRecords = [...deviceRecords]
      ..sort(_compareRecordChronologically);
    var currentSegment = <TimingRecord>[];

    for (final record in sortedRecords) {
      if (currentSegment.isEmpty ||
          _belongsToSameContinuousSegment(currentSegment.last, record)) {
        currentSegment.add(record);
        continue;
      }

      if (currentSegment.length > 1) {
        sections.add(
          _AggregateRecordSection.fromRecords(
            _aggregateKey(currentSegment),
            currentSegment,
          ),
        );
      }
      currentSegment = [record];
    }

    if (currentSegment.length > 1) {
      sections.add(
        _AggregateRecordSection.fromRecords(
          _aggregateKey(currentSegment),
          currentSegment,
        ),
      );
    }
  }
  return sections;
}

int _compareRecordChronologically(TimingRecord a, TimingRecord b) {
  final byDate = a.startDate.compareTo(b.startDate);
  if (byDate != 0) return byDate;
  return (a.id ?? 0).compareTo(b.id ?? 0);
}

bool _belongsToSameContinuousSegment(
  TimingRecord previous,
  TimingRecord current,
) {
  return previous.contact == current.contact && previous.site == current.site;
}

class SectionRecentRecords extends StatefulWidget {
  final List<TimingRecord> records;
  final Map<int, Device> deviceById;
  final Map<int, String> deviceIndexById;
  final ValueChanged<TimingRecord>? onTapRecord;

  const SectionRecentRecords({
    super.key,
    required this.records,
    required this.deviceById,
    required this.deviceIndexById,
    this.onTapRecord,
  });

  @override
  State<SectionRecentRecords> createState() => _SectionRecentRecordsState();
}

class _SectionRecentRecordsState extends State<SectionRecentRecords> {
  final Set<String> _locallyRemovedKeys = <String>{};
  final Set<String> _expandedAggregateKeys = <String>{};

  @override
  void didUpdateWidget(covariant SectionRecentRecords oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentKeys = timingRecentRecordKeys(widget.records);
    _locallyRemovedKeys.removeWhere((k) => !currentKeys.contains(k));
    final visibleRecords = widget.records
        .where((r) => !_locallyRemovedKeys.contains(_recordKey(r)))
        .toList();
    final currentAggregateKeys = _buildAggregateSections(
      visibleRecords,
    ).map((section) => section.key).toSet();
    _expandedAggregateKeys.removeWhere(
      (key) => !currentAggregateKeys.contains(key),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleRecords = widget.records
        .where((r) => !_locallyRemovedKeys.contains(_recordKey(r)))
        .toList();

    if (visibleRecords.isEmpty) {
      return const AppRecentRecordsEmptyState();
    }

    final displaySections = _buildRecordDisplaySections(visibleRecords);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: displaySections.map((section) {
        final aggregate = section.aggregate;
        if (aggregate != null) {
          final expanded = _expandedAggregateKeys.contains(aggregate.key);
          return _DateGroup(
            ymd: section.ymd,
            aggregateSection: aggregate,
            aggregateExpanded: expanded,
            onToggleAggregate: () {
              setState(() {
                if (expanded) {
                  _expandedAggregateKeys.remove(aggregate.key);
                } else {
                  _expandedAggregateKeys.add(aggregate.key);
                }
              });
            },
            deviceById: widget.deviceById,
            deviceIndexById: widget.deviceIndexById,
            onTapRecord: widget.onTapRecord,
          );
        }

        return _DateGroup(
          ymd: section.ymd,
          items: section.records,
          headerOverride: section.headerOverride,
          deviceById: widget.deviceById,
          deviceIndexById: widget.deviceIndexById,
          onTapRecord: widget.onTapRecord,
        );
      }).toList(),
    );
  }
}

class _RecordDisplaySection {
  const _RecordDisplaySection._({
    required this.ymd,
    required this.records,
    required this.sortId,
    this.headerOverride,
    this.aggregate,
  });

  factory _RecordDisplaySection.singles({
    required int ymd,
    required List<TimingRecord> records,
    String? headerOverride,
  }) {
    final sortId = records.fold<int>(0, (current, record) {
      final id = record.id ?? 0;
      return id > current ? id : current;
    });
    return _RecordDisplaySection._(
      ymd: ymd,
      records: records,
      sortId: sortId,
      headerOverride: headerOverride,
    );
  }

  factory _RecordDisplaySection.aggregate(_AggregateRecordSection aggregate) {
    return _RecordDisplaySection._(
      ymd: aggregate.ymd,
      records: const [],
      sortId: aggregate.sortId,
      aggregate: aggregate,
    );
  }

  final int ymd;
  final List<TimingRecord> records;
  final int sortId;
  final String? headerOverride;
  final _AggregateRecordSection? aggregate;
}

class _AggregateRecordSection {
  const _AggregateRecordSection({
    required this.key,
    required this.records,
    required this.summaryRecord,
    required this.ymd,
    required this.sortId,
    required this.deviceId,
    required this.totalHours,
    required this.meterError,
  });

  factory _AggregateRecordSection.fromRecords(
    String key,
    List<TimingRecord> sourceRecords,
  ) {
    final chronologicalRecords = [...sourceRecords]
      ..sort((a, b) {
        final byDate = a.startDate.compareTo(b.startDate);
        if (byDate != 0) return byDate;
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });
    final displayRecords = [...chronologicalRecords]
      ..sort((a, b) {
        final byDate = b.startDate.compareTo(a.startDate);
        if (byDate != 0) return byDate;
        return (b.id ?? 0).compareTo(a.id ?? 0);
      });
    final first = chronologicalRecords.first;
    final last = chronologicalRecords.last;
    var totalHours = 0.0;
    var totalIncome = 0.0;
    final sortId = last.id ?? 0;

    for (final record in chronologicalRecords) {
      totalHours += record.hours;
      totalIncome += record.income;
    }

    final summaryRecord = TimingRecord(
      deviceId: first.deviceId,
      startDate: first.startDate,
      contact: first.contact,
      site: first.site,
      type: TimingType.hours,
      startMeter: first.startMeter,
      endMeter: last.endMeter,
      hours: totalHours,
      income: totalIncome,
      excludeFromFuelEfficiency: first.excludeFromFuelEfficiency,
      isBreaking: false,
    );

    return _AggregateRecordSection(
      key: key,
      records: displayRecords,
      summaryRecord: summaryRecord,
      ymd: first.startDate,
      sortId: sortId,
      deviceId: first.deviceId,
      totalHours: totalHours,
      meterError: ((last.endMeter - first.startMeter) - totalHours).abs(),
    );
  }

  final String key;
  final List<TimingRecord> records;
  final TimingRecord summaryRecord;
  final int ymd;
  final int sortId;
  final int deviceId;
  final double totalHours;
  final double meterError;
}

class _DateGroup extends StatelessWidget {
  final int ymd;
  final List<TimingRecord> items;
  final String? headerOverride;
  final _AggregateRecordSection? aggregateSection;
  final bool aggregateExpanded;
  final VoidCallback? onToggleAggregate;
  final Map<int, Device> deviceById;
  final Map<int, String> deviceIndexById;
  final ValueChanged<TimingRecord>? onTapRecord;

  const _DateGroup({
    required this.ymd,
    this.items = const [],
    this.headerOverride,
    this.aggregateSection,
    this.aggregateExpanded = false,
    this.onToggleAggregate,
    required this.deviceById,
    required this.deviceIndexById,
    this.onTapRecord,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final aggregate = aggregateSection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: TimingTokens.dateHeaderLeftInset,
          ),
          child: Text(
            aggregate == null
                ? headerOverride ?? FormatUtils.date(ymd)
                : '${FormatUtils.date(ymd)} (${aggregateExpanded ? '已展开' : '已聚合'})',
            style: textTheme.bodySmall?.copyWith(
              fontSize: TimingTokens.dateHeaderFontSize,
              color: AppColors.textPrimary,
              height: TimingTokens.dateHeaderLineHeight,
            ),
          ),
        ),
        const Divider(
          height: TimingTokens.recordDividerThickness,
          thickness: TimingTokens.recordDividerThickness,
          color: TimingColors.divider,
        ),
        if (aggregate != null) ...[
          _RecordRow(
            record: aggregate.summaryRecord,
            device: deviceById[aggregate.deviceId],
            deviceIndexText: deviceIndexById[aggregate.deviceId] ?? '?',
            subtitleEmphasis: deviceIndexById[aggregate.deviceId] ?? '?',
            subtitleSecondary: ' ${aggregate.records.length}条记录',
            bottomRightOverride:
                '误差 ${FormatUtils.meter(aggregate.meterError)}，累计 ${FormatUtils.hours(aggregate.totalHours)}',
            onTap: onToggleAggregate,
          ),
          if (aggregateExpanded)
            ...aggregate.records.map(
              (record) => _RecordRow(
                record: record,
                device: deviceById[record.deviceId],
                deviceIndexText: deviceIndexById[record.deviceId] ?? '?',
                hideAvatar: true,
                titleOverride: _dateRangeText(record),
                subtitleOverride: deviceById[record.deviceId] == null
                    ? deviceIndexById[record.deviceId] ?? '?'
                    : '${deviceById[record.deviceId]!.brand}${deviceIndexById[record.deviceId] ?? '?'}',
                subtitleEmphasized: false,
                bottomRightOverride: record.isBreaking
                    ? '破碎 ${FormatUtils.hours(record.hours)}'
                    : FormatUtils.hours(record.hours),
                onTap: onTapRecord == null ? null : () => onTapRecord!(record),
              ),
            ),
        ] else
          ...items.map(
            (record) => _RecordRow(
              record: record,
              device: deviceById[record.deviceId],
              deviceIndexText: deviceIndexById[record.deviceId] ?? '?',
              onTap: onTapRecord == null ? null : () => onTapRecord!(record),
            ),
          ),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  final TimingRecord record;
  final Device? device;
  final String deviceIndexText;
  final bool hideAvatar;
  final String? titleOverride;
  final String? subtitleOverride;
  final String? subtitleEmphasis;
  final String? subtitleSecondary;
  final bool subtitleEmphasized;
  final String? bottomRightOverride;
  final VoidCallback? onTap;

  const _RecordRow({
    required this.record,
    required this.device,
    required this.deviceIndexText,
    this.hideAvatar = false,
    this.titleOverride,
    this.subtitleOverride,
    this.subtitleEmphasis,
    this.subtitleSecondary,
    this.subtitleEmphasized = true,
    this.bottomRightOverride,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.bodyMedium?.copyWith(
      fontSize: TimingTokens.recordTitleFontSize,
      color: AppColors.textPrimary,
      height: TimingTokens.recordTitleLineHeight,
    );
    final subTitleStyle = textTheme.bodyMedium?.copyWith(
      fontSize: TimingTokens.recordSubTitleFontSize,
      fontWeight: subtitleEmphasized ? FontWeight.w700 : FontWeight.w400,
      color: AppColors.textPrimary,
      height: 1,
    );
    final subTitleSecondaryStyle = subTitleStyle?.copyWith(
      fontSize: TimingTokens.recordValueFontSize - 1,
      fontWeight: FontWeight.w400,
      height: 1,
    );
    final valueStyle = textTheme.bodyMedium?.copyWith(
      fontSize: TimingTokens.recordValueFontSize,
      color: AppColors.textPrimary,
      height: 1,
    );
    final content = Material(
      color: SheetColors.background,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: TimingTokens.recordRowHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              TimingTokens.recordRowPaddingLeft,
              0,
              TimingTokens.recordRowPaddingRight,
              0,
            ),
            child: Row(
              children: [
                if (hideAvatar)
                  Transform.translate(
                    offset: const Offset(0, TimingTokens.recordAvatarOffsetY),
                    child: const SizedBox(
                      width: TimingTokens.recordAvatarSize,
                      height: TimingTokens.recordAvatarSize,
                    ),
                  )
                else if (device != null)
                  Transform.translate(
                    offset: const Offset(0, TimingTokens.recordAvatarOffsetY),
                    child: SizedBox(
                      width: TimingTokens.recordAvatarSize,
                      height: TimingTokens.recordAvatarSize,
                      child: DeviceAvatar(
                        brand: device!.brand,
                        customAvatarPath: device!.customAvatarPath,
                        radius: TimingTokens.recordAvatarSize / 2,
                      ),
                    ),
                  )
                else
                  Transform.translate(
                    offset: const Offset(0, TimingTokens.recordAvatarOffsetY),
                    child: Container(
                      width: TimingTokens.recordAvatarSize,
                      height: TimingTokens.recordAvatarSize,
                      decoration: const BoxDecoration(
                        color: TimingColors.avatar,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                const SizedBox(width: TimingTokens.recordAvatarRightGap),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleOverride ??
                            ProjectTitleFormatter.project(
                              contact: record.contact,
                              site: record.site,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      const SizedBox(height: TimingTokens.recordSubTitleTopGap),
                      if (subtitleEmphasis != null || subtitleSecondary != null)
                        RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: [
                              if (subtitleEmphasis != null)
                                TextSpan(
                                  text: subtitleEmphasis,
                                  style: subTitleStyle,
                                ),
                              if (subtitleSecondary != null)
                                TextSpan(
                                  text: subtitleSecondary,
                                  style: subTitleSecondaryStyle,
                                ),
                            ],
                          ),
                        )
                      else
                        Text(
                          subtitleOverride ?? deviceIndexText,
                          style: subTitleStyle,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: TimingTokens.recordValueLeftGap),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: valueStyle,
                        children: [
                          TextSpan(text: FormatUtils.meter(record.startMeter)),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: Icon(
                                Icons.arrow_right_alt,
                                size: TimingTokens.recordValueFontSize + 2,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          TextSpan(text: FormatUtils.meter(record.endMeter)),
                        ],
                      ),
                    ),
                    const SizedBox(height: TimingTokens.recordValueBottomGap),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (bottomRightOverride != null)
                          Text(bottomRightOverride!, style: valueStyle)
                        else ...[
                          if (record.isBreaking) ...[
                            Text('破碎', style: valueStyle),
                            const SizedBox(
                              width: TimingTokens.recordHoursIncomeGap,
                            ),
                          ],
                          if (shouldShowDurationForTimingRecord(record))
                            Text(
                              FormatUtils.hours(record.hours),
                              style: valueStyle,
                            ),
                          if (record.type == TimingType.rent) ...[
                            if (shouldShowDurationForTimingRecord(record))
                              const SizedBox(
                                width: TimingTokens.recordHoursIncomeGap,
                              ),
                            Text(
                              FormatUtils.money(record.income),
                              style: valueStyle,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return content;
  }
}
