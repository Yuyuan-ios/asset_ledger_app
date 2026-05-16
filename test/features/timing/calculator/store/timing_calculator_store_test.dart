import 'package:asset_ledger/features/timing/calculator/service/work_hour_calculator_service.dart';
import 'package:asset_ledger/features/timing/calculator/store/timing_calculator_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime fixedNow;

  setUp(() {
    fixedNow = DateTime(2026, 5, 14, 10, 30);
  });

  TimingCalculatorStore buildStore({double? initialHours}) {
    return TimingCalculatorStore(
      service: WorkHourCalculatorService(),
      initialHours: initialHours,
      now: () => fixedNow,
    );
  }

  void pressExpression(TimingCalculatorStore store, String expression) {
    for (final char in expression.split('')) {
      if (RegExp(r'^[0-9]$').hasMatch(char)) {
        store.pressDigit(char);
      } else if (char == '.') {
        store.pressDecimalPoint();
      } else if (char == '+') {
        store.pressPlus();
      } else {
        fail('Unsupported test input: $char');
      }
    }
  }

  group('TimingCalculatorStore continuing calculations', () {
    test('keeps initial hours as base when the first key is plus', () {
      final store = buildStore(initialHours: 32.6);

      store.pressPlus();
      pressExpression(store, '7.4+5+3+8.4');
      store.pressEqual();

      expect(store.lastResult, 56.4);
      expect(store.latestHistory?.ticketCount, 4);
      expect(store.stagedHistories, hasLength(1));
      expect(store.latestHistory?.createdAt, fixedNow);
      expect(store.isContinuing, isTrue);
    });

    test('continues from last result after equal then plus', () {
      final store = buildStore();

      pressExpression(store, '8+8');
      store.pressEqual();
      expect(store.lastResult, 16.0);

      store.pressPlus();
      store.pressDigit('4');
      store.pressEqual();

      expect(store.expression, '16.0+4');
      expect(store.lastResult, 20.0);
      expect(store.latestHistory?.ticketCount, 1);
      expect(store.stagedHistories, hasLength(2));
      expect(store.isContinuing, isTrue);
    });
  });

  group('TimingCalculatorStore restarting calculations', () {
    test('drops initial hours when the first key is a digit', () {
      final store = buildStore(initialHours: 32.6);

      store.pressDigit('8');
      pressExpression(store, '+8.2');
      store.pressEqual();

      expect(store.expression, '8+8.2');
      expect(store.expression.contains('32.6'), isFalse);
      expect(store.lastResult, 16.2);
      expect(store.latestHistory?.ticketCount, 2);
      expect(store.isContinuing, isFalse);
    });

    test('drops initial hours when the first key is a decimal point', () {
      final store = buildStore(initialHours: 32.6);

      store.pressDecimalPoint();
      pressExpression(store, '5+1');
      store.pressEqual();

      expect(store.expression, '0.5+1');
      expect(store.lastResult, 1.5);
      expect(store.latestHistory?.ticketCount, 2);
      expect(store.isContinuing, isFalse);
    });

    test('starts fresh after equal then digit', () {
      final store = buildStore();

      pressExpression(store, '8+8');
      store.pressEqual();
      expect(store.lastResult, 16.0);

      store.pressDigit('5');
      pressExpression(store, '+3');
      store.pressEqual();

      expect(store.expression, '5+3');
      expect(store.lastResult, 8.0);
      expect(store.latestHistory?.ticketCount, 2);
      expect(store.stagedHistories, hasLength(2));
      expect(store.isContinuing, isFalse);
    });
  });

  group('TimingCalculatorStore histories and errors', () {
    test('does not generate history when evaluate fails', () {
      final store = buildStore();

      pressExpression(store, '8+');
      store.pressEqual();

      expect(store.stagedHistories, isEmpty);
      expect(store.hasError, isTrue);
      expect(store.errorMessage, isNotNull);
    });

    test('adds a staged history for every successful equal press', () {
      final store = buildStore();

      pressExpression(store, '8+8');
      store.pressEqual();
      store.pressEqual();

      expect(store.lastResult, 16.0);
      expect(store.stagedHistories, hasLength(2));
      expect(store.latestHistory?.expression, '8+8');
    });

    test('clear resets expression but keeps staged histories', () {
      final store = buildStore();

      pressExpression(store, '8+8');
      store.pressEqual();
      store.pressClear();

      expect(store.expression, '');
      expect(store.displayExpression, '');
      expect(store.lastResult, isNull);
      expect(store.stagedHistories, hasLength(1));
      expect(store.hasError, isFalse);
    });
  });

  group('TimingCalculatorStore editing helpers', () {
    test('backspace deletes one character at a time', () {
      final store = buildStore();

      pressExpression(store, '8.2');

      store.pressBackspace();
      expect(store.expression, '8.');

      store.pressBackspace();
      expect(store.expression, '8');

      store.pressBackspace();
      expect(store.expression, '');
    });

    test('exposes display expression and canEvaluate state', () {
      final store = buildStore();

      pressExpression(store, '8+8.2');

      expect(store.displayExpression, '8 + 8.2');
      expect(store.canEvaluate, isTrue);

      store.pressPlus();
      expect(store.canEvaluate, isFalse);
    });
  });
}
