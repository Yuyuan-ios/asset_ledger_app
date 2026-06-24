import 'dart:io';

import 'package:asset_ledger/core/errors/store_failure.dart';
import 'package:asset_ledger/core/utils/base_store.dart';
import 'package:asset_ledger/core/utils/store_feedback.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  group('storeFeedback', () {
    test('storeErrorMessage formats validation and database failures', () async {
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
    });

    test('firstStoreErrorMessage picks the first active error', () async {
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

    test('storeActionFeedback exposes failure as structured code (no display text)',
        () async {
      final databaseStore = _HarnessStore();
      await expectLater(
        databaseStore.runAction(() => throw _FakeDatabaseException('write failed')),
        throwsA(isA<DatabaseException>()),
      );

      final feedback = storeActionFeedback(
        databaseStore,
        action: StoreActionKind.delete,
      );
      expect(feedback.isSuccess, isFalse);
      expect(feedback.action, StoreActionKind.delete);
      expect(feedback.failureType, StoreFailureType.database);
      expect(feedback.successOverrideText, isNull);
    });

    test('storeActionFeedback exposes success as structured code', () {
      final store = _HarnessStore();

      final saveFeedback = storeActionFeedback(store, action: StoreActionKind.save);
      expect(saveFeedback.isSuccess, isTrue);
      expect(saveFeedback.action, StoreActionKind.save);
      expect(saveFeedback.failureType, isNull);
      expect(saveFeedback.successOverrideText, isNull);

      final custom = storeActionFeedback(
        store,
        action: StoreActionKind.create,
        successOverrideText: '已新增设备',
      );
      expect(custom.isSuccess, isTrue);
      expect(custom.successOverrideText, '已新增设备');
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
