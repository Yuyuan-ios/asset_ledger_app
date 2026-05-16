import 'package:asset_ledger/features/timing/calculator/service/work_hour_calculator_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late WorkHourCalculatorService service;

  setUp(() {
    service = WorkHourCalculatorService();
  });

  group('WorkHourCalculatorService.evaluate', () {
    test('calculates normal addition expressions and ticket counts', () {
      final cases = [
        (expression: '8+8', result: 16.0, ticketCount: 2),
        (expression: '8+8.2', result: 16.2, ticketCount: 2),
        (expression: '8.2+8.3+8.1', result: 24.6, ticketCount: 3),
        (expression: '8+8.2+8.3+8.1', result: 32.6, ticketCount: 4),
      ];

      for (final item in cases) {
        final result = service.evaluate(expression: item.expression);

        expect(result.success, isTrue);
        expect(result.expression, item.expression);
        expect(result.result, item.result);
        expect(result.ticketCount, item.ticketCount);
        expect(result.errorMessage, isNull);
      }
    });

    test('can exclude the first number from ticket count', () {
      final excluded = service.evaluate(
        expression: '32.6+7.4+5+3+8.4',
        excludeFirstNumberFromTicketCount: true,
      );
      final included = service.evaluate(
        expression: '32.6+7.4+5+3+8.4',
        excludeFirstNumberFromTicketCount: false,
      );

      expect(excluded.success, isTrue);
      expect(excluded.result, 56.4);
      expect(excluded.ticketCount, 4);

      expect(included.success, isTrue);
      expect(included.result, 56.4);
      expect(included.ticketCount, 5);
    });

    test('rejects empty, incomplete, and illegal expressions', () {
      final empty = service.evaluate(expression: '');
      final trailingPlus = service.evaluate(expression: '8+');
      final illegal = service.evaluate(expression: '8+a');

      expect(empty.success, isFalse);
      expect(empty.result, isNull);
      expect(empty.ticketCount, 0);
      expect(empty.errorMessage, isNotNull);

      expect(trailingPlus.success, isFalse);
      expect(trailingPlus.result, isNull);
      expect(trailingPlus.ticketCount, 0);
      expect(trailingPlus.errorMessage, isNotNull);

      expect(illegal.success, isFalse);
      expect(illegal.result, isNull);
      expect(illegal.ticketCount, 0);
      expect(illegal.errorMessage, isNotNull);
    });
  });

  group('WorkHourCalculatorService input guards', () {
    test('rejects more than one decimal digit while appending digits', () {
      final result = service.appendDigit('8.2', '3');

      expect(result.accepted, isFalse);
      expect(result.expression, '8.2');
      expect(result.errorMessage, '每个数字最多 1 位小数');
    });

    test('rejects a second decimal point in the current number', () {
      final result = service.appendDecimalPoint('8.2');

      expect(result.accepted, isFalse);
      expect(result.expression, '8.2');
      expect(result.errorMessage, '每个数字最多 1 位小数');
    });

    test('rejects leading and duplicate plus signs', () {
      final leading = service.appendPlus('');
      final duplicate = service.appendPlus('8+');

      expect(leading.accepted, isFalse);
      expect(leading.expression, '');
      expect(leading.errorMessage, isNotNull);

      expect(duplicate.accepted, isFalse);
      expect(duplicate.expression, '8+');
      expect(duplicate.errorMessage, isNotNull);
    });
  });

  group('WorkHourCalculatorService editing helpers', () {
    test('backspaces one character at a time', () {
      expect(service.backspace('8.2').expression, '8.');
      expect(service.backspace('8.').expression, '8');
      expect(service.backspace('8').expression, '');
    });

    test('clears the expression', () {
      expect(service.clear(), '');
    });
  });
}
