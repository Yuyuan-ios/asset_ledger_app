import 'package:flutter/material.dart';

import '../../../components/feedback/app_records_empty_hint.dart';
import '../../../core/foundation/spacing.dart';
import '../../../core/foundation/typography.dart';
import '../../../data/models/maintenance_record.dart';
import '../../../tokens/mapper/core_tokens.dart';
import '../../../tokens/mapper/fuel_tokens.dart';
import '../../../tokens/mapper/timing_tokens.dart';
import '../../../patterns/timing/records_title_pattern.dart';
import 'maintenance_page_view_data.dart';

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
  final ValueChanged<MaintenanceRecord> onDelete;

  @override
  Widget build(BuildContext context) {
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
        RecordsTitle(count: rows.length),
        const SizedBox(height: FuelTokens.recordsTitleTopGap),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xxl),
            child: const AppRecentRecordsEmptyState(),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              thickness: 1,
              color: TimingColors.divider,
            ),
            itemBuilder: (context, index) {
              final row = rows[index];
              final record = row.record;

              final content = Material(
                color: SheetColors.background,
                child: InkWell(
                  onTap: () => onEdit(record),
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
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: rowTitleStyle,
                                ),
                                const SizedBox(
                                  height: TimingTokens.recordSubTitleTopGap,
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
                                height: TimingTokens.recordValueBottomGap,
                              ),
                              Text(row.amountText, style: rowAmountStyle),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );

              return Dismissible(
                key: ValueKey(
                  'maintenance-${record.id ?? '${record.ymd}-${record.deviceId}-${record.item}-${record.amount}'}',
                ),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red.shade500,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                confirmDismiss: (_) => onConfirmDelete(record),
                onDismissed: (_) => onDelete(record),
                child: content,
              );
            },
          ),
      ],
    );
  }
}
