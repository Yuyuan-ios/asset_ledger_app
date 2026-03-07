import 'package:flutter/material.dart';

import '../../core/foundation/spacing.dart';
import '../../core/foundation/typography.dart';
import '../../data/models/fuel_log.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/fuel_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';
import '../../core/utils/format_utils.dart';
import '../timing/records_title_pattern.dart';

typedef DeleteFuelRecordCallback = Future<bool> Function(FuelLog log);

class FuelRecentRecordsSection extends StatefulWidget {
  final List<FuelLog> logs;
  final Widget Function(FuelLog log) leadingBuilder;
  final String Function(FuelLog log) titleBuilder;
  final String Function(FuelLog log) subtitleBuilder;
  final ValueChanged<FuelLog> onTap;
  final Future<bool> Function(FuelLog log)? onConfirmDelete;
  final DeleteFuelRecordCallback? onDelete;

  const FuelRecentRecordsSection({
    super.key,
    required this.logs,
    required this.leadingBuilder,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.onTap,
    this.onConfirmDelete,
    this.onDelete,
  });

  @override
  State<FuelRecentRecordsSection> createState() =>
      _FuelRecentRecordsSectionState();
}

class _FuelRecentRecordsSectionState extends State<FuelRecentRecordsSection> {
  final Set<String> _locallyRemovedKeys = <String>{};

  String _recordKey(FuelLog r) {
    return 'fuel-${r.id ?? '${r.date}-${r.deviceId}-${r.supplier}-${r.liters}-${r.cost}'}';
  }

  @override
  void didUpdateWidget(covariant FuelRecentRecordsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentKeys = widget.logs.map(_recordKey).toSet();
    _locallyRemovedKeys.removeWhere((k) => !currentKeys.contains(k));
  }

  Future<void> _deleteWithOptimisticRemove(FuelLog log) async {
    if (widget.onDelete == null) return;
    final key = _recordKey(log);
    setState(() => _locallyRemovedKeys.add(key));
    final ok = await widget.onDelete!(log);
    if (!ok && mounted) {
      setState(() => _locallyRemovedKeys.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleLogs = widget.logs
        .where((r) => !_locallyRemovedKeys.contains(_recordKey(r)))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RecordsTitle(count: visibleLogs.length),
        SizedBox(height: FuelTokens.recordsTitleTopGap),
        _FuelGroupedList(
          logs: visibleLogs,
          leadingBuilder: widget.leadingBuilder,
          titleBuilder: widget.titleBuilder,
          subtitleBuilder: widget.subtitleBuilder,
          onTap: widget.onTap,
          onConfirmDelete: widget.onConfirmDelete,
          onDelete: _deleteWithOptimisticRemove,
        ),
      ],
    );
  }
}

class _FuelGroupedList extends StatelessWidget {
  final List<FuelLog> logs;
  final Widget Function(FuelLog log) leadingBuilder;
  final String Function(FuelLog log) titleBuilder;
  final String Function(FuelLog log) subtitleBuilder;
  final ValueChanged<FuelLog> onTap;
  final Future<bool> Function(FuelLog log)? onConfirmDelete;
  final Future<void> Function(FuelLog log)? onDelete;

  const _FuelGroupedList({
    required this.logs,
    required this.leadingBuilder,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.onTap,
    required this.onConfirmDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final emptyTitleStyle = AppTypography.bodySecondary(
      context,
      fontSize: TimingTokens.emptyStateTitleFontSize,
      color: TimingColors.textSecondary,
    );
    final emptySubtitleStyle = AppTypography.caption(
      context,
      fontSize: TimingTokens.emptyStateSubtitleFontSize,
      color: TimingColors.textTertiary,
    );

    if (logs.isEmpty) {
      return SizedBox(
        height: TimingTokens.emptyStateHeight,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('暂无记录', style: emptyTitleStyle),
              const SizedBox(height: TimingTokens.emptyStateSubtitleTopGap),
              Text('点击右上角 + 新建', style: emptySubtitleStyle),
            ],
          ),
        ),
      );
    }

    final grouped = <int, List<FuelLog>>{};
    for (final log in logs) {
      grouped.putIfAbsent(log.date, () => <FuelLog>[]).add(log);
    }

    final flat = <FuelLog>[];
    for (final entry in grouped.entries) {
      flat.addAll(entry.value);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < flat.length; i++) ...[
          if (i == 0 || flat[i].date != flat[i - 1].date)
            const Divider(
              height: TimingTokens.recordDividerThickness,
              thickness: TimingTokens.recordDividerThickness,
              color: TimingColors.divider,
            ),
          _FuelRecordRow(
            log: flat[i],
            leadingBuilder: leadingBuilder,
            titleBuilder: (l) =>
                '${titleBuilder(l)}•${FormatUtils.date(l.date)}',
            subtitleBuilder: subtitleBuilder,
            onTap: () => onTap(flat[i]),
            onConfirmDelete: onConfirmDelete == null
                ? null
                : () => onConfirmDelete!(flat[i]),
            onDelete: onDelete == null ? null : () => onDelete!(flat[i]),
          ),
        ],
      ],
    );
  }
}

// 日期分组已移除：日期显示在每行标题中

class _FuelRecordRow extends StatelessWidget {
  final FuelLog log;
  final Widget Function(FuelLog log) leadingBuilder;
  final String Function(FuelLog log) titleBuilder;
  final String Function(FuelLog log) subtitleBuilder;
  final VoidCallback onTap;
  final Future<bool> Function()? onConfirmDelete;
  final Future<void> Function()? onDelete;

  const _FuelRecordRow({
    required this.log,
    required this.leadingBuilder,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.onTap,
    this.onConfirmDelete,
    this.onDelete,
  });

  TextStyle? _valueStyle(BuildContext context, {FontWeight? fontWeight}) {
    return AppTypography.body(
      context,
      fontSize: TimingTokens.recordValueFontSize,
      fontWeight: fontWeight,
      height: 1,
      color: AppColors.textPrimary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTypography.body(
      context,
      fontSize: TimingTokens.recordTitleFontSize,
      height: TimingTokens.recordTitleLineHeight,
      color: AppColors.textPrimary,
    );
    final subTitleStyle = AppTypography.body(
      context,
      fontSize: TimingTokens.recordSubTitleFontSize,
      height: 1,
      color: AppColors.textPrimary,
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
                leadingBuilder(log),
                const SizedBox(width: TimingTokens.recordAvatarRightGap),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleBuilder(log),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      const SizedBox(height: TimingTokens.recordSubTitleTopGap),
                      Text(subtitleBuilder(log), style: subTitleStyle),
                    ],
                  ),
                ),
                const SizedBox(width: TimingTokens.recordValueLeftGap),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${FormatUtils.liters(log.liters)} L',
                      style: _valueStyle(context),
                    ),
                    const SizedBox(height: TimingTokens.recordValueBottomGap),
                    Text(
                      FormatUtils.money(log.cost),
                      style: _valueStyle(context, fontWeight: FontWeight.w700),
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
        'fuel-${log.id ?? '${log.date}-${log.deviceId}-${log.supplier}-${log.liters}-${log.cost}'}',
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
