import 'package:asset_ledger/app/phone_login_store.dart';
import 'package:asset_ledger/data/services/subscription_service.dart';
import 'package:asset_ledger/features/device/domain/entities/device.dart';
import 'package:asset_ledger/features/device/view/device_account_center_page.dart';
import 'package:asset_ledger/features/device/view/device_page_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

void main() {
  testWidgets('device page account card shows unauthenticated status', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: buildDevicePageSections(
              devices: const <Device>[],
              handlers: DevicePageSectionHandlers(
                onOpenUpgradePage: () {},
                onOpenAccountCenter: () {},
                accountCenterSubtitle: '未登录 · 登录后可备份与同步',
                onOpenAddDeviceFlow: () {},
                onOpenRateApp: () {},
                onOpenTermsPage: () {},
                onOpenPrivacyPage: () {},
                onOpenContact: () {},
                onDeviceTap: (_) {},
                onDeviceLongPress: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('账号与同步'), findsOneWidget);
    expect(find.text('账户中心'), findsOneWidget);
    expect(find.text('未登录 · 登录后可备份与同步'), findsOneWidget);
  });

  testWidgets(
    'account center shows login and purchase entries when logged out',
    (WidgetTester tester) async {
      final subscription = ValueNotifier<SubscriptionSnapshot>(
        const SubscriptionSnapshot(
          status: SubscriptionStatus.free,
          products: <SubscriptionProductKind, ProductDetails>{},
        ),
      );
      addTearDown(subscription.dispose);

      var loginOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AccountCenterPage(
            loginSession: const PhoneLoginSession.unauthenticated(),
            subscriptionListenable: subscription,
            onOpenPhoneLogin: () async {
              loginOpened = true;
              return const PhoneLoginSession(
                loggedIn: true,
                privacyAccepted: true,
                phoneNumber: '13800138000',
                authToken: 'token',
              );
            },
            onOpenUpgradePage: () {},
            onRestorePurchases: () async {},
            onOpenLocalBackup: () {},
            onOpenLocalRestore: () {},
            onOpenSyncInfo: () {},
            onOpenLoginSyncInfo: () {},
          ),
        ),
      );

      expect(find.text('账号状态'), findsOneWidget);
      expect(find.text('未登录'), findsOneWidget);
      expect(find.text('手机号登录'), findsOneWidget);
      expect(find.text('购买权益'), findsOneWidget);
      expect(find.text('升级 Pro，支持持续维护'), findsOneWidget);
      expect(find.text('恢复购买'), findsOneWidget);
      expect(find.text('云端备份与协作记录'), findsOneWidget);
      expect(find.text('手动本地备份'), findsOneWidget);
      expect(find.text('本地恢复'), findsOneWidget);
      expect(find.text('多端同步说明'), findsOneWidget);

      await tester.tap(find.text('手机号登录'));
      await tester.pump();

      expect(loginOpened, isTrue);
      expect(find.text('已登录'), findsOneWidget);
    },
  );

  testWidgets('account center masks authenticated phone number', (
    WidgetTester tester,
  ) async {
    final subscription = ValueNotifier<SubscriptionSnapshot>(
      SubscriptionSnapshot(
        status: SubscriptionStatus.activeYearly,
        products: const <SubscriptionProductKind, ProductDetails>{},
        isEntitlementVerified: true,
        expiryDate: DateTime(2027),
      ),
    );
    addTearDown(subscription.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AccountCenterPage(
          loginSession: const PhoneLoginSession(
            loggedIn: true,
            privacyAccepted: true,
            phoneNumber: '13800138000',
            authToken: 'token',
          ),
          subscriptionListenable: subscription,
          onOpenPhoneLogin: () async =>
              const PhoneLoginSession.unauthenticated(),
          onOpenUpgradePage: () {},
          onRestorePurchases: () async {},
          onOpenLocalBackup: () {},
          onOpenLocalRestore: () {},
          onOpenSyncInfo: () {},
          onOpenLoginSyncInfo: () {},
        ),
      ),
    );

    expect(find.text('已登录'), findsOneWidget);
    expect(find.textContaining('尾号 8000'), findsOneWidget);
    expect(find.textContaining('Pro 已开通'), findsWidgets);
    expect(find.textContaining('13800138000'), findsNothing);
  });
}
