class WorkHourCalculatorService {
  static const String _decimalLimitMessage = '每个数字最多 1 位小数';

  CalculatorInputResult appendDigit(String expression, String digit) {
    if (!RegExp(r'^[0-9]$').hasMatch(digit)) {
      return CalculatorInputResult.rejected(expression, errorMessage: '只能输入数字');
    }

    final currentNumber = _currentNumber(expression);
    final dotIndex = currentNumber.indexOf('.');
    if (dotIndex != -1 && currentNumber.length - dotIndex - 1 >= 1) {
      return CalculatorInputResult.rejected(
        expression,
        errorMessage: _decimalLimitMessage,
      );
    }

    return CalculatorInputResult.accepted(expression + digit);
  }

  CalculatorInputResult appendDecimalPoint(String expression) {
    final currentNumber = _currentNumber(expression);
    if (currentNumber.contains('.')) {
      return CalculatorInputResult.rejected(
        expression,
        errorMessage: _decimalLimitMessage,
      );
    }

    if (expression.isEmpty || expression.endsWith('+')) {
      return CalculatorInputResult.accepted('${expression}0.');
    }

    return CalculatorInputResult.accepted('$expression.');
  }

  CalculatorInputResult appendPlus(String expression) {
    if (expression.isEmpty) {
      return CalculatorInputResult.rejected(expression, errorMessage: '请先输入工时');
    }
    if (expression.endsWith('+')) {
      return CalculatorInputResult.rejected(
        expression,
        errorMessage: '不能连续输入加号',
      );
    }

    return CalculatorInputResult.accepted('$expression+');
  }

  CalculatorInputResult backspace(String expression) {
    if (expression.isEmpty) {
      return CalculatorInputResult.accepted(expression);
    }
    return CalculatorInputResult.accepted(
      expression.substring(0, expression.length - 1),
    );
  }

  String clear() => '';

  CalculatorEvaluateResult evaluate({
    required String expression,
    bool excludeFirstNumberFromTicketCount = false,
  }) {
    if (expression.trim().isEmpty) {
      return CalculatorEvaluateResult.failure(
        expression: expression,
        errorMessage: '请输入工时计算式',
      );
    }

    if (!RegExp(r'^[0-9+.]+$').hasMatch(expression)) {
      return CalculatorEvaluateResult.failure(
        expression: expression,
        errorMessage: '表达式包含非法字符',
      );
    }

    if (expression.endsWith('+')) {
      return CalculatorEvaluateResult.failure(
        expression: expression,
        errorMessage: '表达式不能以加号结尾',
      );
    }

    final parts = expression.split('+');
    if (parts.any((part) => part.isEmpty)) {
      return CalculatorEvaluateResult.failure(
        expression: expression,
        errorMessage: '表达式格式不正确',
      );
    }

    final values = <double>[];
    for (final part in parts) {
      if (!RegExp(r'^\d+(\.\d)?$').hasMatch(part)) {
        return CalculatorEvaluateResult.failure(
          expression: expression,
          errorMessage: '每个数字最多 1 位小数',
        );
      }
      values.add(double.parse(part));
    }

    final result = _round1(
      values.fold<double>(0.0, (sum, value) => sum + value),
    );
    if (result < 0) {
      return CalculatorEvaluateResult.failure(
        expression: expression,
        errorMessage: '工时不能为负数',
      );
    }

    final ticketCount = excludeFirstNumberFromTicketCount
        ? (values.length - 1).clamp(0, values.length)
        : values.length;

    return CalculatorEvaluateResult.success(
      expression: expression,
      result: result,
      ticketCount: ticketCount,
    );
  }

  String _currentNumber(String expression) {
    final lastPlusIndex = expression.lastIndexOf('+');
    if (lastPlusIndex == -1) return expression;
    return expression.substring(lastPlusIndex + 1);
  }

  double _round1(double value) => (value * 10).round() / 10.0;
}

class CalculatorInputResult {
  const CalculatorInputResult({
    required this.expression,
    required this.accepted,
    this.errorMessage,
  });

  factory CalculatorInputResult.accepted(String expression) {
    return CalculatorInputResult(expression: expression, accepted: true);
  }

  factory CalculatorInputResult.rejected(
    String expression, {
    required String errorMessage,
  }) {
    return CalculatorInputResult(
      expression: expression,
      accepted: false,
      errorMessage: errorMessage,
    );
  }

  final String expression;
  final bool accepted;
  final String? errorMessage;
}

class CalculatorEvaluateResult {
  const CalculatorEvaluateResult({
    required this.success,
    required this.expression,
    required this.result,
    required this.ticketCount,
    required this.errorMessage,
  });

  factory CalculatorEvaluateResult.success({
    required String expression,
    required double result,
    required int ticketCount,
  }) {
    return CalculatorEvaluateResult(
      success: true,
      expression: expression,
      result: result,
      ticketCount: ticketCount,
      errorMessage: null,
    );
  }

  factory CalculatorEvaluateResult.failure({
    required String expression,
    required String errorMessage,
  }) {
    return CalculatorEvaluateResult(
      success: false,
      expression: expression,
      result: null,
      ticketCount: 0,
      errorMessage: errorMessage,
    );
  }

  final bool success;
  final String expression;
  final double? result;
  final int ticketCount;
  final String? errorMessage;
}
