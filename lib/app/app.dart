import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_navigator.dart';
import 'inbound_share_file_gate.dart';
import 'phone_login_gate.dart';
import 'router.dart';
import 'sync_lifecycle_gate.dart';
import '../core/theme/app_theme.dart';
import '../l10n/gen/app_localizations.dart';

class AssetLedgerApp extends StatelessWidget {
  const AssetLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AppNavigator.key,
      // i18n 阶段 A:文案 key 化经 AppLocalizations(lib/l10n/*.arb,zh 为
      // 第一语言包)。title 用 onGenerateTitle 取 key,作为链路试点。
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      theme: AppTheme.light(),
      home: const PhoneLoginGate(
        child: SyncLifecycleGate(
          child: InboundShareFileGate(child: AppRouterEntry()),
        ),
      ),
    );
  }
}
