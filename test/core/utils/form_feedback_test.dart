import 'package:asset_ledger/core/utils/form_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formValidationMessage', () {
    test('adds a save-failed prefix when the message is raw', () {
      expect(formValidationMessage('金额必须大于 0'), '保存失败：金额必须大于 0');
    });

    test('keeps existing failed prefixes intact', () {
      expect(
        formValidationMessage('保存失败：日期格式不正确'),
        '保存失败：日期格式不正确',
      );
    });

    test('falls back to a generic message for blank input', () {
      expect(formValidationMessage('   '), '保存失败：请检查输入内容');
    });
  });
}
