import 'package:asset_ledger/core/utils/interaction_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('interactionFeedback', () {
    test('formats missing entity messages with optional id and suffix', () {
      expect(
        missingEntityMessage('设备', id: 3, suffix: '请先去设备页检查'),
        '设备不存在（id=3），请先去设备页检查',
      );
      expect(missingEntityMessage('设备'), '设备不存在');
    });

    test('formats inactive creation and filter status messages', () {
      expect(
        inactiveEntityCreateMessage('该设备', recordLabel: '燃油记录'),
        '该设备已停用，不能用于新建燃油记录',
      );
      expect(filterStatusMessage(cleared: true, hasActiveFilter: false), '已清空筛选');
      expect(filterStatusMessage(cleared: false, hasActiveFilter: true), '已筛选');
      expect(filterStatusMessage(cleared: false, hasActiveFilter: false), '未筛选');
    });
  });
}
