import 'dart:io';

import 'package:asset_ledger/core/utils/base_store.dart';
import 'package:asset_ledger/core/utils/store_feedback.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  group('storeFeedback', () {
    test('formats validation and database failures for the UI', () async {
      final validationStore = _HarnessStore();
      await expectLater(
        validationStore.runAction(() => throw ArgumentError('brand 不能为空')),
        throwsArgumentError,
      );
      expect(storeErrorMessage(validationStore, action: '保存'), '保存失败：brand 不能为空');

      final databaseStore = _HarnessStore();
      await expectLater(
        databaseStore.runAction(() => throw _FakeDatabaseException('write failed')),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        storeErrorMessage(databaseStore, action: '删除'),
        '删除失败：数据未保存，请稍后重试',
      );
      final deleteFeedback = storeActionFeedback(
        databaseStore,
        action: '删除',
      );
      expect(deleteFeedback.isSuccess, isFalse);
      expect(deleteFeedback.message, '删除失败：数据未保存，请稍后重试');
    });

    test('formats file-system failures and picks the first active error', () async {
      final fileStore = _HarnessStore();
      await expectLater(
        fileStore.runAction(
          () => throw FileSystemException('copy failed', '/tmp/avatar.png'),
        ),
        throwsA(isA<FileSystemException>()),
      );

      final idleStore = _HarnessStore();
      expect(
        firstStoreErrorMessage([idleStore, fileStore], action: '读取'),
        '读取失败：请检查文件状态和访问权限',
      );
    });

    test('returns centralized success copy for completed actions', () {
      final store = _HarnessStore();

      final saveFeedback = storeActionFeedback(store, action: '保存');
      expect(saveFeedback.isSuccess, isTrue);
      expect(saveFeedback.message, '已保存');

      final customFeedback = storeActionFeedback(
        store,
        action: '保存',
        successMessage: '已新增设备',
      );
      expect(customFeedback.isSuccess, isTrue);
      expect(customFeedback.message, '已新增设备');
    });
  });
}

class _HarnessStore extends BaseStore {
  Future<void> runAction(Future<void> Function() action) async {
    await run(action);
  }
}

class _FakeDatabaseException implements DatabaseException {
  _FakeDatabaseException(this.message);

  final String message;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  String toString() => message;
}
