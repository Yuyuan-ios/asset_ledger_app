import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/patterns/device/upgrade_subscription_disclosure_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders required subscription review details and legal links', (
    WidgetTester tester,
  ) async {
    var openedPrivacy = false;
    var openedTerms = false;

    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: UpgradeSubscriptionDisclosurePattern(
                subscriptionTitle: 'FleetLedger Pro Annual',
                subscriptionLength: '每年 / 1 year',
                subscriptionPrice: '¥6.00',
                unitPrice: '¥6.00 / 年',
                canPurchaseSelectedProduct: true,
                privacyPolicyUrl:
                    'https://yuyuan-ios.github.io/asset_ledger_app/privacy.html',
                termsOfServiceUrl:
                    'https://yuyuan-ios.github.io/asset_ledger_app/terms.html',
                onPrivacyTap: () => openedPrivacy = true,
                onTermsTap: () => openedTerms = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('订阅信息 / Subscription details'), findsOneWidget);
    expect(find.text('订阅名称'), findsOneWidget);
    expect(find.text('FleetLedger Pro Annual'), findsOneWidget);
    expect(find.text('订阅周期'), findsOneWidget);
    expect(find.text('每年 / 1 year'), findsOneWidget);
    expect(find.text('订阅价格'), findsOneWidget);
    expect(find.text('¥6.00'), findsOneWidget);
    expect(find.text('单位价格'), findsOneWidget);
    expect(find.text('¥6.00 / 年'), findsOneWidget);
    expect(
      find.textContaining('Subscriptions renew automatically'),
      findsOneWidget,
    );
    expect(find.text('隐私政策 Privacy Policy'), findsOneWidget);
    expect(find.text('使用条款 Terms of Use'), findsOneWidget);
    expect(
      find.text('https://yuyuan-ios.github.io/asset_ledger_app/privacy.html'),
      findsOneWidget,
    );
    expect(
      find.text('https://yuyuan-ios.github.io/asset_ledger_app/terms.html'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('隐私政策 Privacy Policy'));
    await tester.tap(find.text('隐私政策 Privacy Policy'));
    await tester.ensureVisible(find.text('使用条款 Terms of Use'));
    await tester.tap(find.text('使用条款 Terms of Use'));

    expect(openedPrivacy, isTrue);
    expect(openedTerms, isTrue);
  });

  testWidgets('blocks purchase when App Store product details are missing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: UpgradeSubscriptionDisclosurePattern(
              subscriptionTitle: '机账通 Pro 月度订阅',
              subscriptionLength: '每月 / 1 month',
              subscriptionPrice: '等待 App Store 商品信息 / Loading from App Store',
              unitPrice: '商品信息加载后显示 / Available after product details load',
              canPurchaseSelectedProduct: false,
              privacyPolicyUrl: 'https://example.test/privacy.html',
              termsOfServiceUrl: 'https://example.test/terms.html',
              onPrivacyTap: () {},
              onTermsTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('商品信息未完整加载前无法购买'), findsOneWidget);
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
