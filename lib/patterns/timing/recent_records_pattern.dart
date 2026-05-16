import 'package:flutter/material.dart';

import '../../core/foundation/spacing.dart';
import '../../data/models/device.dart';
import '../../data/models/timing_record.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';
import '../../core/utils/format_utils.dart';
import '../../components/avatars/app_device_avatar.dart';
import '../../components/feedback/app_records_empty_hint.dart';
import '../../components/layout/pinned_header_delegate.dart';

part 'timing_recent_records_slivers.dart';

typedef DeleteRecordCallback = Future<bool> Function(TimingRecord record);
typedef DeleteRecordsCallback =
    Future<bool> Function(List<TimingRecord> records);

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
  for (final record in singleRecords) {
    groupedSingles
        .putIfAbsent(record.startDate, () => <TimingRecord>[])
        .add(record);
  }

  return <_RecordDisplaySection>[
    for (final entry in groupedSingles.entries)
      _RecordDisplaySection.singles(ymd: entry.key, records: entry.value),
    for (final section in aggregateSections)
      _RecordDisplaySection.aggregate(section),
  ]..sort((a, b) {
    final byDate = b.ymd.compareTo(a.ymd);
    if (byDate != 0) return byDate;
    return b.sortId.compareTo(a.sortId);
  });
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
  final Future<bool> Function(TimingRecord)? onConfirmDeleteRecord;
  final DeleteRecordCallback? onDeleteRecord;
  final Future<bool> Function(List<TimingRecord>)? onConfirmDeleteRecords;
  final DeleteRecordsCallback? onDeleteRecords;

  const SectionRecentRecords({
    super.key,
    required this.records,
    required this.deviceById,
    required this.deviceIndexById,
    this.onTapRecord,
    this.onConfirmDeleteRecord,
    this.onDeleteRecord,
    this.onConfirmDeleteRecords,
    this.onDeleteRecords,
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

  Future<void> _deleteWithOptimisticRemove(TimingRecord record) async {
    if (widget.onDeleteRecord == null) return;
    final key = _recordKey(record);
    setState(() => _locallyRemovedKeys.add(key));
    final ok = await widget.onDeleteRecord!(record);
    if (!ok && mounted) {
      setState(() => _locallyRemovedKeys.remove(key));
    }
  }

  Future<void> _deleteAggregateWithOptimisticRemove(
    _AggregateRecordSection aggregate,
  ) async {
    if (widget.onDeleteRecords == null) return;
    final keys = aggregate.records.map(_recordKey).toSet();
    setState(() {
      _locallyRemovedKeys.addAll(keys);
      _expandedAggregateKeys.remove(aggregate.key);
    });
    final ok = await widget.onDeleteRecords!(aggregate.records);
    if (!ok && mounted) {
      setState(() => _locallyRemovedKeys.removeAll(keys));
    }
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
            onConfirmDeleteRecord: widget.onConfirmDeleteRecord,
            onDeleteRecord: _deleteWithOptimisticRemove,
            onConfirmDeleteRecords: widget.onConfirmDeleteRecords,
            onDeleteRecords: _deleteAggregateWithOptimisticRemove,
          );
        }

        return _DateGroup(
          ymd: section.ymd,
          items: section.records,
          deviceById: widget.deviceById,
          deviceIndexById: widget.deviceIndexById,
          onTapRecord: widget.onTapRecord,
          onConfirmDeleteRecord: widget.onConfirmDeleteRecord,
          onDeleteRecord: _deleteWithOptimisticRemove,
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
    this.aggregate,
  });

  factory _RecordDisplaySection.singles({
    required int ymd,
    required List<TimingRecord> records,
  }) {
    final sortId = records.fold<int>(0, (current, record) {
      final id = record.id ?? 0;
      return id > current ? id : current;
    });
    return _RecordDisplaySection._(ymd: ymd, records: records, sortId: sortId);
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
  final _AggregateRecordSection? aggregateSection;
  final bool aggregateExpanded;
  final VoidCallback? onToggleAggregate;
  final Map<int, Device> deviceById;
  final Map<int, String> deviceIndexById;
  final ValueChanged<TimingRecord>? onTapRecord;
  final Future<bool> Function(TimingRecord)? onConfirmDeleteRecord;
  final Future<void> Function(TimingRecord)? onDeleteRecord;
  final Future<bool> Function(List<TimingRecord>)? onConfirmDeleteRecords;
  final Future<void> Function(_AggregateRecordSection)? onDeleteRecords;

  const _DateGroup({
    required this.ymd,
    this.items = const [],
    this.aggregateSection,
    this.aggregateExpanded = false,
    this.onToggleAggregate,
    required this.deviceById,
    required this.deviceIndexById,
    this.onTapRecord,
    this.onConfirmDeleteRecord,
    this.onDeleteRecord,
    this.onConfirmDeleteRecords,
    this.onDeleteRecords,
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
                ? FormatUtils.date(ymd)
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
            dismissibleKey: aggregate.key,
            subtitleEmphasis: deviceIndexById[aggregate.deviceId] ?? '?',
            subtitleSecondary: ' 工时调整',
            bottomRightOverride:
                '误差 ${FormatUtils.meter(aggregate.meterError)}，累计 ${FormatUtils.hours(aggregate.totalHours)}',
            onTap: onToggleAggregate,
            onConfirmDelete: onConfirmDeleteRecords == null
                ? null
                : () => onConfirmDeleteRecords!(aggregate.records),
            onDelete: onDeleteRecords == null
                ? null
                : () => onDeleteRecords!(aggregate),
          ),
          if (aggregateExpanded)
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
                onTap: onTapRecord == null ? null : () => onTapRecord!(record),
                onConfirmDelete: onConfirmDeleteRecord == null
                    ? null
                    : () => onConfirmDeleteRecord!(record),
                onDelete: onDeleteRecord == null
                    ? null
                    : () => onDeleteRecord!(record),
              ),
            ),
        ] else
          ...items.map(
            (record) => _RecordRow(
              record: record,
              device: deviceById[record.deviceId],
              deviceIndexText: deviceIndexById[record.deviceId] ?? '?',
              onTap: onTapRecord == null ? null : () => onTapRecord!(record),
              onConfirmDelete: onConfirmDeleteRecord == null
                  ? null
                  : () => onConfirmDeleteRecord!(record),
              onDelete: onDeleteRecord == null
                  ? null
                  : () => onDeleteRecord!(record),
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
  final String? dismissibleKey;
  final VoidCallback? onTap;
  final Future<bool> Function()? onConfirmDelete;
  final Future<void> Function()? onDelete;

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
    this.dismissibleKey,
    this.onTap,
    this.onConfirmDelete,
    this.onDelete,
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
      fontWeight: FontWeight.w400,
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
                        titleOverride ?? '${record.contact}·${record.site}',
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

    if (onConfirmDelete == null || onDelete == null) return content;

    return Dismissible(
      key: ValueKey(
        dismissibleKey ??
            'timing-${record.id ?? '${record.startDate}-${record.deviceId}-${record.contact}-${record.site}'}',
      ),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade500,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => onConfirmDelete!(),
      onDismissed: (_) {
        onDelete!();
      },
      child: content,
    );
  }
}
