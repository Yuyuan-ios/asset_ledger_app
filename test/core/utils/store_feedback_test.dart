import 'package:asset_ledger/core/errors/store_failure.dart';
import 'package:asset_ledger/core/utils/base_store.dart';
import 'package:asset_ledger/core/utils/store_feedback.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  group('storeFeedback', () {
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
      expect(feedback.failureDetail, isNotNull);
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

    test('firstStoreActionFailure returns the first failing store as a code',
        () async {
      final idleStore = _HarnessStore();
      final failingStore = _HarnessStore();
      await expectLater(
        failingStore.runAction(() => throw _FakeDatabaseException('write failed')),
        throwsA(isA<DatabaseException>()),
      );

      final feedback = firstStoreActionFailure(
        [idleStore, failingStore],
        action: StoreActionKind.read,
      );
      expect(feedback, isNotNull);
      expect(feedback!.isSuccess, isFalse);
      expect(feedback.action, StoreActionKind.read);
      expect(feedback.failureType, StoreFailureType.database);

      expect(
        firstStoreActionFailure([idleStore], action: StoreActionKind.read),
        isNull,
      );
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
