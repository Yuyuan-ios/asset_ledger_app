import 'package:asset_ledger/data/services/subscription_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    SubscriptionService.setPlanForDebug(Plan.free);
  });

  group('SubscriptionService', () {
    test('setPlanForDebug updates the synchronous cache and capability flags', () {
      SubscriptionService.setPlanForDebug(Plan.pro);

      expect(SubscriptionService.proCached, isTrue);
      expect(SubscriptionService.isPro, isTrue);
      expect(SubscriptionService.canUseCustomAvatar, isTrue);

      SubscriptionService.setPlanForDebug(Plan.free);

      expect(SubscriptionService.proCached, isFalse);
      expect(SubscriptionService.isPro, isFalse);
      expect(SubscriptionService.canUseCustomAvatar, isFalse);
    });

    test('refresh and async getters reflect the current debug plan', () async {
      SubscriptionService.setPlanForDebug(Plan.pro);
      await SubscriptionService.refresh();

      expect(await SubscriptionService.isProAsync(), isTrue);
      expect(await SubscriptionService.canUseCustomAvatarAsync(), isTrue);

      SubscriptionService.setPlanForDebug(Plan.free);
      await SubscriptionService.init();

      expect(await SubscriptionService.isProAsync(), isFalse);
      expect(await SubscriptionService.canUseCustomAvatarAsync(), isFalse);
    });
  });
}
