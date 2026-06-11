// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fleet Ledger';

  @override
  String get tabTiming => 'Timing';

  @override
  String get tabEnergy => 'Energy';

  @override
  String get tabAccount => 'Accounts';

  @override
  String get tabMaintenance => 'Service';

  @override
  String get tabDevice => 'Devices';
}
