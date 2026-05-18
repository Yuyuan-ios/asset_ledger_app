import 'package:asset_ledger/core/errors/domain_failure.dart';
import 'package:asset_ledger/core/errors/error_message_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorMessageMapper', () {
    test('maps domain and argument errors to user-facing text', () {
      expect(
        ErrorMessageMapper.toUserMessage(
          const DomainFailure('invalid_date', '日期不合法'),
        ),
        '日期不合法',
      );
      expect(
        ErrorMessageMapper.toUserMessage(
          ArgumentError.value(-1, 'amount', '金额不能为负数'),
        ),
        '金额不能为负数',
      );
      expect(ErrorMessageMapper.toUserMessage(Exception('x')), '操作失败，请稍后重试。');
    });
  });
}
