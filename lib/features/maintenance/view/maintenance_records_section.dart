import 'package:flutter/material.dart';

import '../../../components/feedback/app_records_empty_hint.dart';
import '../../../core/foundation/spacing.dart';
import '../../../core/foundation/typography.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../domain/entities/maintenance_entities.dart';
import '../../../tokens/mapper/core_tokens.dart';
import '../../../tokens/mapper/fuel_tokens.dart';
import '../../../tokens/mapper/timing_tokens.dart';
import '../../../patterns/layout/record_card_surface.dart';
import '../../../patterns/timing/records_title_pattern.dart';
import 'maintenance_page_view_data.dart';

typedef DeleteMaintenanceRecordCallback =
    Future<bool> Function(MaintenanceRecord record);

String maintenanceRecentRecordKey(MaintenanceRecord record) {
  return 'maintenance-${record.id ?? '${record.ymd}-${record.deviceId}-${record.item}-${record.effectiveAmountFen}'}';
}

Set<String> maintenanceRecentRecordKeys(List<MaintenanceRecordRowVM> rows) {
  return rows.map((row) => maintenanceRecentRecordKey(row.record)).toSet();
}

class MaintenanceRecordsSection extends StatelessWidget {
  const MaintenanceRecordsSection({
    super.key,
    required this.rows,
    required this.onEdit,
    required this.onConfirmDelete,
    required this.onDelete,
  });

  final List<MaintenanceRecordRowVM> rows;
  final ValueChanged<MaintenanceRecord> onEdit;
  final Future<bool> Function(MaintenanceRecord record) onConfirmDelete;
  final DeleteMaintenanceRecordCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RecordsTitle(
          count: rows.length,
          title: l10n.commonRecentRecordsCount(rows.length),
        ),
        const SizedBox(height: FuelTokens.recordsTitleTopGap),
        MaintenanceRecordsContent(
          rows: rows,
          onEdit: onEdit,
          onConfirmDelete: onConfirmDelete,
          onDelete: onDelete,
        ),
      ],
    );
  }
}

class MaintenanceRecordsContent extends StatefulWidget {
  const MaintenanceRecordsContent({
    super.key,
    required this.rows,
    required this.onEdit,
    required this.onConfirmDelete,
    required this.onDelete,
  });

  final List<MaintenanceRecordRowVM> rows;
  final ValueChanged<MaintenanceRecord> onEdit;
  final Future<bool> Function(MaintenanceRecord record) onConfirmDelete;
  final DeleteMaintenanceRecordCallback onDelete;

  @override
  State<MaintenanceRecordsContent> createState() =>
      _MaintenanceRecordsContentState();
}

class _MaintenanceRecordsContentState extends State<MaintenanceRecordsContent> {
  final Set<String> _locallyRemovedKeys = <String>{};

  @override
  void didUpdateWidget(covariant MaintenanceRecordsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentKeys = maintenanceRecentRecordKeys(widget.rows);
    _locallyRemovedKeys.removeWhere((key) => !currentKeys.contains(key));
  }

  Future<void> _deleteWithOptimisticRemove(MaintenanceRecord record) async {
    final key = maintenanceRecentRecordKey(record);
    setState(() => _locallyRemovedKeys.add(key));
    final ok = await widget.onDelete(record);
    if (!ok && mounted) {
      setState(() => _locallyRemovedKeys.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visibleRows = widget.rows
        .where(
          (row) => !_locallyRemovedKeys.contains(
            maintenanceRecentRecordKey(row.record),
          ),
        )
        .toList();
    final rowTitleStyle = AppTypography.body(
      context,
      fontSize: TimingTokens.recordTitleFontSize,
      height: TimingTokens.recordTitleLineHeight,
      color: AppColors.textPrimary,
    );
    final rowSubtitleStyle = AppTypography.body(
      context,
      fontSize: TimingTokens.recordSubTitleFontSize,
      fontWeight: FontWeight.w700,
      height: 1,
      color: AppColors.textPrimary,
    );
    final rowValueStyle = AppTypography.body(
      context,
      fontSize: TimingTokens.recordValueFontSize,
      height: 1,
      color: AppColors.textPrimary,
    );
    final rowAmountStyle = AppTypography.body(
      context,
      fontSize: TimingTokens.recordValueFontSize,
      height: 1,
      color: AppColors.textPrimary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (visibleRows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xxl),
            child: AppRecentRecordsEmptyState(
              title: l10n.commonNoRecordsTitle,
              subtitle: l10n.commonCreateFromTopRightHint,
            ),
          )
        else
          RecordCardSurface(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < visibleRows.length; index++) ...[
                  if (index > 0)
                    const Divider(
                      height: TimingTokens.recordDividerThickness,
                      thickness: TimingTokens.recordDividerThickness,
                      color: TimingColors.divider,
                    ),
                  Builder(
                    builder: (context) {
                      final row = visibleRows[index];
                      final record = row.record;

                      final content = Material(
                        color: SheetColors.background,
                        child: InkWell(
                          onTap: () => widget.onEdit(record),
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
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: rowTitleStyle,
                                        ),
                                        const SizedBox(
                                          height:
                                              TimingTokens.recordSubTitleTopGap,
                                        ),
                                        Text(
                                          row.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: rowSubtitleStyle,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(
                                    width: TimingTokens.recordValueLeftGap,
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(row.dateText, style: rowValueStyle),
                                      const SizedBox(
                                        height:
                                            TimingTokens.recordValueBottomGap,
                                      ),
                                      Text(
                                        row.amountText,
                                        style: rowAmountStyle,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );

                      return Dismissible(
                        key: ValueKey(maintenanceRecentRecordKey(record)),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red.shade500,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.lg,
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                        ),
                        confirmDismiss: (_) => widget.onConfirmDelete(record),
                        onDismissed: (_) => _deleteWithOptimisticRemove(record),
                        child: content,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
