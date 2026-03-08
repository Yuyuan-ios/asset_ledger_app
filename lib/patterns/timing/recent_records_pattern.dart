import 'package:flutter/material.dart';

import '../../core/foundation/spacing.dart';
import '../../data/models/device.dart';
import '../../data/models/timing_record.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';
import '../../core/utils/format_utils.dart';
import '../../components/avatars/app_device_avatar.dart';
import '../../components/feedback/app_records_empty_hint.dart';

typedef DeleteRecordCallback = Future<bool> Function(TimingRecord record);

class SectionRecentRecords extends StatefulWidget {
  final List<TimingRecord> records;
  final Map<int, Device> deviceById;
  final Map<int, String> deviceIndexById;
  final ValueChanged<TimingRecord>? onTapRecord;
  final Future<bool> Function(TimingRecord)? onConfirmDeleteRecord;
  final DeleteRecordCallback? onDeleteRecord;

  const SectionRecentRecords({
    super.key,
    required this.records,
    required this.deviceById,
    required this.deviceIndexById,
    this.onTapRecord,
    this.onConfirmDeleteRecord,
    this.onDeleteRecord,
  });

  @override
  State<SectionRecentRecords> createState() => _SectionRecentRecordsState();
}

class _SectionRecentRecordsState extends State<SectionRecentRecords> {
  final Set<String> _locallyRemovedKeys = <String>{};

  String _recordKey(TimingRecord r) {
    return 'timing-${r.id ?? '${r.startDate}-${r.deviceId}-${r.contact}-${r.site}'}';
  }

  @override
  void didUpdateWidget(covariant SectionRecentRecords oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentKeys = widget.records.map(_recordKey).toSet();
    _locallyRemovedKeys.removeWhere((k) => !currentKeys.contains(k));
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

  @override
  Widget build(BuildContext context) {
    final visibleRecords = widget.records
        .where((r) => !_locallyRemovedKeys.contains(_recordKey(r)))
        .toList();

    if (visibleRecords.isEmpty) {
      return const AppRecentRecordsEmptyState();
    }

    final grouped = <int, List<TimingRecord>>{};
    for (final record in visibleRecords) {
      grouped.putIfAbsent(record.startDate, () => <TimingRecord>[]).add(record);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return _DateGroup(
          ymd: entry.key,
          items: entry.value,
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

class _DateGroup extends StatelessWidget {
  final int ymd;
  final List<TimingRecord> items;
  final Map<int, Device> deviceById;
  final Map<int, String> deviceIndexById;
  final ValueChanged<TimingRecord>? onTapRecord;
  final Future<bool> Function(TimingRecord)? onConfirmDeleteRecord;
  final Future<void> Function(TimingRecord)? onDeleteRecord;

  const _DateGroup({
    required this.ymd,
    required this.items,
    required this.deviceById,
    required this.deviceIndexById,
    this.onTapRecord,
    this.onConfirmDeleteRecord,
    this.onDeleteRecord,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: TimingTokens.dateHeaderLeftInset,
          ),
          child: Text(
            FormatUtils.date(ymd),
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
  final VoidCallback? onTap;
  final Future<bool> Function()? onConfirmDelete;
  final Future<void> Function()? onDelete;

  const _RecordRow({
    required this.record,
    required this.device,
    required this.deviceIndexText,
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
      color: AppColors.textPrimary,
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
                if (device != null)
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
                        '${record.contact}·${record.site}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      const SizedBox(height: TimingTokens.recordSubTitleTopGap),
                      Text(deviceIndexText, style: subTitleStyle),
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
                        if (record.isBreaking) ...[
                          Text('破碎', style: valueStyle),
                          const SizedBox(
                            width: TimingTokens.recordHoursIncomeGap,
                          ),
                        ],
                        Text(
                          FormatUtils.hours(record.hours),
                          style: valueStyle,
                        ),
                        if (record.type == TimingType.rent) ...[
                          const SizedBox(
                            width: TimingTokens.recordHoursIncomeGap,
                          ),
                          Text(
                            FormatUtils.money(record.income),
                            style: valueStyle,
                          ),
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
