// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Fleet Ledger';

  @override
  String get tabTiming => '计时';

  @override
  String get tabEnergy => '油电';

  @override
  String get tabAccount => '账户';

  @override
  String get tabMaintenance => '维保';

  @override
  String get tabDevice => '设备';
}
