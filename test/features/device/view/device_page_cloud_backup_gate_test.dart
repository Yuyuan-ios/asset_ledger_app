import 'package:asset_ledger/app/app_providers.dart';
import 'package:asset_ledger/app/phone_login_store.dart';
import 'package:asset_ledger/data/services/backup/cloud_backup_service.dart';
import 'package:asset_ledger/data/services/local_backup_export_service.dart';
import 'package:asset_ledger/data/services/subscription_service.dart';
import 'package:asset_ledger/features/device/application/controllers/cloud_backup_controller.dart';
import 'package:asset_ledger/features/device/view/device_page.dart';
import 'package:asset_ledger/infrastructure/cloud/cloud_backup_gateway.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SubscriptionService.resetForTest();
  });

  tearDown(() {
    SubscriptionService.resetForTest();
  });

  for (final actionLabel in ['云端备份', '云端恢复']) {
    testWidgets('Pro user tapping $actionLabel sees Max upgrade gate', (
      tester,
    ) async {
      final gateway = _RecordingCloudBackupGateway();

      await _pumpDevicePage(tester, gateway);
      SubscriptionService.setStatusForTest(SubscriptionStatus.activePro);
      await tester.pumpAndSettle();

      await tester.tap(find.text('账户中心').hitTestable().first);
      await tester.pumpAndSettle();

      final action = find.text(actionLabel);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(find.text('需要升级 Max'), findsOneWidget);
      expect(
        find.text('云端备份与恢复是 Max 功能。升级 Max 后可上传当前数据，并可在需要时从云端恢复。'),
        findsOneWidget,
      );
      expect(find.text('升级 Max'), findsOneWidget);
      expect(gateway.calls, isZero);
    });
  }
}

Future<void> _pumpDevicePage(
  WidgetTester tester,
  _RecordingCloudBackupGateway gateway,
) async {
  final tokenExpiresAt =
      DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/
      1000;
  SharedPreferences.setMockInitialValues({
    SharedPreferencesPhoneLoginStore.loggedInKey: true,
    SharedPreferencesPhoneLoginStore.privacyAcceptedKey: true,
    SharedPreferencesPhoneLoginStore.phoneNumberKey: '13800138000',
    SharedPreferencesPhoneLoginStore.authTokenKey: 'token',
    SharedPreferencesPhoneLoginStore.tokenExpiresAtKey: tokenExpiresAt,
  });

  final bundle = AppProviders.build();
  final cloudBackupController = CloudBackupController(
    service: CloudBackupService(
      gateway: gateway,
      exportBackup: () async => const LocalBackupExportResult(success: false),
    ),
    canUseCloudBackup: () => SubscriptionService.canUseCloudBackup,
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ...bundle.providers,
        Provider<CloudBackupController>.value(value: cloudBackupController),
      ],
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: DevicePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _RecordingCloudBackupGateway implements CloudBackupGateway {
  var calls = 0;

  @override
  Future<CloudBackupEnvelope> download(String backupId) async {
    calls++;
    throw const CloudBackupGatewayException('unexpected', 'unexpected call');
  }

  @override
  Future<List<CloudBackupMetadata>> list() async {
    calls++;
    throw const CloudBackupGatewayException('unexpected', 'unexpected call');
  }

  @override
  Future<String> upload(CloudBackupEnvelope envelope) async {
    calls++;
    throw const CloudBackupGatewayException('unexpected', 'unexpected call');
  }
}
