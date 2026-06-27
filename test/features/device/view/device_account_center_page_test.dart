import 'package:asset_ledger/app/phone_login_store.dart';
import 'package:asset_ledger/core/measure/measure_unit.dart';
import 'package:asset_ledger/data/services/subscription_service.dart';
import 'package:asset_ledger/data/services/subscription_verification_repository.dart';
import 'package:asset_ledger/features/device/domain/entities/device.dart';
import 'package:asset_ledger/features/device/domain/services/device_business_ledger.dart';
import 'package:asset_ledger/features/device/view/device_account_center_page.dart';
import 'package:asset_ledger/features/device/view/device_page_sections.dart';
import 'package:asset_ledger/features/device/view/device_subpage_app_bar.dart';
import 'package:asset_ledger/features/device/view/device_subpage_route.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/tokens/mapper/timing_tokens.dart';
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

  testWidgets('device page account status sits beside title before arrow', (
    WidgetTester tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final subtitle = l10n.deviceAccountCenterLoggedInTailSubtitle(
      '9190',
      l10n.deviceEntitlementFree,
    );

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
                accountCenterSubtitle: subtitle,
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

    final title = find.text('账户中心');
    final status = find.text('已登录 · 尾号 9190 · 免费版');
    final accountChevron = find.byIcon(Icons.chevron_right).first;

    expect(title, findsOneWidget);
    expect(status, findsOneWidget);
    expect(
      tester.getCenter(status).dx,
      greaterThan(tester.getCenter(title).dx),
    );
    expect(
      (tester.getCenter(status).dy - tester.getCenter(title).dy).abs(),
      lessThan(1),
    );
    expect(
      tester.getTopRight(status).dx,
      lessThan(tester.getTopLeft(accountChevron).dx),
    );
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
    expect(find.text('未设置初始投入'), findsOneWidget);
    expect(find.text('点击设置成本与残值'), findsOneWidget);
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
            onRestorePurchases: _noopRestorePurchases,
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
      expect(find.text('解除计时记录 30 条限制'), findsOneWidget);
      expect(find.text('6 元/年'), findsOneWidget);
      expect(find.text('升级 Max，开启云端备份'), findsOneWidget);
      expect(find.text('包含 Pro 权益，支持云端备份与恢复'), findsOneWidget);
      expect(find.text('24 元/年'), findsOneWidget);
      expect(find.text('恢复购买'), findsOneWidget);
      expect(find.text('云端备份'), findsOneWidget);
      expect(find.text('云端恢复'), findsOneWidget);
      expect(find.text('登录后可使用云端备份与恢复'), findsNWidgets(3));
      expect(find.text('导出当前数据'), findsOneWidget);
      expect(find.text('本地恢复'), findsOneWidget);
      expect(find.text('多端同步说明'), findsOneWidget);

      await tester.tap(find.text('手机号登录'));
      await tester.pump();

      expect(loginOpened, isTrue);
      expect(find.text('已登录'), findsOneWidget);
    },
  );

  testWidgets('account center app bar matches section header metrics', (
    WidgetTester tester,
  ) async {
    final subscription = ValueNotifier<SubscriptionSnapshot>(
      const SubscriptionSnapshot(
        status: SubscriptionStatus.free,
        products: <SubscriptionProductKind, ProductDetails>{},
      ),
    );
    addTearDown(subscription.dispose);

    await tester.pumpWidget(
      _localizedApp(
        home: AccountCenterPage(
          loginSession: const PhoneLoginSession.unauthenticated(),
          subscriptionListenable: subscription,
          onOpenPhoneLogin: () async =>
              const PhoneLoginSession.unauthenticated(),
          onOpenUpgradePage: () {},
          onRestorePurchases: _noopRestorePurchases,
          onOpenLocalBackup: () {},
          onOpenLocalRestore: () {},
          onOpenSyncInfo: () {},
          onOpenCloudBackup: () {},
        ),
      ),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final title = tester.widget<Text>(find.text('账户中心'));

    expect(appBar.toolbarHeight, DeviceSubpageAppBar.toolbarHeight);
    expect(appBar.centerTitle, isTrue);
    expect(title.style?.fontSize, TimingTokens.headerTitleSize);
    expect(title.style?.height, TimingTokens.headerTitleLineHeight);
    expect(title.style?.fontWeight, FontWeight.w700);
    expect(
      tester.getCenter(find.text('账户中心')).dx,
      moreOrLessEquals(tester.getCenter(find.byType(AppBar)).dx, epsilon: 1),
    );
  });

  testWidgets('account center supports right swipe back', (
    WidgetTester tester,
  ) async {
    final subscription = ValueNotifier<SubscriptionSnapshot>(
      const SubscriptionSnapshot(
        status: SubscriptionStatus.free,
        products: <SubscriptionProductKind, ProductDetails>{},
      ),
    );
    addTearDown(subscription.dispose);

    await tester.pumpWidget(
      _localizedApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  deviceSubpageRoute<void>(
                    builder: (_) => AccountCenterPage(
                      loginSession: const PhoneLoginSession.unauthenticated(),
                      subscriptionListenable: subscription,
                      onOpenPhoneLogin: () async =>
                          const PhoneLoginSession.unauthenticated(),
                      onOpenUpgradePage: () {},
                      onRestorePurchases: _noopRestorePurchases,
                      onOpenLocalBackup: () {},
                      onOpenLocalRestore: () {},
                      onOpenSyncInfo: () {},
                      onOpenCloudBackup: () {},
                    ),
                  ),
                );
              },
              child: const Text('打开账户中心'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开账户中心'));
    await tester.pumpAndSettle();
    expect(find.text('账户中心'), findsOneWidget);

    await tester.dragFrom(const Offset(5, 300), const Offset(340, 0));
    await tester.pumpAndSettle();

    expect(find.text('打开账户中心'), findsOneWidget);
    expect(find.text('账户中心'), findsNothing);
  });

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
          onRestorePurchases: _noopRestorePurchases,
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
          onRestorePurchases: _noopRestorePurchases,
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

  testWidgets(
    'account center shows restore pending instead of free entitlement',
    (WidgetTester tester) async {
      final subscription = ValueNotifier<SubscriptionSnapshot>(
        const SubscriptionSnapshot(
          status: SubscriptionStatus.pending,
          products: <SubscriptionProductKind, ProductDetails>{},
          isRestoring: true,
        ),
      );
      addTearDown(subscription.dispose);
      var restoreTapped = false;

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
            onRestorePurchases: () async {
              restoreTapped = true;
              return const SubscriptionRestoreOutcome.noActivePurchase();
            },
            onOpenLocalBackup: () {},
            onOpenLocalRestore: () {},
            onOpenSyncInfo: () {},
            onOpenCloudBackup: () {},
          ),
        ),
      );

      expect(find.textContaining('正在等待 App Store 交易结果'), findsWidgets);
      expect(find.textContaining('免费版'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('恢复购买'));
      await tester.pump();

      expect(restoreTapped, isFalse);
    },
  );

  for (final restoreCase in _restoreOutcomeCases) {
    testWidgets(
      'account center shows restore result snackbar for ${restoreCase.name}',
      (WidgetTester tester) async {
        final subscription = ValueNotifier<SubscriptionSnapshot>(
          const SubscriptionSnapshot(
            status: SubscriptionStatus.free,
            products: <SubscriptionProductKind, ProductDetails>{},
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
              onRestorePurchases: () async => restoreCase.outcome,
              onOpenLocalBackup: () {},
              onOpenLocalRestore: () {},
              onOpenSyncInfo: () {},
              onOpenCloudBackup: () {},
            ),
          ),
        );

        await tester.tap(find.text('恢复购买'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text(restoreCase.expectedZh), findsOneWidget);
      },
    );
  }

  testWidgets('account center marks cloud backup as Max-only for free users', (
    WidgetTester tester,
  ) async {
    final subscription = ValueNotifier<SubscriptionSnapshot>(
      const SubscriptionSnapshot(
        status: SubscriptionStatus.free,
        products: <SubscriptionProductKind, ProductDetails>{},
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
          onRestorePurchases: _noopRestorePurchases,
          onOpenLocalBackup: () {},
          onOpenLocalRestore: () {},
          onOpenSyncInfo: () {},
          onOpenCloudBackup: () {},
        ),
      ),
    );

    expect(find.text('云端备份'), findsOneWidget);
    expect(find.text('云端恢复'), findsOneWidget);
    expect(find.text('Max 功能，可上传当前数据并在需要时恢复'), findsOneWidget);
    expect(find.text('Max 功能，可从云端备份恢复数据'), findsOneWidget);
    expect(find.text('上传当前数据或从云端恢复'), findsNothing);
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
          onRestorePurchases: _noopRestorePurchases,
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
    expect(find.text('云端备份服务暂未配置'), findsNWidgets(2));

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
          onRestorePurchases: _noopRestorePurchases,
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
          onRestorePurchases: _noopRestorePurchases,
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

Future<SubscriptionRestoreOutcome> _noopRestorePurchases() async {
  return const SubscriptionRestoreOutcome.noActivePurchase();
}

class _RestoreOutcomeCase {
  const _RestoreOutcomeCase({
    required this.name,
    required this.outcome,
    required this.expectedZh,
  });

  final String name;
  final SubscriptionRestoreOutcome outcome;
  final String expectedZh;
}

const _restoreOutcomeCases = [
  _RestoreOutcomeCase(
    name: 'restored pro',
    outcome: SubscriptionRestoreOutcome.restoredPro(),
    expectedZh: '已恢复 Pro 订阅',
  ),
  _RestoreOutcomeCase(
    name: 'restored max',
    outcome: SubscriptionRestoreOutcome.restoredMax(),
    expectedZh: '已恢复 Max 订阅',
  ),
  _RestoreOutcomeCase(
    name: 'no active purchase',
    outcome: SubscriptionRestoreOutcome.noActivePurchase(),
    expectedZh: '未发现可恢复的购买',
  ),
  _RestoreOutcomeCase(
    name: 'failed',
    outcome: SubscriptionRestoreOutcome.failed('订阅服务端未返回有效授权'),
    expectedZh: '恢复失败：订阅服务端未返回有效授权',
  ),
  _RestoreOutcomeCase(
    name: 'unavailable',
    outcome: SubscriptionRestoreOutcome.unavailable('同步请求失败'),
    expectedZh: '订阅服务暂不可用：同步请求失败',
  ),
];
