import 'package:asset_ledger/core/utils/text_field_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects zero-like numeric text', () {
    expect(isZeroLikeNumericText('0'), isTrue);
    expect(isZeroLikeNumericText('0.0'), isTrue);
    expect(isZeroLikeNumericText('00.00'), isTrue);
    expect(isZeroLikeNumericText(' 0 '), isTrue);
    expect(isZeroLikeNumericText(''), isFalse);
    expect(isZeroLikeNumericText('5817.1'), isFalse);
    expect(isZeroLikeNumericText('0.1'), isFalse);
  });

  test('selects all only when the controller contains a zero-like value', () {
    final zeroController = TextEditingController(text: '0.0');
    addTearDown(zeroController.dispose);

    selectAllIfZeroLike(zeroController);
    expect(zeroController.selection.baseOffset, 0);
    expect(zeroController.selection.extentOffset, zeroController.text.length);

    final valueController = TextEditingController(text: '5817.1');
    addTearDown(valueController.dispose);

    selectAllIfZeroLike(valueController);
    expect(valueController.selection.isValid, isFalse);
  });
}
