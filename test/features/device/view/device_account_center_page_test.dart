import 'package:asset_ledger/app/phone_login_store.dart';
import 'package:asset_ledger/core/measure/measure_unit.dart';
import 'package:asset_ledger/data/services/subscription_service.dart';
import 'package:asset_ledger/data/services/subscription_verification_repository.dart';
import 'package:asset_ledger/features/device/domain/entities/device.dart';
import 'package:asset_ledger/features/device/domain/services/device_business_ledger.dart';
import 'package:asset_ledger/features/device/view/device_account_center_page.dart';
import 'package:asset_ledger/features/device/view/device_page_sections.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

void main() {
  testWidgets('device page account card shows unauthenticated status', (
    WidgetTester tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));

    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: ListView(
            children: buildDevicePageSections(
              l10n: l10n,
              devices: <Device>[],
              handlers: DevicePageSectionHandlers(
                onOpenUpgradePage: () {},
                onOpenAccountCenter: () {},
                accountCenterSubtitle:
                    l10n.deviceAccountCenterLoggedOutSubtitle,
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

  testWidgets('device page sections show business ledger summaries', (
    WidgetTester tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));

    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: ListView(
            children: buildDevicePageSections(
              l10n: l10n,
              devices: <Device>[
                Device(
                  id: 1,
                  name: 'SANY 1#',
                  brand: 'SANY',
                  defaultUnitPrice: 100,
                  baseMeterHours: 0,
                ),
              ],
              handlers: DevicePageSectionHandlers(
                onOpenUpgradePage: () {},
                onOpenAccountCenter: () {},
                accountCenterSubtitle:
                    l10n.deviceAccountCenterLoggedOutSubtitle,
                onOpenAddDeviceFlow: () {},
                onOpenRateApp: () {},
                onOpenTermsPage: () {},
                onOpenPrivacyPage: () {},
                onOpenContact: () {},
                onDeviceTap: (_) {},
                onDeviceLongPress: (_) {},
                businessLedgers: const [
                  DeviceBusinessLedger(
                    deviceId: 1,
                    deviceName: 'SANY 1#',
                    incomeFen: 155000,
                    unitTotals: [
                      DeviceBusinessUnitTotal(
                        unit: MeasureUnit.hour,
                        quantityScaled: 2500,
                      ),
                      DeviceBusinessUnitTotal(
                        unit: MeasureUnit.trip,
                        quantityScaled: 3000,
                      ),
                    ],
                    projects: [
                      DeviceBusinessProjectHistory(
                        projectId: 'p1',
                        projectName: '李洋 · 万达',
                        minYmd: 20260103,
                        receivableFen: 55000,
                        receivedFen: 10000,
                        writeOffFen: 0,
                        remainingFen: 45000,
                        paymentStatus: DeviceBusinessPaymentStatus.partial,
                        unitTotals: [
                          DeviceBusinessUnitTotal(
                            unit: MeasureUnit.hour,
                            quantityScaled: 2500,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('设备经营'), findsOneWidget);
    expect(find.text('SANY 1#'), findsOneWidget);
    expect(find.textContaining('收入 ¥1550'), findsOneWidget);
    expect(find.textContaining('2.5小时、3趟'), findsOneWidget);
    expect(find.textContaining('1 项 · 待收 ¥450'), findsOneWidget);
  });

  testWidgets('device business ledger marks inactive device title', (
    WidgetTester tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));

    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: ListView(
            children: buildDevicePageSections(
              l10n: l10n,
              devices: <Device>[],
              handlers: DevicePageSectionHandlers(
                onOpenUpgradePage: () {},
                onOpenAccountCenter: () {},
                accountCenterSubtitle:
                    l10n.deviceAccountCenterLoggedOutSubtitle,
                onOpenAddDeviceFlow: () {},
                onOpenRateApp: () {},
                onOpenTermsPage: () {},
                onOpenPrivacyPage: () {},
                onOpenContact: () {},
                onDeviceTap: (_) {},
                onDeviceLongPress: (_) {},
                businessLedgers: const [
                  DeviceBusinessLedger(
                    deviceId: 1,
                    deviceName: 'SANY 1#',
                    deviceIsActive: false,
                    incomeFen: 155000,
                    unitTotals: [
                      DeviceBusinessUnitTotal(
                        unit: MeasureUnit.hour,
                        quantityScaled: 2500,
                      ),
                    ],
                    projects: [],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('SANY 已停用'), findsOneWidget);
    expect(find.text('SANY 1#'), findsNothing);
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
        _localizedApp(
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
            onOpenCloudBackup: () {},
          ),
        ),
      );

      expect(find.text('账号状态'), findsOneWidget);
      expect(find.text('未登录'), findsOneWidget);
      expect(find.text('手机号登录'), findsOneWidget);
      expect(find.text('购买权益'), findsOneWidget);
      expect(find.text('升级 Pro，支持持续维护'), findsOneWidget);
      expect(find.text('恢复购买'), findsOneWidget);
      expect(find.text('云端备份'), findsOneWidget);
      expect(find.text('登录后可保存与恢复云端备份'), findsOneWidget);
      expect(find.text('手动本地备份'), findsOneWidget);
      expect(find.text('本地恢复'), findsOneWidget);
      expect(find.text('多端同步说明'), findsOneWidget);

      await tester.tap(find.text('手机号登录'));
      await tester.pump();

      expect(loginOpened, isTrue);
      expect(find.text('已登录'), findsOneWidget);
    },
  );

  testWidgets('account center keeps login entry for skipped session', (
    WidgetTester tester,
  ) async {
    final subscription = ValueNotifier<SubscriptionSnapshot>(
      const SubscriptionSnapshot(
        status: SubscriptionStatus.free,
        products: <SubscriptionProductKind, ProductDetails>{},
      ),
    );
    addTearDown(subscription.dispose);

    var loginOpened = false;

    await tester.pumpWidget(
      _localizedApp(
        home: AccountCenterPage(
          loginSession: const PhoneLoginSession.skipped(),
          subscriptionListenable: subscription,
          onOpenPhoneLogin: () async {
            loginOpened = true;
            return const PhoneLoginSession.skipped();
          },
          onOpenUpgradePage: () {},
          onRestorePurchases: () async {},
          onOpenLocalBackup: () {},
          onOpenLocalRestore: () {},
          onOpenSyncInfo: () {},
          onOpenCloudBackup: () {},
        ),
      ),
    );

    expect(find.text('未登录'), findsOneWidget);
    expect(find.text('手机号登录'), findsOneWidget);

    await tester.tap(find.text('手机号登录'));
    await tester.pump();

    expect(loginOpened, isTrue);
  });

  testWidgets('account center masks authenticated phone number', (
    WidgetTester tester,
  ) async {
    final subscription = ValueNotifier<SubscriptionSnapshot>(
      SubscriptionSnapshot(
        status: SubscriptionStatus.activePro,
        products: const <SubscriptionProductKind, ProductDetails>{},
        entitlementTier: SubscriptionEntitlementTier.pro,
        isEntitlementVerified: true,
        expiryDate: DateTime(2027),
      ),
    );
    addTearDown(subscription.dispose);

    await tester.pumpWidget(
      _localizedApp(
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
          onOpenCloudBackup: () {},
        ),
      ),
    );

    expect(find.text('已登录'), findsOneWidget);
    expect(find.textContaining('尾号 8000'), findsOneWidget);
    expect(find.textContaining('Pro 已开通'), findsWidgets);
    expect(find.textContaining('13800138000'), findsNothing);
  });

  testWidgets('account center shows cloud backup unavailable state', (
    WidgetTester tester,
  ) async {
    final subscription = ValueNotifier<SubscriptionSnapshot>(
      const SubscriptionSnapshot(
        status: SubscriptionStatus.free,
        products: <SubscriptionProductKind, ProductDetails>{},
      ),
    );
    addTearDown(subscription.dispose);

    var cloudBackupOpened = false;

    await tester.pumpWidget(
      _localizedApp(
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
          onOpenCloudBackup: () {
            cloudBackupOpened = true;
          },
          cloudBackupAvailable: false,
          cloudBackupUnavailableMessage: '云端备份服务暂未配置',
        ),
      ),
    );

    expect(find.text('云端备份'), findsOneWidget);
    expect(find.text('云端备份服务暂未配置'), findsOneWidget);

    await tester.tap(find.text('云端备份'));
    await tester.pump();

    expect(cloudBackupOpened, isTrue);
  });

  testWidgets('account center hides conflict review when sync is unavailable', (
    WidgetTester tester,
  ) async {
    final subscription = ValueNotifier<SubscriptionSnapshot>(
      const SubscriptionSnapshot(
        status: SubscriptionStatus.free,
        products: <SubscriptionProductKind, ProductDetails>{},
      ),
    );
    addTearDown(subscription.dispose);
    var conflictReviewOpened = false;

    await tester.pumpWidget(
      _localizedApp(
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
          onOpenCloudBackup: () {},
          onOpenSyncConflictReview: () {
            conflictReviewOpened = true;
          },
        ),
      ),
    );

    expect(find.text('同步冲突复核'), findsNothing);
    expect(conflictReviewOpened, isFalse);
  });

  testWidgets('account center opens conflict review when sync is available', (
    WidgetTester tester,
  ) async {
    final subscription = ValueNotifier<SubscriptionSnapshot>(
      const SubscriptionSnapshot(
        status: SubscriptionStatus.free,
        products: <SubscriptionProductKind, ProductDetails>{},
      ),
    );
    addTearDown(subscription.dispose);
    var conflictReviewOpened = false;

    await tester.pumpWidget(
      _localizedApp(
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
          onOpenCloudBackup: () {},
          onOpenSyncConflictReview: () {
            conflictReviewOpened = true;
          },
          syncConflictReviewAvailable: true,
        ),
      ),
    );

    expect(find.text('同步冲突复核'), findsOneWidget);

    await tester.ensureVisible(find.text('同步冲突复核'));
    await tester.pump();
    await tester.tap(find.text('同步冲突复核'));
    await tester.pump();

    expect(conflictReviewOpened, isTrue);
  });
}

Widget _localizedApp({required Widget home}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}
