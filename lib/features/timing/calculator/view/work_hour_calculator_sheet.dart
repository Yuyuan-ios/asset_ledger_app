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

const _sheetBackground = Color(0xFF050505);
const _sheetHandle = Color(0xFF5A514A);
const _displayBackground = Color(0xFF11140F);
const _displayBorder = Color(0xFF2B3529);
const _displayTextPrimary = Color(0xFFF2F2F2);
const _displayTextResult = Color(0xFFFFFFFF);
const _displayTextSecondary = Color(0xFF9A9A9A);
const _displayError = Color(0xFFFF7A6A);

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
      title: null,
      scrollable: false,
      contentPadding: EdgeInsets.zero,
      footerEnabled: false,
      backgroundColor: _sheetBackground,
      handleColor: _sheetHandle,
      child: Consumer<TimingCalculatorStore>(
        builder: (context, store, _) {
          final stagedHistories = _combinedStagedHistories(store);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _CalculatorDisplay(store: store),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: CalculationHistoryList(
                    existingHistories: existingHistories,
                    stagedHistories: stagedHistories,
                    latestAppliedHistory: store.latestHistory,
                  ),
                ),
              ),
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
    final primaryText = store.hasError
        ? store.errorMessage ?? ''
        : result == null
        ? '未计算'
        : '结果 ${result.toStringAsFixed(1)} h';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _displayBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _displayBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 140),
            child: Text(
              primaryText,
              key: ValueKey(primaryText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: AppTypography.pageTitle(
                context,
                fontSize: result == null || store.hasError ? 18 : 32,
                fontWeight: result == null || store.hasError
                    ? FontWeight.w600
                    : FontWeight.w700,
                color: store.hasError
                    ? _displayError
                    : result == null
                    ? _displayTextSecondary
                    : _displayTextResult,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            expression,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
            style: AppTypography.body(
              context,
              fontSize: store.displayExpression.isEmpty ? 18 : 22,
              fontWeight: store.displayExpression.isEmpty
                  ? FontWeight.w500
                  : FontWeight.w600,
              color: store.displayExpression.isEmpty
                  ? _displayTextSecondary.withValues(alpha: 0.72)
                  : _displayTextPrimary.withValues(alpha: 0.84),
            ),
          ),
        ],
      ),
    );
  }
}
