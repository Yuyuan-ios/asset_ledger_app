import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// OS 任务切换器/窗口标题中的应用名(品牌名,跨语言保持一致)
  ///
  /// In zh, this message translates to:
  /// **'Fleet Ledger'**
  String get appTitle;

  /// 底部导航:计时记录入口
  ///
  /// In zh, this message translates to:
  /// **'计时'**
  String get tabTiming;

  /// 底部导航:能耗入口。纲要 §10.4:原「燃油」改名「油电」,同时容纳燃油机械油耗与电动设备电量/续航统计
  ///
  /// In zh, this message translates to:
  /// **'油电'**
  String get tabEnergy;

  /// 底部导航:账户/应收入口
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get tabAccount;

  /// 底部导航:维修保养入口
  ///
  /// In zh, this message translates to:
  /// **'维保'**
  String get tabMaintenance;

  /// 底部导航:设备管理入口
  ///
  /// In zh, this message translates to:
  /// **'设备'**
  String get tabDevice;

  /// 计时模块:工时计算器显示区的空表达式占位
  ///
  /// In zh, this message translates to:
  /// **'工时计算式'**
  String get timingCalculatorExpressionPlaceholder;

  /// 计时模块:工时计算器尚未产生结果时的状态文案
  ///
  /// In zh, this message translates to:
  /// **'未计算'**
  String get timingCalculatorNoResult;

  /// 计时模块:工时计算器结果显示
  ///
  /// In zh, this message translates to:
  /// **'结果 {value} h'**
  String timingCalculatorResult(String value);

  /// 计时模块:工时计算器等号键下方的应用结果按钮文案
  ///
  /// In zh, this message translates to:
  /// **'填入'**
  String get timingCalculatorApplyButton;

  /// 计时模块:工时计算器历史列表为空态
  ///
  /// In zh, this message translates to:
  /// **'暂无计算记录'**
  String get timingCalculationHistoryEmpty;

  /// 计时模块:工时计算器历史记录时间与票据数量
  ///
  /// In zh, this message translates to:
  /// **'{date} | 票据 {count} 张'**
  String timingCalculationHistoryMeta(String date, int count);

  /// 计时模块:工时计算器历史记录已应用到工时输入的标记
  ///
  /// In zh, this message translates to:
  /// **'已填入工时'**
  String get timingCalculationAppliedBadge;

  /// 计时模块:计时录入页附件模式选择器的普通挖斗选项
  ///
  /// In zh, this message translates to:
  /// **'挖斗'**
  String get timingAttachmentDigging;

  /// 计时模块:计时录入页附件模式选择器的破碎锤选项
  ///
  /// In zh, this message translates to:
  /// **'破碎'**
  String get timingAttachmentBreaking;

  /// 计时模块:计时首页最近记录分区标题
  ///
  /// In zh, this message translates to:
  /// **'最近记录'**
  String get timingRecentRecordsTitle;

  /// 计时模块:计时首页外协项目分区标题
  ///
  /// In zh, this message translates to:
  /// **'外协项目'**
  String get timingExternalWorkProjectsTitle;

  /// 计时模块:最近记录设备筛选菜单的全部设备选项
  ///
  /// In zh, this message translates to:
  /// **'全部设备'**
  String get timingAllDevicesFilter;

  /// 计时模块:外协项目记录标题栏的导入按钮
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get timingExternalWorkImportAction;

  /// 计时模块:外协项目记录标题栏的关联按钮
  ///
  /// In zh, this message translates to:
  /// **'关联'**
  String get timingExternalWorkLinkAction;

  /// 计时模块:最近记录聚合行的记录数量
  ///
  /// In zh, this message translates to:
  /// **'{count}条记录'**
  String timingRecentRecordCount(int count);

  /// 计时模块:最近记录聚合行的码表误差与累计工时
  ///
  /// In zh, this message translates to:
  /// **'误差 {error}，累计 {total}'**
  String timingRecentAggregateSummary(String error, String total);

  /// 计时模块:最近记录日期标题中表示聚合记录已展开的状态
  ///
  /// In zh, this message translates to:
  /// **'已展开'**
  String get timingRecentAggregateExpanded;

  /// 计时模块:最近记录日期标题中表示多条记录已聚合的状态
  ///
  /// In zh, this message translates to:
  /// **'已聚合'**
  String get timingRecentAggregateCollapsed;

  /// 计时模块:最近记录行中表示破碎模式的短标签
  ///
  /// In zh, this message translates to:
  /// **'破碎'**
  String get timingRecentBreakingBadge;

  /// 计时模块:外协包关联底部弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'关联到项目'**
  String get timingExternalWorkLinkSheetTitle;

  /// 计时模块:外协包关联弹窗中的外协包选择区标题
  ///
  /// In zh, this message translates to:
  /// **'选择外协包'**
  String get timingExternalWorkSelectPackage;

  /// 计时模块:外协包关联弹窗中的外协包摘要区标题
  ///
  /// In zh, this message translates to:
  /// **'外协包摘要'**
  String get timingExternalWorkPackageSummary;

  /// 计时模块:外协包关联弹窗取消按钮
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get timingExternalWorkCancelAction;

  /// 计时模块:外协包关联弹窗解除关联按钮
  ///
  /// In zh, this message translates to:
  /// **'解除关联'**
  String get timingExternalWorkUnlinkAction;

  /// 计时模块:外协包关联弹窗确认关联按钮
  ///
  /// In zh, this message translates to:
  /// **'确认关联'**
  String get timingExternalWorkConfirmLinkAction;

  /// 计时模块:外协包关联弹窗中已关联项目提示
  ///
  /// In zh, this message translates to:
  /// **'已关联：{title}'**
  String timingExternalWorkLinkedProject(String title);

  /// 计时模块:外协包关联弹窗中的本地项目选择区标题
  ///
  /// In zh, this message translates to:
  /// **'选择要关联的项目'**
  String get timingExternalWorkSelectProject;

  /// 计时模块:外协包关联弹窗中无可关联项目时的空态
  ///
  /// In zh, this message translates to:
  /// **'暂无可关联的自有项目'**
  String get timingExternalWorkNoLinkableProjects;

  /// 计时模块:外协包关联弹窗中已结清候选项目的显示标题
  ///
  /// In zh, this message translates to:
  /// **'{title}（已结清）'**
  String timingExternalWorkSettledCandidateTitle(String title);

  /// 计时模块:选择已结清项目时在外协包关联弹窗内展示的边界提示
  ///
  /// In zh, this message translates to:
  /// **'该项目已结清。关联外协包后将撤销结清状态，并按新的项目总应收重新计算待收。'**
  String get timingExternalWorkSettledHint;

  /// 计时模块:关联外协包到已结清项目前的确认弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'关联到已结清项目'**
  String get timingExternalWorkSettledConfirmTitle;

  /// 计时模块:关联外协包到已结清项目前的确认弹窗正文
  ///
  /// In zh, this message translates to:
  /// **'该项目已结清。关联外协包后将撤销结清状态，并按新的项目总应收重新计算待收。是否继续？'**
  String get timingExternalWorkSettledConfirmContent;

  /// 计时模块:外协包关联二次确认弹窗的继续按钮
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get timingExternalWorkContinueAction;

  /// 计时模块:外协包已有关联但找不到本地项目标题时的默认项目名
  ///
  /// In zh, this message translates to:
  /// **'已关联项目'**
  String get timingExternalWorkDefaultLinkedProjectTitle;

  /// 计时模块:外协包摘要中的记录数量
  ///
  /// In zh, this message translates to:
  /// **'{count}条记录'**
  String timingExternalWorkPackageRecordCount(int count);

  /// 计时模块:外协包地址摘要中多个地址之间的分隔符
  ///
  /// In zh, this message translates to:
  /// **'、'**
  String get timingExternalWorkSiteSummarySeparator;

  /// 计时模块:外协包成功关联到本地项目后的 toast
  ///
  /// In zh, this message translates to:
  /// **'已关联到项目'**
  String get timingExternalWorkLinkSuccess;

  /// 计时模块:外协包成功关联到已结清项目并撤销结清后的 toast
  ///
  /// In zh, this message translates to:
  /// **'已关联到项目，原结清已撤销'**
  String get timingExternalWorkLinkSettledSuccess;

  /// 计时模块:外协包关联失败 toast
  ///
  /// In zh, this message translates to:
  /// **'关联失败，请重试'**
  String get timingExternalWorkLinkFailure;

  /// 计时模块:解除外协包关联前的确认弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'解除关联'**
  String get timingExternalWorkUnlinkConfirmTitle;

  /// 计时模块:解除外协包关联前的确认弹窗正文
  ///
  /// In zh, this message translates to:
  /// **'解除关联后，该外协包将作为独立的外协的项目保留，不会删除外协记录。是否继续？'**
  String get timingExternalWorkUnlinkConfirmContent;

  /// 计时模块:外协包解除关联成功 toast
  ///
  /// In zh, this message translates to:
  /// **'已解除关联，外协记录已保留'**
  String get timingExternalWorkUnlinkSuccess;

  /// 计时模块:外协包解除关联失败 toast
  ///
  /// In zh, this message translates to:
  /// **'解除关联失败，请重试'**
  String get timingExternalWorkUnlinkFailure;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
