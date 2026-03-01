import 'package:flutter/material.dart';

import '../../core/foundation/spacing.dart';
import '../../data/models/device.dart';
import '../../data/models/timing_record.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';
import '../../core/utils/format_utils.dart';
import '../../components/avatars/app_device_avatar.dart';

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
      return const SizedBox(
        height: TimingTokens.emptyStateHeight,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '暂无记录',
                style: TextStyle(
                  fontSize: TimingTokens.emptyStateTitleFontSize,
                  color: AppColors.timingTextSecondary,
                ),
              ),
              SizedBox(height: TimingTokens.emptyStateSubtitleTopGap),
              Text(
                '点击右上角 + 新建',
                style: TextStyle(
                  fontSize: TimingTokens.emptyStateSubtitleFontSize,
                  color: AppColors.timingTextTertiary,
                ),
              ),
            ],
          ),
        ),
      );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: TimingTokens.dateHeaderLeftInset,
          ),
          child: Text(
            FormatUtils.date(ymd),
            style: const TextStyle(
              fontSize: TimingTokens.dateHeaderFontSize,
              color: AppColors.textPrimary,
              height: TimingTokens.dateHeaderLineHeight,
            ),
          ),
        ),
        const Divider(
          height: TimingTokens.recordDividerThickness,
          thickness: TimingTokens.recordDividerThickness,
          color: AppColors.timingDivider,
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

  TextStyle get _valueStyle => const TextStyle(
    fontSize: TimingTokens.recordValueFontSize,
    color: AppColors.textPrimary,
    height: 1,
  );

  @override
  Widget build(BuildContext context) {
    final content = Material(
      color: AppColors.sheetBackground,
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
                  SizedBox(
                    width: TimingTokens.recordAvatarSize,
                    height: TimingTokens.recordAvatarSize,
                    child: DeviceAvatar(
                      brand: device!.brand,
                      customAvatarPath: device!.customAvatarPath,
                      radius: TimingTokens.recordAvatarSize / 2,
                    ),
                  )
                else
                  Container(
                    width: TimingTokens.recordAvatarSize,
                    height: TimingTokens.recordAvatarSize,
                    decoration: const BoxDecoration(
                      color: AppColors.timingAvatar,
                      shape: BoxShape.circle,
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
                        style: const TextStyle(
                          fontSize: TimingTokens.recordTitleFontSize,
                          color: AppColors.textPrimary,
                          height: TimingTokens.recordTitleLineHeight,
                        ),
                      ),
                      const SizedBox(height: TimingTokens.recordSubTitleTopGap),
                      Text(
                        deviceIndexText,
                        style: TextStyle(
                          fontSize: TimingTokens.recordSubTitleFontSize,
                          color: AppColors.textPrimary,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: TimingTokens.recordValueLeftGap),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${FormatUtils.meter(record.startMeter)} \u2192 ${FormatUtils.meter(record.endMeter)}',
                      style: _valueStyle,
                    ),
                    const SizedBox(height: TimingTokens.recordValueBottomGap),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          FormatUtils.hours(record.hours),
                          style: _valueStyle,
                        ),
                        if (record.type == TimingType.rent) ...[
                          const SizedBox(
                            width: TimingTokens.recordHoursIncomeGap,
                          ),
                          Text(
                            FormatUtils.money(record.income),
                            style: _valueStyle,
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
