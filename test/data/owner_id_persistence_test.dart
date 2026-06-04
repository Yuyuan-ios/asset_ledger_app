import 'package:asset_ledger/app/identity/app_identity_service.dart';
import 'package:asset_ledger/app/identity/owner_id_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppIdentityService ownerId persistence', () {
    test(
      'first initialize generates and persists ownerId; subsequent restarts '
      'read back the same value',
      () async {
        final store = InMemoryOwnerIdStore();
        await AppIdentityService.resetForTest(
          store: store,
          generator: _sequenceGenerator(),
        );
        final firstId = AppIdentityService.instance
            .currentActorContext()
            .actorId;
        expect(firstId, 'gen-1');
        expect(await store.read(), 'gen-1');

        // 模拟"应用重启 / service 重新构造"：用同一个 store + 全新的
        // generator（generator 应被忽略，因为 store 里已经有 ownerId）。
        var generatorCalled = 0;
        await AppIdentityService.resetForTest(
          store: store,
          generator: () {
            generatorCalled += 1;
            return 'generator-must-not-run-$generatorCalled';
          },
        );
        final secondId = AppIdentityService.instance
            .currentActorContext()
            .actorId;
        expect(
          secondId,
          firstId,
          reason: 'second initialize must read the same ownerId from store',
        );
        expect(
          generatorCalled,
          0,
          reason: 'generator must not run when store already has ownerId',
        );
      },
    );

    test(
      'currentActorContext returns the persisted ownerId across repeated reads '
      'within the same session',
      () async {
        final store = InMemoryOwnerIdStore();
        await AppIdentityService.resetForTest(
          store: store,
          generator: _sequenceGenerator(),
        );
        final ctx1 = AppIdentityService.instance.currentActorContext();
        final ctx2 = AppIdentityService.instance.currentActorContext();
        expect(ctx1.actorId, ctx2.actorId);
        expect(ctx1.actorId, 'gen-1');
      },
    );

    test('clearing the store causes the next initialize to generate a new id', () async {
      final store = InMemoryOwnerIdStore();
      await AppIdentityService.resetForTest(
        store: store,
        generator: _sequenceGenerator(prefix: 'first-'),
      );
      final firstId = AppIdentityService.instance
          .currentActorContext()
          .actorId;
      expect(firstId, 'first-1');

      await store.clear();
      await AppIdentityService.resetForTest(
        store: store,
        generator: _sequenceGenerator(prefix: 'second-'),
      );
      final regeneratedId = AppIdentityService.instance
          .currentActorContext()
          .actorId;
      expect(
        regeneratedId,
        'second-1',
        reason: 'cleared store must trigger a fresh generator call',
      );
      expect(
        regeneratedId,
        isNot(firstId),
        reason: 'regenerated ownerId must differ from the cleared one',
      );
    });

    test(
      'initialize is idempotent: a second call with the same store does not '
      'overwrite the persisted id',
      () async {
        final store = InMemoryOwnerIdStore();
        await AppIdentityService.resetForTest(
          store: store,
          generator: _sequenceGenerator(prefix: 'first-'),
        );
        final firstId = AppIdentityService.instance
            .currentActorContext()
            .actorId;
        expect(firstId, 'first-1');

        // 不 reset 单例，直接再调一次 initialize：store 已有持久值，应直接复用，
        // 不应让新 generator 产出新 id。
        var generatorCalled = 0;
        await AppIdentityService.initialize(
          store: store,
          generator: () {
            generatorCalled += 1;
            return 'second-$generatorCalled';
          },
        );
        final secondId = AppIdentityService.instance
            .currentActorContext()
            .actorId;
        expect(secondId, firstId);
        expect(generatorCalled, 0);
      },
    );
  });
}

/// 测试用确定性 generator：每次返回 `<prefix><counter>`，便于断言。
String Function() _sequenceGenerator({String prefix = 'gen-'}) {
  var counter = 0;
  return () {
    counter += 1;
    return '$prefix$counter';
  };
}
