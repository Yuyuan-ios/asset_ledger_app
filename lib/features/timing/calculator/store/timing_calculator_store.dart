import 'package:flutter/foundation.dart';

import '../model/staged_timing_calculation_history.dart';
import '../service/work_hour_calculator_service.dart';

class TimingCalculatorStore extends ChangeNotifier {
  TimingCalculatorStore({
    required WorkHourCalculatorService service,
    double? initialHours,
    DateTime Function()? now,
  }) : _service = service,
       _now = now ?? DateTime.now,
       _initialHours = initialHours {
    if (initialHours != null && initialHours > 0) {
      _expression = _formatHours(initialHours);
    }
  }

  final WorkHourCalculatorService _service;
  final DateTime Function() _now;

  String _expression = '';
  final double? _initialHours;
  double? _lastResult;
  String? _errorMessage;

  bool _hasUserStartedInput = false;
  bool _isContinuing = false;
  bool _hasEvaluatedOnce = false;

  final List<StagedTimingCalculationHistory> _stagedHistories = [];

  String get expression => _expression;
  String get displayExpression => _expression.split('+').join(' + ');
  double? get lastResult => _lastResult;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  bool get canEvaluate => _expression.isNotEmpty && !_expression.endsWith('+');
  bool get isContinuing => _isContinuing;
  List<StagedTimingCalculationHistory> get stagedHistories =>
      List.unmodifiable(_stagedHistories);
  StagedTimingCalculationHistory? get latestHistory =>
      _stagedHistories.isEmpty ? null : _stagedHistories.last;

  void pressDigit(String digit) {
    if (_hasEvaluatedOnce || _shouldRestartForFirstValueInput()) {
      _resetExpressionForFreshInput();
    }

    final result = _service.appendDigit(_expression, digit);
    _applyInputResult(result, markStarted: true);
  }

  void pressDecimalPoint() {
    if (_hasEvaluatedOnce || _shouldRestartForFirstValueInput()) {
      _resetExpressionForFreshInput();
    }

    final result = _service.appendDecimalPoint(_expression);
    _applyInputResult(result, markStarted: true);
  }

  void pressPlus() {
    final continueFromInitialHours =
        !_hasUserStartedInput &&
        _expression.isNotEmpty &&
        (_initialHours ?? 0) > 0;

    if (_hasEvaluatedOnce && _lastResult != null) {
      _expression = _formatHours(_lastResult!);
      _isContinuing = true;
      _hasUserStartedInput = true;
      _hasEvaluatedOnce = false;
    }

    final result = _service.appendPlus(_expression);
    _applyInputResult(result, markStarted: true);
    if (result.accepted && continueFromInitialHours) {
      _isContinuing = true;
    }
  }

  void pressBackspace() {
    final result = _service.backspace(_expression);
    _expression = result.expression;
    _errorMessage = result.errorMessage;
    _hasEvaluatedOnce = false;
    if (!_hasUserStartedInput) {
      _hasUserStartedInput = true;
    }
    if (_expression.isEmpty) {
      _isContinuing = false;
      _hasUserStartedInput = false;
    }
    notifyListeners();
  }

  void pressClear() {
    _expression = _service.clear();
    _lastResult = null;
    _errorMessage = null;
    _hasUserStartedInput = false;
    _isContinuing = false;
    _hasEvaluatedOnce = false;
    notifyListeners();
  }

  void pressEqual() {
    final result = _service.evaluate(
      expression: _expression,
      excludeFirstNumberFromTicketCount: _isContinuing,
    );

    if (result.success) {
      _lastResult = result.result;
      _errorMessage = null;
      _stagedHistories.add(
        StagedTimingCalculationHistory(
          createdAt: _now(),
          expression: _expression,
          result: result.result!,
          ticketCount: result.ticketCount,
        ),
      );
      _hasEvaluatedOnce = true;
    } else {
      _errorMessage = result.errorMessage;
    }

    notifyListeners();
  }

  bool _shouldRestartForFirstValueInput() {
    return !_hasUserStartedInput &&
        _expression.isNotEmpty &&
        (_initialHours ?? 0) > 0;
  }

  void _resetExpressionForFreshInput() {
    _expression = '';
    _errorMessage = null;
    _hasUserStartedInput = false;
    _isContinuing = false;
    _hasEvaluatedOnce = false;
  }

  void _applyInputResult(
    CalculatorInputResult result, {
    required bool markStarted,
  }) {
    _expression = result.expression;
    _errorMessage = result.errorMessage;
    if (result.accepted && markStarted) {
      _hasUserStartedInput = true;
      _hasEvaluatedOnce = false;
    }
    notifyListeners();
  }

  String _formatHours(double value) => value.toStringAsFixed(1);
}
