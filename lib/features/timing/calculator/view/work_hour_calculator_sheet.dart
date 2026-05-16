import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// [新增] 满足 no_textstyle_in_migrated_modules：用 AppTypography 替代 TextStyle 构造
import '../../../../core/foundation/typography.dart';
import '../../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../model/staged_timing_calculation_history.dart';
import '../model/timing_calculation_history.dart';
import '../service/work_hour_calculator_service.dart';
import '../store/timing_calculator_store.dart';
import 'calculation_history_list.dart';
import 'calculator_keypad.dart';

class WorkHourCalculatorSheet extends StatelessWidget {
  const WorkHourCalculatorSheet({
    super.key,
    required this.initialHours,
    this.existingHistories = const [],
    required this.initialStagedHistories,
    required this.onResultApplied,
    required this.onHistoriesChanged,
  });

  final double? initialHours;
  final List<TimingCalculationHistory> existingHistories;
  final List<StagedTimingCalculationHistory> initialStagedHistories;
  final ValueChanged<double> onResultApplied;
  final ValueChanged<List<StagedTimingCalculationHistory>> onHistoriesChanged;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TimingCalculatorStore(
        service: WorkHourCalculatorService(),
        initialHours: initialHours,
      ),
      child: _WorkHourCalculatorSheetBody(
        existingHistories: List.unmodifiable(existingHistories),
        initialStagedHistories: List.unmodifiable(initialStagedHistories),
        onResultApplied: onResultApplied,
        onHistoriesChanged: onHistoriesChanged,
      ),
    );
  }
}

class _WorkHourCalculatorSheetBody extends StatelessWidget {
  const _WorkHourCalculatorSheetBody({
    required this.existingHistories,
    required this.initialStagedHistories,
    required this.onResultApplied,
    required this.onHistoriesChanged,
  });

  final List<TimingCalculationHistory> existingHistories;
  final List<StagedTimingCalculationHistory> initialStagedHistories;
  final ValueChanged<double> onResultApplied;
  final ValueChanged<List<StagedTimingCalculationHistory>> onHistoriesChanged;

  @override
  Widget build(BuildContext context) {
    return AppBottomSheetShell(
      title: '工时计算依据',
      scrollable: false,
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      cancelText: '关闭',
      confirmText: '完成',
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () => Navigator.of(context).pop(),
      child: Consumer<TimingCalculatorStore>(
        builder: (context, store, _) {
          final stagedHistories = _combinedStagedHistories(store);
          return Column(
            children: [
              _CalculatorDisplay(store: store),
              const SizedBox(height: 12),
              Expanded(
                child: CalculationHistoryList(
                  existingHistories: existingHistories,
                  stagedHistories: stagedHistories,
                ),
              ),
              const SizedBox(height: 12),
              CalculatorKeypad(
                onDigit: store.pressDigit,
                onDecimal: store.pressDecimalPoint,
                onPlus: store.pressPlus,
                onBackspace: store.pressBackspace,
                onClear: store.pressClear,
                onEqual: () => _handleEqual(store),
              ),
            ],
          );
        },
      ),
    );
  }

  List<StagedTimingCalculationHistory> _combinedStagedHistories(
    TimingCalculatorStore store,
  ) {
    return [...initialStagedHistories, ...store.stagedHistories];
  }

  void _handleEqual(TimingCalculatorStore store) {
    final beforeCount = store.stagedHistories.length;
    store.pressEqual();
    final result = store.lastResult;
    if (store.stagedHistories.length <= beforeCount || result == null) {
      return;
    }

    onResultApplied(result);
    onHistoriesChanged(_combinedStagedHistories(store));
  }
}

class _CalculatorDisplay extends StatelessWidget {
  const _CalculatorDisplay({required this.store});

  final TimingCalculatorStore store;

  @override
  Widget build(BuildContext context) {
    final expression = store.displayExpression.isEmpty
        ? '工时计算式'
        : store.displayExpression;
    final result = store.lastResult;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // [修改] 22px/w800 计算式显示 → AppTypography.pageTitle
          Text(
            expression,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.pageTitle(
              context,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: store.displayExpression.isEmpty
                  ? Colors.black38
                  : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 140),
            child: store.hasError
                // [修改] 错误信息 red/w600 → AppTypography.body
                ? Text(
                    store.errorMessage ?? '',
                    key: ValueKey(store.errorMessage),
                    style: AppTypography.body(
                      context,
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                // [修改] 结果/占位 black54/w600 → AppTypography.body
                : Text(
                    result == null
                        ? '未计算'
                        : '结果 ${result.toStringAsFixed(1)} h',
                    key: ValueKey(result),
                    style: AppTypography.body(
                      context,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
