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

  /// 通用:列表/分区标题栏中的新增按钮
  ///
  /// In zh, this message translates to:
  /// **'+ 新建'**
  String get commonCreateAction;

  /// 计时模块:计时首页顶部标题
  ///
  /// In zh, this message translates to:
  /// **'计时'**
  String get timingSectionHeaderTitle;

  /// App 版本更新弹窗:立即跳转更新的主按钮文案
  ///
  /// In zh, this message translates to:
  /// **'立即更新'**
  String get appUpdateActionUpdateNow;

  /// App 版本更新普通提示弹窗:暂不更新的取消按钮文案
  ///
  /// In zh, this message translates to:
  /// **'稍后再说'**
  String get appUpdateActionLater;

  /// App 版本更新弹窗:服务端未下发标题时的客户端兜底标题
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get appUpdateFallbackTitle;

  /// App 版本更新弹窗:服务端未下发正文时的客户端兜底正文
  ///
  /// In zh, this message translates to:
  /// **'更新以获得更稳定的体验。'**
  String get appUpdateFallbackContent;

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

  /// 外协导入:选择的分享包扩展名不支持时的提示
  ///
  /// In zh, this message translates to:
  /// **'请选择 FleetLedger .jzt 分享包'**
  String get externalWorkPickInvalidType;

  /// 外协导入:分享包读取失败或内容为空时的提示
  ///
  /// In zh, this message translates to:
  /// **'读取分享包失败，请重新选择文件'**
  String get externalWorkPickReadFailure;

  /// 外协导入:分享包超过大小上限时的提示
  ///
  /// In zh, this message translates to:
  /// **'分享包文件过大，无法导入'**
  String get externalWorkPickFileTooLarge;

  /// 外协导入预览页标题
  ///
  /// In zh, this message translates to:
  /// **'外协项目记录'**
  String get externalWorkImportPreviewTitle;

  /// 外协导入预览页确认按钮导入中的状态
  ///
  /// In zh, this message translates to:
  /// **'导入中'**
  String get externalWorkImportPreviewImportingAction;

  /// 外协导入预览页摘要区标题
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get externalWorkImportPreviewSectionTitle;

  /// 外协导入预览页分享来源行标签
  ///
  /// In zh, this message translates to:
  /// **'来自'**
  String get externalWorkImportPreviewSenderLabel;

  /// 外协导入预览页记录数量行标签
  ///
  /// In zh, this message translates to:
  /// **'记录'**
  String get externalWorkImportPreviewRecordLabel;

  /// 外协导入预览页记录数量值
  ///
  /// In zh, this message translates to:
  /// **'{count} 条'**
  String externalWorkImportPreviewRecordCount(int count);

  /// 外协导入预览页地点行标签
  ///
  /// In zh, this message translates to:
  /// **'地点'**
  String get externalWorkImportPreviewSiteLabel;

  /// 外协导入预览页总工时行标签
  ///
  /// In zh, this message translates to:
  /// **'总工时'**
  String get externalWorkImportPreviewTotalHoursLabel;

  /// 外协导入预览页总金额行标签
  ///
  /// In zh, this message translates to:
  /// **'总金额'**
  String get externalWorkImportPreviewTotalAmountLabel;

  /// 外协导入预览页记录明细标题
  ///
  /// In zh, this message translates to:
  /// **'记录明细'**
  String get externalWorkImportPreviewLinesTitle;

  /// 外协导入预览页工时值
  ///
  /// In zh, this message translates to:
  /// **'{hours}小时'**
  String externalWorkImportPreviewHoursValue(String hours);

  /// 外协导入预览页记录可导入状态标签
  ///
  /// In zh, this message translates to:
  /// **'可导入'**
  String get externalWorkImportPreviewStatusImportable;

  /// 外协导入预览页记录已导入状态标签
  ///
  /// In zh, this message translates to:
  /// **'已导入过'**
  String get externalWorkImportPreviewStatusImported;

  /// 外协导入预览页记录存在相同来源记录状态标签
  ///
  /// In zh, this message translates to:
  /// **'存在相同来源记录'**
  String get externalWorkImportPreviewStatusSameSource;

  /// 外协导入预览页记录存在可疑重复状态标签
  ///
  /// In zh, this message translates to:
  /// **'存在可疑重复记录'**
  String get externalWorkImportPreviewStatusSuspiciousDuplicate;

  /// 外协导入预览页相同来源重复数量摘要
  ///
  /// In zh, this message translates to:
  /// **'存在相同来源记录 {count} 条'**
  String externalWorkImportPreviewSameSourceCount(int count);

  /// 外协导入预览页可疑重复数量摘要
  ///
  /// In zh, this message translates to:
  /// **'存在可疑重复记录 {count} 条'**
  String externalWorkImportPreviewSuspiciousCount(int count);

  /// 外协导入预览页导入成功消息
  ///
  /// In zh, this message translates to:
  /// **'已导入 {count} 条外协项目记录'**
  String externalWorkImportPreviewImportedSuccess(int count);

  /// 外协导入预览页导入成功横幅完整文案
  ///
  /// In zh, this message translates to:
  /// **'{message}，可在外协项目记录中查看'**
  String externalWorkImportPreviewSuccessBanner(String message);

  /// 外协导入预览页预览生成失败兜底消息
  ///
  /// In zh, this message translates to:
  /// **'导入预览生成失败，请稍后重试'**
  String get externalWorkImportPreviewGenericPrepareFailure;

  /// 外协导入预览页导入失败兜底消息
  ///
  /// In zh, this message translates to:
  /// **'导入失败，请稍后重试'**
  String get externalWorkImportPreviewGenericImportFailure;

  /// 外协导入预览页空内容错误
  ///
  /// In zh, this message translates to:
  /// **'请先选择或粘贴 .jzt 内容'**
  String get externalWorkImportPreviewEmptyContent;

  /// 外协导入预览页 JSON 解析失败错误
  ///
  /// In zh, this message translates to:
  /// **'分享包不是有效的 JSON 内容'**
  String get externalWorkImportPreviewInvalidJson;

  /// 外协导入预览页分享包 magic 不匹配错误
  ///
  /// In zh, this message translates to:
  /// **'这不是有效的 FleetLedger 分享包'**
  String get externalWorkImportPreviewInvalidPackage;

  /// 外协导入预览页分享包版本不支持错误
  ///
  /// In zh, this message translates to:
  /// **'分享包版本暂不支持'**
  String get externalWorkImportPreviewUnsupportedVersion;

  /// 外协导入预览页分享包类型不支持错误
  ///
  /// In zh, this message translates to:
  /// **'暂不支持这种分享包'**
  String get externalWorkImportPreviewUnsupportedPackage;

  /// 外协导入预览页完整性信息不完整错误
  ///
  /// In zh, this message translates to:
  /// **'分享包完整性信息不完整'**
  String get externalWorkImportPreviewIncompleteIntegrity;

  /// 外协导入预览页 payload hash 校验失败错误
  ///
  /// In zh, this message translates to:
  /// **'分享包内容校验失败，请重新获取分享包'**
  String get externalWorkImportPreviewHashMismatch;

  /// 外协导入预览页记录内容无效错误
  ///
  /// In zh, this message translates to:
  /// **'分享包记录内容不完整或格式异常'**
  String get externalWorkImportPreviewInvalidRecords;

  /// 外协导入预览页基础信息无效错误
  ///
  /// In zh, this message translates to:
  /// **'分享包基础信息不完整或格式异常'**
  String get externalWorkImportPreviewInvalidBaseInfo;

  /// 外协导入预览页分享包解析失败兜底错误
  ///
  /// In zh, this message translates to:
  /// **'分享包无法解析'**
  String get externalWorkImportPreviewParseFailure;

  /// 外协导入预览页确认导入时因重复被拒绝的错误
  ///
  /// In zh, this message translates to:
  /// **'这份分享包已导入过，或包含相同来源记录'**
  String get externalWorkImportPreviewDuplicateRejected;

  /// 计时页外协项目记录列表空态标题
  ///
  /// In zh, this message translates to:
  /// **'暂无外协项目记录'**
  String get externalWorkRecordsEmptyTitle;

  /// 计时页外协项目记录列表空态说明
  ///
  /// In zh, this message translates to:
  /// **'从他人分享的 .jzt 文件导入后，会显示在这里'**
  String get externalWorkRecordsEmptySubtitle;

  /// 计时页外协项目记录详情来源说明
  ///
  /// In zh, this message translates to:
  /// **'从分享包导入'**
  String get externalWorkRecordsSourceImported;

  /// 计时页外协项目记录聚合行的记录数量后缀
  ///
  /// In zh, this message translates to:
  /// **'•{count}条记录'**
  String externalWorkRecordsBulletCount(int count);

  /// 计时页外协项目记录聚合行的设备数量后缀
  ///
  /// In zh, this message translates to:
  /// **'等{count}台'**
  String externalWorkRecordsMoreDevices(int count);

  /// 计时页外协项目记录设备信息为空时的兜底
  ///
  /// In zh, this message translates to:
  /// **'设备未填写'**
  String get externalWorkRecordsMissingDevice;

  /// 计时页外协项目记录未知值兜底
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get externalWorkRecordsUnknown;

  /// 计时页外协项目记录已关联状态
  ///
  /// In zh, this message translates to:
  /// **'已关联'**
  String get externalWorkRecordsStatusLinked;

  /// 计时页外协项目记录待处理状态
  ///
  /// In zh, this message translates to:
  /// **'待处理'**
  String get externalWorkRecordsStatusPending;

  /// 计时页外协项目记录已忽略状态
  ///
  /// In zh, this message translates to:
  /// **'已忽略'**
  String get externalWorkRecordsStatusIgnored;

  /// 计时页外协项目记录已归档状态
  ///
  /// In zh, this message translates to:
  /// **'已归档'**
  String get externalWorkRecordsStatusArchived;

  /// 计时页外协项目记录已作废状态
  ///
  /// In zh, this message translates to:
  /// **'已作废'**
  String get externalWorkRecordsStatusVoided;

  /// 计时页外协项目记录年份分组标题
  ///
  /// In zh, this message translates to:
  /// **'{year}年'**
  String externalWorkRecordsYearLabel(int year);

  /// 计时页外协项目记录详情来源行标签
  ///
  /// In zh, this message translates to:
  /// **'来源'**
  String get externalWorkRecordsSourceLabel;

  /// 计时页外协项目记录详情分享人行标签
  ///
  /// In zh, this message translates to:
  /// **'分享人'**
  String get externalWorkRecordsSourceNameLabel;

  /// 计时页外协项目记录详情地址行标签
  ///
  /// In zh, this message translates to:
  /// **'地址'**
  String get externalWorkRecordsSiteLabel;

  /// 计时页外协项目记录详情设备行标签
  ///
  /// In zh, this message translates to:
  /// **'设备'**
  String get externalWorkRecordsDeviceLabel;

  /// 计时页外协项目记录详情日期行标签
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get externalWorkRecordsDateLabel;

  /// 计时页外协项目记录详情工时数量行标签
  ///
  /// In zh, this message translates to:
  /// **'工时 / 数量'**
  String get externalWorkRecordsHoursQuantityLabel;

  /// 计时页外协项目记录详情单价行标签
  ///
  /// In zh, this message translates to:
  /// **'单价'**
  String get externalWorkRecordsUnitPriceLabel;

  /// 计时页外协项目记录详情金额行标签
  ///
  /// In zh, this message translates to:
  /// **'金额'**
  String get externalWorkRecordsAmountLabel;

  /// 计时页外协项目记录详情已收项目款行标签
  ///
  /// In zh, this message translates to:
  /// **'已收项目款'**
  String get externalWorkRecordsProjectReceivedLabel;

  /// 计时页外协项目记录详情导入时间行标签
  ///
  /// In zh, this message translates to:
  /// **'导入时间'**
  String get externalWorkRecordsImportedAtLabel;

  /// 计时页外协项目记录详情当前状态行标签
  ///
  /// In zh, this message translates to:
  /// **'当前状态'**
  String get externalWorkRecordsCurrentStatusLabel;

  /// 计时页外协项目记录详情只读说明
  ///
  /// In zh, this message translates to:
  /// **'这条记录来自他人分享，当前不可编辑。'**
  String get externalWorkRecordsReadOnlyNotice;

  /// 计时页外协项目记录详情关联到本地项目按钮
  ///
  /// In zh, this message translates to:
  /// **'关联到本地项目'**
  String get externalWorkRecordsLinkAction;

  /// 计时页外协项目记录列表头像短字
  ///
  /// In zh, this message translates to:
  /// **'协'**
  String get externalWorkRecordsAvatarLabel;

  /// 计时页外协项目详情底部弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'外协项目详情'**
  String get externalWorkDetailSheetTitle;

  /// 计时页外协项目详情底部弹窗删除分享包按钮
  ///
  /// In zh, this message translates to:
  /// **'删除分享包'**
  String get externalWorkDeleteSharePackageAction;

  /// 计时页删除外协分享包确认弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'删除分享包'**
  String get externalWorkDeleteSharePackageTitle;

  /// 计时页删除外协分享包确认弹窗正文
  ///
  /// In zh, this message translates to:
  /// **'这将删除该分享包导入的全部 {count} 条外协记录，删除后不可恢复。'**
  String externalWorkDeleteSharePackageContent(int count);

  /// 外协模块删除按钮
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get externalWorkDeleteAction;

  /// 外协模块读取动作名,用于 store 反馈文案
  ///
  /// In zh, this message translates to:
  /// **'读取'**
  String get externalWorkReadAction;

  /// 外协模块确认按钮
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get externalWorkConfirmAction;

  /// 计时模块:新建计时记录底部录入 sheet 标题
  ///
  /// In zh, this message translates to:
  /// **'新建计时'**
  String get timingEntryCreateSheetTitle;

  /// 计时模块:编辑计时记录底部录入 sheet 标题
  ///
  /// In zh, this message translates to:
  /// **'编辑计时'**
  String get timingEntryEditSheetTitle;

  /// 计时模块:新建计时记录底部录入 sheet 的取消按钮
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get timingEntryCancelAction;

  /// 计时模块:编辑计时记录底部录入 sheet 的删除当前记录按钮
  ///
  /// In zh, this message translates to:
  /// **'删除本记录'**
  String get timingEntryDeleteRecordAction;

  /// 计时模块:编辑计时记录时加载工时计算历史失败后的 toast
  ///
  /// In zh, this message translates to:
  /// **'工时计算历史加载失败，仍可继续编辑'**
  String get timingEntryHistoryLoadFailure;

  /// 计时模块:计时记录保存失败的通用 toast
  ///
  /// In zh, this message translates to:
  /// **'保存失败，请重试'**
  String get timingEntrySaveFailure;

  /// 计时模块:计时记录删除前影响检查失败的 toast
  ///
  /// In zh, this message translates to:
  /// **'删除前检查失败，请重试'**
  String get timingEntryDeletePrecheckFailure;

  /// 计时模块:删除计时记录二次确认弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'删除计时记录'**
  String get timingEntryDeleteConfirmTitle;

  /// 计时模块:删除计时记录二次确认弹窗确认按钮
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get timingEntryDeleteConfirmAction;

  /// 计时模块:删除计时记录失败 toast
  ///
  /// In zh, this message translates to:
  /// **'删除失败，请重试'**
  String get timingEntryDeleteFailure;

  /// 计时模块:计时记录因收款等原因无法删除的弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'无法删除'**
  String get timingEntryDeleteBlockedTitle;

  /// 计时模块:无法删除计时记录提示弹窗确认按钮
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get timingEntryDeleteBlockedConfirm;

  /// 计时模块:删除已结清项目中的计时记录时的二次确认正文
  ///
  /// In zh, this message translates to:
  /// **'该项目已结清。删除计时记录后将撤销结清状态，并按新的项目金额重新计算待收。是否继续？'**
  String get timingEntryDeleteSettledConfirmContent;

  /// 计时模块:删除项目最后一条本地计时记录时的二次确认正文
  ///
  /// In zh, this message translates to:
  /// **'删除后，该项目将不再有本地计时记录，并会同步解除相关合并/外协关联。是否继续？'**
  String get timingEntryDeleteLastRecordConfirmContent;

  /// 计时模块:普通计时记录删除二次确认正文
  ///
  /// In zh, this message translates to:
  /// **'删除后不可恢复，确认删除这条记录吗？'**
  String get timingEntryDeleteDefaultConfirmContent;

  /// 计时模块:计时记录删除成功 toast
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get timingEntryDeleted;

  /// 计时模块:删除计时记录后同步撤销结清状态的成功摘要片段
  ///
  /// In zh, this message translates to:
  /// **'已撤销结清'**
  String get timingEntrySettlementRevoked;

  /// 计时模块:删除计时记录后同步解除合并组的成功摘要片段
  ///
  /// In zh, this message translates to:
  /// **'已解除合并'**
  String get timingEntryMergeDissolved;

  /// 计时模块:删除计时记录后同步从合并组移出项目的成功摘要片段
  ///
  /// In zh, this message translates to:
  /// **'已移出合并'**
  String get timingEntryMergeMemberRemoved;

  /// 计时模块:删除计时记录后同步解除外协关联的成功摘要片段
  ///
  /// In zh, this message translates to:
  /// **'已解除外协关联'**
  String get timingEntryExternalWorkUnlinked;

  /// 计时模块:删除计时记录成功摘要中多个级联动作之间的分隔符
  ///
  /// In zh, this message translates to:
  /// **'、'**
  String get timingEntryDeleteCascadeSeparator;

  /// 计时模块:删除计时记录成功且带有级联动作摘要的 toast
  ///
  /// In zh, this message translates to:
  /// **'已删除，{details}'**
  String timingEntryDeleteCascadeSuccess(String details);

  /// 计时模块:计时录入表单设备下拉字段标签
  ///
  /// In zh, this message translates to:
  /// **'设备编号'**
  String get timingEntryDeviceLabel;

  /// 计时模块:计时录入表单设备下拉字段占位
  ///
  /// In zh, this message translates to:
  /// **'请选择设备'**
  String get timingEntryDeviceHint;

  /// 计时模块:计时录入表单无在用设备时的设备下拉占位
  ///
  /// In zh, this message translates to:
  /// **'暂无在用设备，请先去“设备”页新增'**
  String get timingEntryNoActiveDeviceHint;

  /// 计时模块:计时录入表单联系人字段标签与占位
  ///
  /// In zh, this message translates to:
  /// **'联系人'**
  String get timingEntryContactLabel;

  /// 计时模块:计时录入表单使用地址/工地字段标签与占位
  ///
  /// In zh, this message translates to:
  /// **'使用地址/工地'**
  String get timingEntrySiteLabel;

  /// 计时模块:计时录入表单开始工作时间/码表字段标题
  ///
  /// In zh, this message translates to:
  /// **'开始工作时间'**
  String get timingEntryStartWorkTimeLabel;

  /// 计时模块:计时录入表单结束工作时间/码表字段标题
  ///
  /// In zh, this message translates to:
  /// **'结束工作时间'**
  String get timingEntryEndWorkTimeLabel;

  /// 计时模块:计时录入表单打开工时计算器的图标 tooltip
  ///
  /// In zh, this message translates to:
  /// **'工时计算依据'**
  String get timingEntryWorkHourBasisTooltip;

  /// 计时模块:计时录入表单租金模式工时字段可空占位
  ///
  /// In zh, this message translates to:
  /// **'0.0（可空）'**
  String get timingEntryOptionalZeroHint;

  /// 计时模块:计时录入表单租金模式金额字段标签
  ///
  /// In zh, this message translates to:
  /// **'金额（元）'**
  String get timingEntryAmountYuanLabel;

  /// 计时模块:计时首页收入/支出图表的年份标题
  ///
  /// In zh, this message translates to:
  /// **'{year}年'**
  String timingChartYearLabel(int year);

  /// 计时模块:计时首页图表收入柱图例
  ///
  /// In zh, this message translates to:
  /// **'收入'**
  String get timingChartIncomeLegend;

  /// 计时模块:计时首页图表净收入值标签
  ///
  /// In zh, this message translates to:
  /// **'净入'**
  String get timingChartNetIncomeValueLabel;

  /// 计时模块:计时首页图表支出图例和值标签
  ///
  /// In zh, this message translates to:
  /// **'支出'**
  String get timingChartExpenseLabel;

  /// 通用:最近记录列表标题及记录数量
  ///
  /// In zh, this message translates to:
  /// **'最近记录({count})'**
  String commonRecentRecordsCount(int count);

  /// 通用:最近记录列表为空时的标题
  ///
  /// In zh, this message translates to:
  /// **'暂无记录'**
  String get commonNoRecordsTitle;

  /// 通用:最近记录列表为空时提示用户从右上角新增
  ///
  /// In zh, this message translates to:
  /// **'点击右上角 + 新建'**
  String get commonCreateFromTopRightHint;

  /// 油电模块:油电页标题
  ///
  /// In zh, this message translates to:
  /// **'油电'**
  String get fuelPageTitle;

  /// 油电模块:新增油电记录底部录入 sheet 标题
  ///
  /// In zh, this message translates to:
  /// **'新增油电'**
  String get fuelCreateSheetTitle;

  /// 油电模块:编辑油电记录底部录入 sheet 标题
  ///
  /// In zh, this message translates to:
  /// **'编辑油电'**
  String get fuelEditSheetTitle;

  /// 油电模块:油电记录弹窗取消按钮
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get fuelCancelAction;

  /// 油电模块:油电记录录入 sheet 确认按钮
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get fuelConfirmAction;

  /// 油电模块:删除油电记录二次确认弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'确认删除？'**
  String get fuelDeleteConfirmTitle;

  /// 油电模块:删除油电记录二次确认弹窗正文
  ///
  /// In zh, this message translates to:
  /// **'删除后不可恢复。'**
  String get fuelDeleteConfirmContent;

  /// 油电模块:删除油电记录二次确认弹窗确认按钮
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get fuelDeleteConfirmAction;

  /// 油电模块:油电效率卡片中设备已停用或不存在时的兜底设备名
  ///
  /// In zh, this message translates to:
  /// **'设备{id}（已停用/不存在）'**
  String fuelInactiveDeviceFallbackName(int id);

  /// 油电模块:油电录入表单设备下拉字段标签
  ///
  /// In zh, this message translates to:
  /// **'设备编号'**
  String get fuelDeviceLabel;

  /// 油电模块:油电录入表单设备下拉字段占位
  ///
  /// In zh, this message translates to:
  /// **'请选择设备'**
  String get fuelDeviceHint;

  /// 油电模块:油电录入表单无在用设备时的设备下拉占位
  ///
  /// In zh, this message translates to:
  /// **'暂无在用设备，请先去“设备”页新增'**
  String get fuelNoActiveDeviceHint;

  /// 油电模块:油电录入表单供应人字段标签
  ///
  /// In zh, this message translates to:
  /// **'供应人（必填）'**
  String get fuelSupplierRequiredLabel;

  /// 油电模块:油电录入表单供应人字段占位
  ///
  /// In zh, this message translates to:
  /// **'例如：中石化 / 充电站'**
  String get fuelSupplierHint;

  /// 油电模块:油电录入表单用量字段标签
  ///
  /// In zh, this message translates to:
  /// **'油电用量（升/度）'**
  String get fuelLitersLabel;

  /// 油电模块:油电录入表单用量字段占位
  ///
  /// In zh, this message translates to:
  /// **'例如：120.0'**
  String get fuelLitersHint;

  /// 油电模块:油电录入表单金额字段标签
  ///
  /// In zh, this message translates to:
  /// **'金额（元）'**
  String get fuelAmountYuanLabel;

  /// 油电模块:油电录入表单金额字段占位
  ///
  /// In zh, this message translates to:
  /// **'例如：980.0'**
  String get fuelAmountHint;

  /// 油电模块:油电效率统计卡片标题
  ///
  /// In zh, this message translates to:
  /// **'设备油电效率'**
  String get fuelEfficiencyTitle;

  /// 油电模块:油电效率统计卡片为空时的提示
  ///
  /// In zh, this message translates to:
  /// **'暂无数据（先录入油电记录与工时记录）'**
  String get fuelEfficiencyEmpty;

  /// 油电模块:供应人筛选输入框标签
  ///
  /// In zh, this message translates to:
  /// **'筛选：供应人'**
  String get fuelSupplierFilterLabel;

  /// 油电模块:供应人筛选输入框占位
  ///
  /// In zh, this message translates to:
  /// **'输入关键字即可过滤（可空）'**
  String get fuelSupplierFilterHint;

  /// 维保模块:维保页标题
  ///
  /// In zh, this message translates to:
  /// **'维保'**
  String get maintenancePageTitle;

  /// 维保模块:新增维保记录底部录入 sheet 标题
  ///
  /// In zh, this message translates to:
  /// **'新建维保'**
  String get maintenanceCreateSheetTitle;

  /// 维保模块:编辑维保记录底部录入 sheet 标题
  ///
  /// In zh, this message translates to:
  /// **'编辑维保'**
  String get maintenanceEditSheetTitle;

  /// 维保模块:维保记录弹窗取消按钮
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get maintenanceCancelAction;

  /// 维保模块:维保记录录入 sheet 确认按钮
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get maintenanceConfirmAction;

  /// 维保模块:删除维保记录二次确认弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'确认删除？'**
  String get maintenanceDeleteConfirmTitle;

  /// 维保模块:删除维保记录二次确认弹窗日期行
  ///
  /// In zh, this message translates to:
  /// **'日期：{date}'**
  String maintenanceDeleteConfirmDateLine(String date);

  /// 维保模块:删除维保记录二次确认弹窗事项行
  ///
  /// In zh, this message translates to:
  /// **'事项：{item}'**
  String maintenanceDeleteConfirmItemLine(String item);

  /// 维保模块:删除维保记录二次确认弹窗金额行
  ///
  /// In zh, this message translates to:
  /// **'金额：{amount}'**
  String maintenanceDeleteConfirmAmountLine(String amount);

  /// 维保模块:删除维保记录二次确认弹窗警告
  ///
  /// In zh, this message translates to:
  /// **'⚠️ 删除后不可恢复'**
  String get maintenanceDeleteConfirmWarning;

  /// 维保模块:删除维保记录二次确认弹窗确认按钮
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get maintenanceDeleteConfirmAction;

  /// 维保模块:当年维保费用统计卡为空时的提示
  ///
  /// In zh, this message translates to:
  /// **'当年维保费：暂无数据'**
  String get maintenanceSummaryEmpty;

  /// 维保模块:当年维保费用统计卡标题
  ///
  /// In zh, this message translates to:
  /// **'当年维保费用（按设备 & 公共）'**
  String get maintenanceSummaryTitle;

  /// 维保模块:公共支出标签
  ///
  /// In zh, this message translates to:
  /// **'公共支出'**
  String get maintenancePublicExpenseLabel;

  /// 维保模块:维保费用统计合计标签
  ///
  /// In zh, this message translates to:
  /// **'合计'**
  String get maintenanceTotalLabel;

  /// 维保模块:维保录入表单公共支出开关标题
  ///
  /// In zh, this message translates to:
  /// **'公共支出（不属于任何设备）'**
  String get maintenancePublicExpenseSwitchTitle;

  /// 维保模块:维保录入表单设备下拉字段标签
  ///
  /// In zh, this message translates to:
  /// **'设备编号'**
  String get maintenanceDeviceLabel;

  /// 维保模块:维保录入表单设备下拉字段占位
  ///
  /// In zh, this message translates to:
  /// **'请选择设备'**
  String get maintenanceDeviceHint;

  /// 维保模块:维保录入表单无在用设备时的设备下拉占位
  ///
  /// In zh, this message translates to:
  /// **'暂无在用设备，请先去“设备”页新增'**
  String get maintenanceNoActiveDeviceHint;

  /// 维保模块:维保录入表单事项字段标签
  ///
  /// In zh, this message translates to:
  /// **'事项（必填）'**
  String get maintenanceItemRequiredLabel;

  /// 维保模块:维保录入表单事项字段占位
  ///
  /// In zh, this message translates to:
  /// **'例如：更换机油/保养/维修'**
  String get maintenanceItemHint;

  /// 维保模块:维保录入表单金额字段标签
  ///
  /// In zh, this message translates to:
  /// **'金额（元）'**
  String get maintenanceAmountYuanLabel;

  /// 维保模块:维保录入表单金额字段占位
  ///
  /// In zh, this message translates to:
  /// **'例如：980.0'**
  String get maintenanceAmountHint;

  /// 维保模块:维保录入表单备注字段标签
  ///
  /// In zh, this message translates to:
  /// **'备注（可填）'**
  String get maintenanceNoteOptionalLabel;

  /// 维保模块:维保录入表单备注字段占位
  ///
  /// In zh, this message translates to:
  /// **'例如：含工时/含配件'**
  String get maintenanceNoteHint;

  /// 账户模块:通用取消按钮
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get accountCancelAction;

  /// 账户模块:通用确认按钮
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get accountConfirmAction;

  /// 账户模块:通用删除按钮
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get accountDeleteAction;

  /// 账户模块:项目列表标题
  ///
  /// In zh, this message translates to:
  /// **'项目'**
  String get accountProjectTitleLabel;

  /// 账户模块:项目列表切换到普通显示的 tooltip
  ///
  /// In zh, this message translates to:
  /// **'普通显示'**
  String get accountDensityNormalTooltip;

  /// 账户模块:项目列表切换到紧凑显示的 tooltip
  ///
  /// In zh, this message translates to:
  /// **'紧凑显示'**
  String get accountDensityCompactTooltip;

  /// 账户模块:打开项目筛选入口
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get accountFilterAction;

  /// 账户模块:清除项目筛选入口
  ///
  /// In zh, this message translates to:
  /// **'取消筛选'**
  String get accountClearFilterAction;

  /// 账户模块:打开项目合并入口
  ///
  /// In zh, this message translates to:
  /// **'合并'**
  String get accountMergeAction;

  /// 账户模块:总览卡标题
  ///
  /// In zh, this message translates to:
  /// **'总    览'**
  String get accountOverviewTitle;

  /// 账户模块:总览卡无设备数据提示
  ///
  /// In zh, this message translates to:
  /// **'暂无设备数据'**
  String get accountNoDeviceData;

  /// 账户模块:总览卡总应收标签
  ///
  /// In zh, this message translates to:
  /// **'总应收'**
  String get accountTotalReceivableLabel;

  /// 账户模块:总览卡已收标签
  ///
  /// In zh, this message translates to:
  /// **'已收'**
  String get accountReceivedLabel;

  /// 账户模块:总览卡待收标签
  ///
  /// In zh, this message translates to:
  /// **'待收'**
  String get accountRemainingLabel;

  /// 账户模块:总览卡回款比例标签
  ///
  /// In zh, this message translates to:
  /// **'回款'**
  String get accountReceiptRatioLabel;

  /// 账户模块:总览卡净收款 tooltip
  ///
  /// In zh, this message translates to:
  /// **'已收款扣除油电、维保和已支付外协项目款后的金额。'**
  String get accountNetReceivedTooltip;

  /// 账户模块:总览卡净收款标签
  ///
  /// In zh, this message translates to:
  /// **'已收-开支'**
  String get accountNetReceivedLabel;

  /// 账户模块:项目不存在或被清理时的提示
  ///
  /// In zh, this message translates to:
  /// **'项目不存在或已被清理'**
  String get accountProjectMissing;

  /// 账户模块:我方项目列表为空提示
  ///
  /// In zh, this message translates to:
  /// **'暂无项目（计时页有记录后将自动出现）'**
  String get accountOwnedProjectsEmpty;

  /// 账户模块:结清项目卡片图标语义标签
  ///
  /// In zh, this message translates to:
  /// **'结清图标'**
  String get accountSettledIconLabel;

  /// 账户模块:导出工时表按钮 tooltip 和语义标签
  ///
  /// In zh, this message translates to:
  /// **'导出工时表'**
  String get accountExportWorklogTooltip;

  /// 账户模块:外协项目卡片应付指标标签
  ///
  /// In zh, this message translates to:
  /// **'外协应付'**
  String get accountExternalPayableLabel;

  /// 账户模块:外协项目卡片应收指标标签
  ///
  /// In zh, this message translates to:
  /// **'应收项目款'**
  String get accountExternalReceivableLabel;

  /// 账户模块:外协详情应收项目款标签,附带客户侧应收单价
  ///
  /// In zh, this message translates to:
  /// **'应收项目款(应收单价{rate})'**
  String accountExternalReceivableWithCustomerRate(String rate);

  /// 账户模块:外协详情应付项目款标签,附带分享包内应付单价
  ///
  /// In zh, this message translates to:
  /// **'应付项目款(应付单价{rate})'**
  String accountExternalPayableWithSourceRate(String rate);

  /// 账户模块:外协项目卡片待设置值
  ///
  /// In zh, this message translates to:
  /// **'待设置'**
  String get accountPendingSetup;

  /// 账户模块:外协项目卡片毛利指标标签
  ///
  /// In zh, this message translates to:
  /// **'毛利'**
  String get accountGrossProfitLabel;

  /// 账户模块:外协项目卡片待计算值
  ///
  /// In zh, this message translates to:
  /// **'待计算'**
  String get accountPendingCalculation;

  /// 账户模块:外协项目头像文字
  ///
  /// In zh, this message translates to:
  /// **'协'**
  String get accountExternalWorkAvatarLabel;

  /// 账户模块:外协项目列表标题
  ///
  /// In zh, this message translates to:
  /// **'外协项目'**
  String get accountExternalProjectsTitle;

  /// 账户模块:外协项目列表为空提示
  ///
  /// In zh, this message translates to:
  /// **'暂无外协项目（未关联外协包导入后将自动出现）'**
  String get accountExternalProjectsEmpty;

  /// 账户模块:外协详情 sheet 标题
  ///
  /// In zh, this message translates to:
  /// **'外协详情'**
  String get accountExternalWorkDetailTitle;

  /// 账户模块:外协详情包内总工时
  ///
  /// In zh, this message translates to:
  /// **'工时 {hours} h'**
  String accountExternalHoursSummary(String hours);

  /// 账户模块:外协详情客户侧应收单价标签
  ///
  /// In zh, this message translates to:
  /// **'应收单价'**
  String get accountExternalCustomerRateLabel;

  /// 账户模块:外协详情应付总额
  ///
  /// In zh, this message translates to:
  /// **'应付总额 {amount}'**
  String accountExternalPayableTotalSummary(String amount);

  /// 账户模块:外协详情应付进度已付百分比
  ///
  /// In zh, this message translates to:
  /// **'已付 {percent}%'**
  String accountExternalPaidPercent(int percent);

  /// 账户模块:外协详情应付进度待付金额
  ///
  /// In zh, this message translates to:
  /// **'待付 {amount}'**
  String accountExternalUnpaidAmount(String amount);

  /// 账户模块:外协详情支付记录区标题
  ///
  /// In zh, this message translates to:
  /// **'支付记录'**
  String get accountExternalPaymentRecordsTitle;

  /// 账户模块:外协详情新增应付按钮（本轮占位）
  ///
  /// In zh, this message translates to:
  /// **'+ 新增应付'**
  String get accountExternalAddPayableAction;

  /// 账户模块:外协详情支付记录占位提示
  ///
  /// In zh, this message translates to:
  /// **'支付记录即将上线'**
  String get accountExternalPaymentsEmpty;

  /// 账户模块:外协应收单价编辑对话框标题
  ///
  /// In zh, this message translates to:
  /// **'设置应收单价'**
  String get accountExternalCustomerRateEditTitle;

  /// 账户模块:外协应收单价输入框占位
  ///
  /// In zh, this message translates to:
  /// **'应收单价（元）'**
  String get accountExternalCustomerRateInputHint;

  /// 账户模块:外协应收单价输入校验错误
  ///
  /// In zh, this message translates to:
  /// **'请输入有效金额'**
  String get accountExternalCustomerRateInvalid;

  /// 账户模块:项目详情 sheet 标题
  ///
  /// In zh, this message translates to:
  /// **'项目详情'**
  String get accountProjectDetailTitle;

  /// 账户模块:关闭项目详情按钮 tooltip
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get accountCloseTooltip;

  /// 账户模块:项目详情本地设备分组标签
  ///
  /// In zh, this message translates to:
  /// **'本地设备'**
  String get accountLocalDeviceLabel;

  /// 账户模块:项目详情外协设备分组标签
  ///
  /// In zh, this message translates to:
  /// **'外协设备'**
  String get accountExternalDeviceLabel;

  /// 账户模块:项目详情批量修改单价按钮
  ///
  /// In zh, this message translates to:
  /// **'批量修改'**
  String get accountBatchEditAction;

  /// 账户模块:项目详情解除合并按钮
  ///
  /// In zh, this message translates to:
  /// **'解除合并'**
  String get accountDissolveMergeAction;

  /// 账户模块:项目详情收款记录标题
  ///
  /// In zh, this message translates to:
  /// **'收款记录'**
  String get accountPaymentsTitle;

  /// 账户模块:项目详情无收款记录提示
  ///
  /// In zh, this message translates to:
  /// **'暂无收款记录'**
  String get accountNoPayments;

  /// 账户模块:项目详情修改单价按钮
  ///
  /// In zh, this message translates to:
  /// **'修改'**
  String get accountEditAction;

  /// 账户模块:项目详情外协设备缺失提示
  ///
  /// In zh, this message translates to:
  /// **'设备未填写'**
  String get accountEquipmentMissing;

  /// 账户模块:项目详情外协设备记录数量标签
  ///
  /// In zh, this message translates to:
  /// **'{base}·{count}条记录'**
  String accountRecordCountLabel(String base, int count);

  /// 账户模块:项目详情新增收款按钮
  ///
  /// In zh, this message translates to:
  /// **'+ 新增收款'**
  String get accountAddPaymentAction;

  /// 账户模块:项目详情项目总额摘要
  ///
  /// In zh, this message translates to:
  /// **'项目总额 {amount}'**
  String accountProjectTotalSummary(String amount);

  /// 账户模块:项目详情已结清状态
  ///
  /// In zh, this message translates to:
  /// **'已结清'**
  String get accountSettledStatus;

  /// 账户模块:项目详情已结清且可撤销按钮
  ///
  /// In zh, this message translates to:
  /// **'已结清，点此撤销'**
  String get accountSettledRevokeAction;

  /// 账户模块:项目详情已收比例文案
  ///
  /// In zh, this message translates to:
  /// **'已收 {percent}%'**
  String accountReceivedPercent(String percent);

  /// 账户模块:项目详情待收金额文案
  ///
  /// In zh, this message translates to:
  /// **'待收 {amount}'**
  String accountPendingReceivable(String amount);

  /// 账户模块:项目详情结清按钮
  ///
  /// In zh, this message translates to:
  /// **'结清'**
  String get accountSettleAction;

  /// 账户模块:项目详情设备单价分组标签
  ///
  /// In zh, this message translates to:
  /// **'设备单价'**
  String get accountRateSectionLabel;

  /// 账户模块:项目详情破碎设备行名称
  ///
  /// In zh, this message translates to:
  /// **'{name} · 破碎'**
  String accountBreakingDeviceLabel(String name);

  /// 账户模块:项目详情收款备注行
  ///
  /// In zh, this message translates to:
  /// **'备注：{remark}'**
  String accountPaymentRemarkLine(String remark);

  /// 账户模块:合并收款保存成功 toast
  ///
  /// In zh, this message translates to:
  /// **'保存成功'**
  String get accountMergedPaymentSaveSuccess;

  /// 账户模块:保存失败 toast
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{reason}'**
  String accountSaveFailureWithReason(String reason);

  /// 账户模块:已保存 toast
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get accountSaved;

  /// 账户模块:删除合并收款确认标题
  ///
  /// In zh, this message translates to:
  /// **'删除收款？'**
  String get accountMergedPaymentDeleteTitle;

  /// 账户模块:删除合并收款确认正文
  ///
  /// In zh, this message translates to:
  /// **'将删除这笔合并收款及其分摊记录：\n{date}  {amount}\n\n此操作不会删除计时记录。'**
  String accountMergedPaymentDeleteContent(String date, String amount);

  /// 账户模块:删除成功 toast
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get accountDeleted;

  /// 账户模块:删除失败 toast
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{reason}'**
  String accountDeleteFailureWithReason(String reason);

  /// 账户模块:解除合并成功 toast
  ///
  /// In zh, this message translates to:
  /// **'已解除合并'**
  String get accountDissolveMergeSuccess;

  /// 账户模块:删除普通收款确认标题
  ///
  /// In zh, this message translates to:
  /// **'确认删除？'**
  String get accountDeleteConfirmTitle;

  /// 账户模块:删除普通收款确认正文
  ///
  /// In zh, this message translates to:
  /// **'日期：{date}\n金额：{amount}'**
  String accountPaymentDeleteConfirmContent(String date, String amount);

  /// 账户模块:已结清项目保存收款前撤销结清确认标题
  ///
  /// In zh, this message translates to:
  /// **'撤销结清并保存收款？'**
  String get accountSettledPaymentSaveConfirmTitle;

  /// 账户模块:已结清项目保存收款前撤销结清确认正文
  ///
  /// In zh, this message translates to:
  /// **'该项目已结清。保存收款前将先撤销结清状态，并撤销结清产生的核销结果。是否继续？'**
  String get accountSettledPaymentSaveConfirmContent;

  /// 账户模块:已结清项目删除收款前撤销结清确认正文
  ///
  /// In zh, this message translates to:
  /// **'该项目已结清。删除这笔收款前将先撤销结清状态，并撤销结清产生的核销结果。\n\n日期：{date}\n金额：{amount}\n\n是否继续？'**
  String accountSettledPaymentDeleteConfirmContent(String date, String amount);

  /// 账户模块:撤销核销成功 toast
  ///
  /// In zh, this message translates to:
  /// **'已撤销核销，待收已恢复'**
  String get accountWriteOffRevoked;

  /// 账户模块:撤销核销失败 toast
  ///
  /// In zh, this message translates to:
  /// **'撤销核销失败：{reason}'**
  String accountRevokeWriteOffFailure(String reason);

  /// 账户模块:项目核销记录异常 toast
  ///
  /// In zh, this message translates to:
  /// **'该项目核销记录异常，请先检查核销记录。'**
  String get accountWriteOffInvalid;

  /// 账户模块:撤销结清状态成功 toast
  ///
  /// In zh, this message translates to:
  /// **'已撤销结清状态'**
  String get accountSettlementRevoked;

  /// 账户模块:撤销结清状态失败 toast
  ///
  /// In zh, this message translates to:
  /// **'撤销结清状态失败：{reason}'**
  String accountRevokeSettlementFailure(String reason);

  /// 账户模块:合并项目成员异常 toast
  ///
  /// In zh, this message translates to:
  /// **'合并项目成员异常，请刷新后重试。'**
  String get accountMergedMemberInvalid;

  /// 账户模块:合并项目成功 toast
  ///
  /// In zh, this message translates to:
  /// **'已合并'**
  String get accountMergeSuccess;

  /// 账户模块:分享项目按钮 tooltip
  ///
  /// In zh, this message translates to:
  /// **'分享项目'**
  String get accountShareProjectTooltip;

  /// 账户模块:分享项目输入为空错误
  ///
  /// In zh, this message translates to:
  /// **'请输入分享人姓名或包名'**
  String get accountShareNameRequired;

  /// 账户模块:分享项目弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'分享项目'**
  String get accountShareProjectTitle;

  /// 账户模块:分享项目分享人输入框标签
  ///
  /// In zh, this message translates to:
  /// **'分享人姓名（自己）'**
  String get accountShareNameLabel;

  /// 账户模块:分享项目分享人输入框占位
  ///
  /// In zh, this message translates to:
  /// **'例如：老王、张三等'**
  String get accountShareNameHint;

  /// 账户模块:分享项目弹窗说明
  ///
  /// In zh, this message translates to:
  /// **'对方导入后，会在“外协项目”中看到这个名称。'**
  String get accountShareNameHelp;

  /// 账户模块:生成分享包按钮
  ///
  /// In zh, this message translates to:
  /// **'生成分享包'**
  String get accountGenerateSharePackageAction;

  /// 账户模块:结清弹窗项目已结清错误
  ///
  /// In zh, this message translates to:
  /// **'项目已结清，不能重复结清'**
  String get accountSettlementAlreadySettled;

  /// 账户模块:结清弹窗输入不合法错误
  ///
  /// In zh, this message translates to:
  /// **'输入不合法'**
  String get accountInputInvalid;

  /// 账户模块:结清弹窗通用保存失败错误
  ///
  /// In zh, this message translates to:
  /// **'保存失败，请稍后重试'**
  String get accountSaveFailureGeneric;

  /// 账户模块:结清弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'结清项目'**
  String get accountSettlementDialogTitle;

  /// 账户模块:结清弹窗核销金额标签
  ///
  /// In zh, this message translates to:
  /// **'核销金额'**
  String get accountWriteOffAmountLabel;

  /// 账户模块:结清弹窗核销原因输入框标签
  ///
  /// In zh, this message translates to:
  /// **'核销/减免原因（可填）'**
  String get accountWriteOffReasonLabel;

  /// 账户模块:结清弹窗说明
  ///
  /// In zh, this message translates to:
  /// **'确认后，这笔待收将作为核销处理，不再计入待收，也不会算作实收。'**
  String get accountSettlementHelper;

  /// 账户模块:结清弹窗确认按钮
  ///
  /// In zh, this message translates to:
  /// **'确认结清'**
  String get accountConfirmSettlementAction;

  /// 账户模块:批量改单价弹窗设备数量
  ///
  /// In zh, this message translates to:
  /// **'设备数：{count} 台'**
  String accountDeviceCountLine(int count);

  /// 账户模块:批量改单价弹窗挖斗单价输入框标签
  ///
  /// In zh, this message translates to:
  /// **'挖斗统一单价（整数）'**
  String get accountDiggingBatchRateLabel;

  /// 账户模块:批量改单价弹窗破碎单价输入框标签
  ///
  /// In zh, this message translates to:
  /// **'破碎统一单价（整数）'**
  String get accountBreakingBatchRateLabel;

  /// 账户模块:批量改单价弹窗说明
  ///
  /// In zh, this message translates to:
  /// **'保存后：该项目下所有设备会分别按“挖斗/破碎”模式更新项目单价（仅影响本项目）。'**
  String get accountBatchRateHelper;

  /// 账户模块:单台改单价输入框标签
  ///
  /// In zh, this message translates to:
  /// **'单价'**
  String get accountSingleRateLabel;

  /// 账户模块:单台改单价弹窗说明
  ///
  /// In zh, this message translates to:
  /// **'提示：该单价会保存为本项目的项目单价，仅影响本项目。'**
  String get accountSingleRateHelper;

  /// 账户模块:批量改单价弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'批量修改单价：{project}'**
  String accountBatchRateTitle(String project);

  /// 账户模块:编辑破碎单价弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'编辑破碎单价：{project}'**
  String accountBreakingRateTitle(String project);

  /// 账户模块:编辑单价弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'编辑单价：{project}'**
  String accountSingleRateTitle(String project);

  /// 账户模块:单价更新成功 toast
  ///
  /// In zh, this message translates to:
  /// **'已更新'**
  String get accountUpdated;

  /// 账户模块:项目筛选 sheet 标题
  ///
  /// In zh, this message translates to:
  /// **'筛选项目'**
  String get accountFilterSheetTitle;

  /// 账户模块:项目筛选关键词输入框标签
  ///
  /// In zh, this message translates to:
  /// **'关键词（联系人 / 工地）'**
  String get accountFilterKeywordLabel;

  /// 账户模块:项目筛选关键词输入框占位
  ///
  /// In zh, this message translates to:
  /// **'例如：王涛 / 修文 / 地铁站'**
  String get accountFilterKeywordHint;

  /// 账户模块:项目筛选清空按钮
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get accountClearAction;

  /// 账户模块:新增收款弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'新增收款'**
  String get accountPaymentCreateTitle;

  /// 账户模块:编辑收款弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'编辑收款'**
  String get accountPaymentEditTitle;

  /// 账户模块:收款弹窗项目名称行
  ///
  /// In zh, this message translates to:
  /// **'项目：{project}'**
  String accountProjectLine(String project);

  /// 账户模块:收款弹窗金额输入框标签
  ///
  /// In zh, this message translates to:
  /// **'金额（整数）'**
  String get accountPaymentAmountIntegerLabel;

  /// 账户模块:收款弹窗备注输入框标签
  ///
  /// In zh, this message translates to:
  /// **'备注（可填）'**
  String get accountNoteOptionalLabel;

  /// 账户模块:收款弹窗应收已收提示
  ///
  /// In zh, this message translates to:
  /// **'应收：{receivable}，已收：{received}'**
  String accountPaymentReceivableReceivedLine(
    String receivable,
    String received,
  );

  /// 账户模块:项目合并失败提示
  ///
  /// In zh, this message translates to:
  /// **'合并失败：{reason}'**
  String accountMergeFailureWithReason(String reason);

  /// 账户模块:项目合并 sheet 标题
  ///
  /// In zh, this message translates to:
  /// **'合并项目'**
  String get accountMergeSheetTitle;

  /// 账户模块:项目合并提交中按钮
  ///
  /// In zh, this message translates to:
  /// **'合并中'**
  String get accountMergingAction;

  /// 账户模块:项目合并无可合并项目提示
  ///
  /// In zh, this message translates to:
  /// **'暂无可合并项目'**
  String get accountNoMergeableProjects;

  /// 账户模块:项目合并未合并分组标题
  ///
  /// In zh, this message translates to:
  /// **'未合并'**
  String get accountUnmergedSection;

  /// 账户模块:项目合并已合并分组标题
  ///
  /// In zh, this message translates to:
  /// **'已合并'**
  String get accountMergedSection;

  /// 账户模块:解除合并确认弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'解除合并？'**
  String get accountDissolveConfirmTitle;

  /// 账户模块:解除合并确认弹窗正文开头
  ///
  /// In zh, this message translates to:
  /// **'解除后将恢复为普通项目：'**
  String get accountDissolveIntro;

  /// 账户模块:解除合并确认弹窗说明
  ///
  /// In zh, this message translates to:
  /// **'原始计时记录不会删除。\n设备、工时、单价不会改变。'**
  String get accountDissolveHelp;

  /// 账户模块:解除合并提交中按钮
  ///
  /// In zh, this message translates to:
  /// **'解除中'**
  String get accountDissolvingAction;

  /// 账户模块:解除合并失败提示
  ///
  /// In zh, this message translates to:
  /// **'解除合并失败：{reason}'**
  String accountDissolveFailureWithReason(String reason);

  /// 设备模块:通用取消按钮
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get deviceCancelAction;

  /// 设备模块:通用确定按钮
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get deviceConfirmAction;

  /// 设备模块:通用知晓按钮
  ///
  /// In zh, this message translates to:
  /// **'我知道了'**
  String get deviceDoneAction;

  /// 设备模块:设备页标题
  ///
  /// In zh, this message translates to:
  /// **'设备'**
  String get devicePageTitle;

  /// 设备模块:设备页搜索提示
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get deviceSearchHint;

  /// 设备模块:账号同步分组标题
  ///
  /// In zh, this message translates to:
  /// **'账号与同步'**
  String get deviceAccountSyncSectionTitle;

  /// 设备模块:账户中心标题
  ///
  /// In zh, this message translates to:
  /// **'账户中心'**
  String get deviceAccountCenterTitle;

  /// 设备模块:个人资料分组标题
  ///
  /// In zh, this message translates to:
  /// **'个人资料'**
  String get deviceProfileSectionTitle;

  /// 设备模块:升级入口标题
  ///
  /// In zh, this message translates to:
  /// **'立即升级'**
  String get deviceUpgradeNowTitle;

  /// 设备模块:设备分组标题
  ///
  /// In zh, this message translates to:
  /// **'设备'**
  String get deviceEquipmentSectionTitle;

  /// 设备模块:添加设备入口
  ///
  /// In zh, this message translates to:
  /// **'添加设备'**
  String get deviceAddDeviceAction;

  /// 设备模块:评分分组标题
  ///
  /// In zh, this message translates to:
  /// **'给我们评分'**
  String get deviceRateUsSectionTitle;

  /// 设备模块:评分入口
  ///
  /// In zh, this message translates to:
  /// **'给app评分'**
  String get deviceRateAppAction;

  /// 设备模块:条款分组标题
  ///
  /// In zh, this message translates to:
  /// **'条款'**
  String get deviceTermsSectionTitle;

  /// 设备模块:使用条款标题
  ///
  /// In zh, this message translates to:
  /// **'使用条款'**
  String get deviceTermsTitle;

  /// 设备模块:隐私政策标题
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get devicePrivacyTitle;

  /// 设备模块:支持反馈分组标题
  ///
  /// In zh, this message translates to:
  /// **'支持与反馈'**
  String get deviceSupportSectionTitle;

  /// 设备模块:联系开发者入口
  ///
  /// In zh, this message translates to:
  /// **'联系开发者'**
  String get deviceContactDeveloperAction;

  /// 设备模块:设备管理分组标题
  ///
  /// In zh, this message translates to:
  /// **'管理设备(长按图标删除)'**
  String get deviceManagementTitle;

  /// 设备模块:挖掘机类别
  ///
  /// In zh, this message translates to:
  /// **'挖掘机'**
  String get deviceEquipmentExcavator;

  /// 设备模块:装载机类别
  ///
  /// In zh, this message translates to:
  /// **'装载机'**
  String get deviceEquipmentLoader;

  /// 设备模块:新增设备弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'新增设备'**
  String get deviceEditorCreateTitle;

  /// 设备模块:编辑设备弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'编辑设备'**
  String get deviceEditorEditTitle;

  /// 设备模块:未选择品牌提示
  ///
  /// In zh, this message translates to:
  /// **'未选择品牌（头像）'**
  String get deviceBrandNotSelected;

  /// 设备模块:设备编辑品牌行
  ///
  /// In zh, this message translates to:
  /// **'品牌：{equipmentType}  {brand}{preview}'**
  String deviceBrandSelectedLine(
    String equipmentType,
    String brand,
    String preview,
  );

  /// 设备模块:选择按钮
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get deviceSelectAction;

  /// 设备模块:品牌默认头像状态
  ///
  /// In zh, this message translates to:
  /// **'头像：品牌默认'**
  String get deviceAvatarBrandDefault;

  /// 设备模块:自定义头像状态
  ///
  /// In zh, this message translates to:
  /// **'头像：已设置自定义'**
  String get deviceAvatarCustomSet;

  /// 设备模块:从相册选择头像按钮
  ///
  /// In zh, this message translates to:
  /// **'相册'**
  String get deviceGalleryAction;

  /// 设备模块:恢复默认头像按钮
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get deviceDefaultAction;

  /// 设备模块:设备编辑基准码表字段
  ///
  /// In zh, this message translates to:
  /// **'基准码表（>=0，必填）'**
  String get deviceBaseMeterLabel;

  /// 设备模块:设备编辑默认单价字段
  ///
  /// In zh, this message translates to:
  /// **'默认单价（>0，必填）'**
  String get deviceDefaultRateLabel;

  /// 设备模块:设备编辑破碎单价字段
  ///
  /// In zh, this message translates to:
  /// **'破碎单价（选填）'**
  String get deviceBreakingRateOptionalLabel;

  /// 设备模块:设备编辑破碎单价提示
  ///
  /// In zh, this message translates to:
  /// **'不填写默认该设备没有破碎'**
  String get deviceBreakingRateHint;

  /// 设备模块:设备编辑型号字段
  ///
  /// In zh, this message translates to:
  /// **'型号（选填）'**
  String get deviceModelOptionalLabel;

  /// 设备模块:自定义头像升级提示标题
  ///
  /// In zh, this message translates to:
  /// **'需要升级'**
  String get deviceCustomAvatarProTitle;

  /// 设备模块:自定义头像升级提示正文
  ///
  /// In zh, this message translates to:
  /// **'自定义设备头像是 Pro 功能，升级后可为设备设置专属头像。'**
  String get deviceCustomAvatarProMessage;

  /// 设备模块:头像从相册更换成功提示
  ///
  /// In zh, this message translates to:
  /// **'已从相册更换头像'**
  String get deviceAvatarGalleryChanged;

  /// 设备模块:头像保存失败提示
  ///
  /// In zh, this message translates to:
  /// **'头像保存失败：{error}'**
  String deviceAvatarSaveFailure(String error);

  /// 设备模块:设备头像选择页标题
  ///
  /// In zh, this message translates to:
  /// **'选择设备头像'**
  String get deviceAvatarSelectTitle;

  /// 设备模块:设备头像选择空状态
  ///
  /// In zh, this message translates to:
  /// **'该类别暂无品牌，先选另一类或新增自定义头像'**
  String get deviceAvatarEmpty;

  /// 设备模块:品牌国家中国
  ///
  /// In zh, this message translates to:
  /// **'中国'**
  String get deviceBrandCountryChina;

  /// 设备模块:品牌国家日本
  ///
  /// In zh, this message translates to:
  /// **'日本'**
  String get deviceBrandCountryJapan;

  /// 设备模块:品牌国家美国
  ///
  /// In zh, this message translates to:
  /// **'美国'**
  String get deviceBrandCountryUs;

  /// 设备模块:品牌国家韩国
  ///
  /// In zh, this message translates to:
  /// **'韩国'**
  String get deviceBrandCountryKorea;

  /// 设备模块:类型+品牌选择页标题
  ///
  /// In zh, this message translates to:
  /// **'选择设备类型与品牌'**
  String get deviceTypeSelectTitle;

  /// 设备模块:常用类型-更多入口
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get deviceTypeMoreChip;

  /// 设备模块:类型选择弹层标题
  ///
  /// In zh, this message translates to:
  /// **'选择设备类型'**
  String get deviceTypeSheetTitle;

  /// 设备模块:类型弹层搜索占位
  ///
  /// In zh, this message translates to:
  /// **'搜索设备类型'**
  String get deviceTypeSearchHint;

  /// 设备模块:类型弹层搜索无结果
  ///
  /// In zh, this message translates to:
  /// **'未找到相关设备类型'**
  String get deviceTypeSheetEmpty;

  /// 设备模块:类型未上线角标
  ///
  /// In zh, this message translates to:
  /// **'敬请期待'**
  String get deviceTypeComingSoonBadge;

  /// 设备模块:未上线类型底部按钮文案
  ///
  /// In zh, this message translates to:
  /// **'{type} 创建流程即将上线'**
  String deviceTypeComingSoonCta(String type);

  /// 设备模块:底部主按钮-下一步创建
  ///
  /// In zh, this message translates to:
  /// **'下一步：创建{type}设备'**
  String deviceCreateNextCta(String type);

  /// 设备模块:品牌区标题
  ///
  /// In zh, this message translates to:
  /// **'选择品牌头像'**
  String get deviceBrandSectionTitle;

  /// 设备模块:品牌搜索占位
  ///
  /// In zh, this message translates to:
  /// **'搜索品牌 / 输入自定义品牌'**
  String get deviceBrandSearchHint;

  /// 设备模块:品牌搜索无结果
  ///
  /// In zh, this message translates to:
  /// **'未找到相关品牌'**
  String get deviceBrandSearchEmptyTitle;

  /// 设备模块:该类型无品牌库空态
  ///
  /// In zh, this message translates to:
  /// **'暂未收录{type}品牌，可使用自定义品牌'**
  String deviceBrandEmptyForType(String type);

  /// 设备模块:使用自定义品牌按钮
  ///
  /// In zh, this message translates to:
  /// **'使用自定义品牌'**
  String get deviceBrandUseCustom;

  /// 设备模块:切换类型清空品牌提示
  ///
  /// In zh, this message translates to:
  /// **'已切换为{type}，品牌已重置'**
  String deviceBrandResetNotice(String type);

  /// 设备模块:自定义品牌弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'自定义品牌'**
  String get deviceBrandCustomDialogTitle;

  /// 设备模块:自定义品牌输入占位
  ///
  /// In zh, this message translates to:
  /// **'输入品牌名称'**
  String get deviceBrandCustomDialogHint;

  /// 设备模块:自定义品牌确定按钮
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get deviceBrandCustomConfirm;

  /// 设备模块:大类-工程机械
  ///
  /// In zh, this message translates to:
  /// **'工程机械'**
  String get deviceCategoryConstruction;

  /// 设备模块:大类-农业设备
  ///
  /// In zh, this message translates to:
  /// **'农业设备'**
  String get deviceCategoryAgriculture;

  /// 设备模块:大类-无人设备
  ///
  /// In zh, this message translates to:
  /// **'无人设备'**
  String get deviceCategoryUnmanned;

  /// 设备模块:大类-智能设备
  ///
  /// In zh, this message translates to:
  /// **'智能设备'**
  String get deviceCategorySmart;

  /// 设备模块:大类-其他
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get deviceCategoryOther;

  /// 设备模块:类型描述-挖掘机
  ///
  /// In zh, this message translates to:
  /// **'土方 / 矿山 / 施工'**
  String get deviceTypeExcavatorDesc;

  /// 设备模块:类型描述-装载机
  ///
  /// In zh, this message translates to:
  /// **'装载 / 转运 / 施工'**
  String get deviceTypeLoaderDesc;

  /// 设备模块:类型名-压路机
  ///
  /// In zh, this message translates to:
  /// **'压路机'**
  String get deviceTypeRollerName;

  /// 设备模块:类型描述-压路机
  ///
  /// In zh, this message translates to:
  /// **'道路 / 压实 / 施工'**
  String get deviceTypeRollerDesc;

  /// 设备模块:类型名-装卸车
  ///
  /// In zh, this message translates to:
  /// **'装卸车'**
  String get deviceTypeHandlingVehicleName;

  /// 设备模块:类型描述-装卸车
  ///
  /// In zh, this message translates to:
  /// **'装卸 / 转运 / 搬运'**
  String get deviceTypeHandlingVehicleDesc;

  /// 设备模块:类型名-吊车
  ///
  /// In zh, this message translates to:
  /// **'吊车'**
  String get deviceTypeCraneName;

  /// 设备模块:类型描述-吊车
  ///
  /// In zh, this message translates to:
  /// **'吊装 / 起重 / 吊运'**
  String get deviceTypeCraneDesc;

  /// 设备模块:类型名-叉车
  ///
  /// In zh, this message translates to:
  /// **'叉车'**
  String get deviceTypeForkliftName;

  /// 设备模块:类型描述-叉车
  ///
  /// In zh, this message translates to:
  /// **'叉取 / 仓储 / 堆垛'**
  String get deviceTypeForkliftDesc;

  /// 设备模块:类型名-农机
  ///
  /// In zh, this message translates to:
  /// **'农机'**
  String get deviceTypeAgriMachineName;

  /// 设备模块:类型描述-农机
  ///
  /// In zh, this message translates to:
  /// **'农田 / 作业 / 农业生产'**
  String get deviceTypeAgriMachineDesc;

  /// 设备模块:类型名-无人机
  ///
  /// In zh, this message translates to:
  /// **'无人机'**
  String get deviceTypeDroneName;

  /// 设备模块:类型描述-无人机
  ///
  /// In zh, this message translates to:
  /// **'巡检 / 植保 / 测绘'**
  String get deviceTypeDroneDesc;

  /// 设备模块:类型名-机器人
  ///
  /// In zh, this message translates to:
  /// **'机器人'**
  String get deviceTypeRobotName;

  /// 设备模块:类型描述-机器人
  ///
  /// In zh, this message translates to:
  /// **'巡检 / 作业 / 交互'**
  String get deviceTypeRobotDesc;

  /// 设备模块:类型名-自定义设备
  ///
  /// In zh, this message translates to:
  /// **'自定义设备'**
  String get deviceTypeCustomName;

  /// 设备模块:类型描述-自定义设备
  ///
  /// In zh, this message translates to:
  /// **'其他类型 / 自定义'**
  String get deviceTypeCustomDesc;

  /// 设备模块:设备选择器标签
  ///
  /// In zh, this message translates to:
  /// **'设备编号'**
  String get devicePickerLabel;

  /// 设备模块:设备选择器空状态提示
  ///
  /// In zh, this message translates to:
  /// **'暂无在用设备，请先去“设备”页新增'**
  String get devicePickerEmptyHint;

  /// 设备模块:设备选择器在用设备条目及当前码表
  ///
  /// In zh, this message translates to:
  /// **'{name}（码表 {meter} h）'**
  String devicePickerItemWithMeter(String name, String meter);

  /// 设备模块:设备选择器未知设备兜底
  ///
  /// In zh, this message translates to:
  /// **'未知设备'**
  String get devicePickerUnknownDevice;

  /// 设备模块:设备选择器已停用设备条目及当前码表
  ///
  /// In zh, this message translates to:
  /// **'{name}（已停用 · 码表 {meter} h）'**
  String devicePickerInactiveItemWithMeter(String name, String meter);

  /// 设备模块:设备选择器未知已停用设备兜底
  ///
  /// In zh, this message translates to:
  /// **'未知设备（已停用）'**
  String get devicePickerUnknownInactive;

  /// 设备模块:停用设备确认标题
  ///
  /// In zh, this message translates to:
  /// **'确认停用设备？'**
  String get deviceDeactivateTitle;

  /// 设备模块:停用设备确认正文
  ///
  /// In zh, this message translates to:
  /// **'设备：{name}\n\n只会停用设备，不会删除任何计时/油电/收入历史记录。\n停用后：\n• 设备页默认不再显示\n• 计时页下拉框不可再选\n• 历史记录仍可回显（通过 deviceId 区分新旧设备）'**
  String deviceDeactivateContent(String name);

  /// 设备模块:停用按钮
  ///
  /// In zh, this message translates to:
  /// **'停用'**
  String get deviceDeactivateAction;

  /// 设备模块:保存动作名,用于 store feedback
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get deviceSaveAction;

  /// 设备模块:读取动作名,用于 store feedback
  ///
  /// In zh, this message translates to:
  /// **'读取'**
  String get deviceReadAction;

  /// 设备模块:新增设备成功 toast
  ///
  /// In zh, this message translates to:
  /// **'已新增设备'**
  String get deviceSaveCreated;

  /// 设备模块:更新设备成功 toast
  ///
  /// In zh, this message translates to:
  /// **'已更新设备'**
  String get deviceSaveUpdated;

  /// 设备模块:停用设备成功 toast
  ///
  /// In zh, this message translates to:
  /// **'已停用（历史记录不受影响）'**
  String get deviceDeactivateSuccess;

  /// 设备模块:保存生命周期金额失败的兜底 toast
  ///
  /// In zh, this message translates to:
  /// **'保存失败：数据未保存，请稍后重试'**
  String get deviceSaveFailureDataNotSaved;

  /// 设备模块:生命周期回本卡片未设置成本时的提示
  ///
  /// In zh, this message translates to:
  /// **'点击设置成本与残值'**
  String get deviceLifecycleSetCostAction;

  /// 设备模块:生命周期回本卡片净收益公式说明
  ///
  /// In zh, this message translates to:
  /// **'生命周期净收益 = 已实收 + 预计残值 - 初始成本'**
  String get deviceLifecycleNetProfitFormula;

  /// 设备模块:生命周期回本未设置成本时的状态文案
  ///
  /// In zh, this message translates to:
  /// **'未设置成本'**
  String get deviceLifecyclePaybackNoCostStatus;

  /// 设备模块:生命周期回本未设置成本时的结果文案
  ///
  /// In zh, this message translates to:
  /// **'设置后可查看回本进度与预计盈余'**
  String get deviceLifecyclePaybackNoCostResult;

  /// 设备模块:生命周期已回本且回本倍数≥2时的状态文案
  ///
  /// In zh, this message translates to:
  /// **'已回本 {multiplier}x'**
  String deviceLifecyclePaybackPaidBackMultiplier(String multiplier);

  /// 设备模块:生命周期恰好回本(100%)时的状态文案
  ///
  /// In zh, this message translates to:
  /// **'已回本 100%'**
  String get deviceLifecyclePaybackPaidBackFull;

  /// 设备模块:生命周期已回本且不足2倍时的百分比状态文案
  ///
  /// In zh, this message translates to:
  /// **'已回本 {percent}%'**
  String deviceLifecyclePaybackPaidBackPercent(String percent);

  /// 设备模块:生命周期尚未回本时的百分比进度状态文案
  ///
  /// In zh, this message translates to:
  /// **'回本 {percent}%'**
  String deviceLifecyclePaybackPercentInProgress(String percent);

  /// 设备模块:生命周期已回本且有盈余时的结果文案
  ///
  /// In zh, this message translates to:
  /// **'预计盈余 {amount}'**
  String deviceLifecyclePaybackProfit(String amount);

  /// 设备模块:生命周期恰好回本暂无盈余时的结果文案
  ///
  /// In zh, this message translates to:
  /// **'已回本，暂无盈余'**
  String get deviceLifecyclePaybackBreakeven;

  /// 设备模块:生命周期尚未回本时的差额结果文案
  ///
  /// In zh, this message translates to:
  /// **'还差 {amount} 回本'**
  String deviceLifecyclePaybackShortfall(String amount);

  /// 设备模块:生命周期回本卡片无障碍初始投入摘要
  ///
  /// In zh, this message translates to:
  /// **'初始投入{amount}'**
  String deviceLifecycleInitialInvestmentSemantics(String amount);

  /// 设备模块:生命周期回本卡片无障碍初始投入未设置值
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get deviceLifecycleInitialInvestmentUnsetValue;

  /// 设备模块:生命周期回本卡片无障碍已实收净额摘要
  ///
  /// In zh, this message translates to:
  /// **'已实收净额{amount}'**
  String deviceLifecycleNetReceivedSemantics(String amount);

  /// 设备模块:生命周期回本卡片无障碍预计售出残值摘要
  ///
  /// In zh, this message translates to:
  /// **'预计售出残值{amount}'**
  String deviceLifecycleEstimatedResidualSemantics(String amount);

  /// 设备模块:生命周期回本卡片无障碍待收摘要
  ///
  /// In zh, this message translates to:
  /// **'待收{amount}'**
  String deviceLifecyclePendingReceivableSemantics(String amount);

  /// 设备模块:生命周期回本卡片运营摘要
  ///
  /// In zh, this message translates to:
  /// **'已运营：{hours}小时 / {count}项'**
  String deviceLifecycleOperationSummary(String hours, int count);

  /// 设备模块:生命周期回本卡片未设置初始投入
  ///
  /// In zh, this message translates to:
  /// **'未设置初始投入'**
  String get deviceLifecycleInitialInvestmentUnset;

  /// 设备模块:生命周期回本卡片初始投入金额
  ///
  /// In zh, this message translates to:
  /// **'初始投入 {amount}'**
  String deviceLifecycleInitialInvestmentAmount(String amount);

  /// 设备模块:生命周期回本卡片盈余图例
  ///
  /// In zh, this message translates to:
  /// **'盈余'**
  String get deviceLifecycleSurplusLabel;

  /// 设备模块:生命周期回本卡片未回本缺口图例
  ///
  /// In zh, this message translates to:
  /// **'未回本缺口'**
  String get deviceLifecyclePaybackGapLabel;

  /// 设备模块:生命周期回本进度条实收补本额图例
  ///
  /// In zh, this message translates to:
  /// **'实收补本额'**
  String get deviceLifecycleReceivedPrincipalLabel;

  /// 设备模块:生命周期回本卡片已实收净额标签
  ///
  /// In zh, this message translates to:
  /// **'已实收净额'**
  String get deviceLifecycleNetReceivedLabel;

  /// 设备模块:生命周期回本卡片预计售出残值标签
  ///
  /// In zh, this message translates to:
  /// **'预计售出残值'**
  String get deviceLifecycleEstimatedResidualLabel;

  /// 设备模块:生命周期回本卡片待收标签
  ///
  /// In zh, this message translates to:
  /// **'待收 {amount}'**
  String deviceLifecyclePendingReceivableLabel(String amount);

  /// 设备模块:生命周期金额设置 sheet 标题
  ///
  /// In zh, this message translates to:
  /// **'设置设备生命周期金额'**
  String get deviceLifecycleAmountSheetTitle;

  /// 设备模块:生命周期金额设置 sheet 更新按钮
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get deviceLifecycleAmountUpdateAction;

  /// 设备模块:生命周期金额设置 sheet 初始投入成本字段
  ///
  /// In zh, this message translates to:
  /// **'初始投入成本'**
  String get deviceLifecycleInitialCostLabel;

  /// 设备模块:生命周期金额设置 sheet 预计售出残值字段
  ///
  /// In zh, this message translates to:
  /// **'预计售出残值'**
  String get deviceLifecycleEstimatedResidualInputLabel;

  /// 设备模块:生命周期金额设置 sheet 预计盈余标题
  ///
  /// In zh, this message translates to:
  /// **'预计盈余'**
  String get deviceLifecycleProjectedSurplusTitle;

  /// 设备模块:生命周期金额设置 sheet 未回本标题
  ///
  /// In zh, this message translates to:
  /// **'还差回本'**
  String get deviceLifecyclePaybackRemainingTitle;

  /// 设备模块:生命周期金额设置 sheet 公式预计售出残值行
  ///
  /// In zh, this message translates to:
  /// **'+ 预计售出残值'**
  String get deviceLifecycleEstimatedResidualFormulaLabel;

  /// 设备模块:生命周期金额设置 sheet 公式初始投入成本行
  ///
  /// In zh, this message translates to:
  /// **'- 初始投入成本'**
  String get deviceLifecycleInitialCostFormulaLabel;

  /// 设备模块:生命周期金额设置 sheet 公式生命周期净收益行
  ///
  /// In zh, this message translates to:
  /// **'= 生命周期净收益'**
  String get deviceLifecycleNetProfitFormulaLabel;

  /// 设备模块:账户中心账号状态分组
  ///
  /// In zh, this message translates to:
  /// **'账号状态'**
  String get deviceAccountStatusSectionTitle;

  /// 设备模块:设备页账户中心未登录副标题
  ///
  /// In zh, this message translates to:
  /// **'未登录 · 登录后可备份与同步'**
  String get deviceAccountCenterLoggedOutSubtitle;

  /// 设备模块:设备页账户中心已登录副标题
  ///
  /// In zh, this message translates to:
  /// **'已登录 · {entitlement}'**
  String deviceAccountCenterLoggedInSubtitle(String entitlement);

  /// 设备模块:设备页账户中心带手机号尾号副标题
  ///
  /// In zh, this message translates to:
  /// **'已登录 · 尾号 {tail} · {entitlement}'**
  String deviceAccountCenterLoggedInTailSubtitle(
    String tail,
    String entitlement,
  );

  /// 设备模块:账户中心已登录标题
  ///
  /// In zh, this message translates to:
  /// **'已登录'**
  String get deviceAccountLoggedInTitle;

  /// 设备模块:账户中心未登录标题
  ///
  /// In zh, this message translates to:
  /// **'未登录'**
  String get deviceAccountLoggedOutTitle;

  /// 设备模块:账户中心未登录状态说明
  ///
  /// In zh, this message translates to:
  /// **'登录后可备份、恢复与同步数据'**
  String get deviceAccountAuthLoggedOutSubtitle;

  /// 设备模块:账户中心带手机号尾号状态说明
  ///
  /// In zh, this message translates to:
  /// **'尾号 {tail} · {entitlement}'**
  String deviceAccountAuthTailSubtitle(String tail, String entitlement);

  /// 设备模块:Pro 权益状态
  ///
  /// In zh, this message translates to:
  /// **'Pro 已开通'**
  String get deviceEntitlementPro;

  /// 设备模块:免费版权益状态
  ///
  /// In zh, this message translates to:
  /// **'免费版'**
  String get deviceEntitlementFree;

  /// 设备模块:权益有效期说明
  ///
  /// In zh, this message translates to:
  /// **'{entitlement} · 有效至 {date}'**
  String deviceEntitlementExpires(String entitlement, String date);

  /// 设备模块:手机号登录入口
  ///
  /// In zh, this message translates to:
  /// **'手机号登录'**
  String get devicePhoneLoginAction;

  /// 设备模块:手机号登录说明
  ///
  /// In zh, this message translates to:
  /// **'登录后可使用云端备份与购买权益同步'**
  String get devicePhoneLoginSubtitle;

  /// 设备模块:购买权益分组
  ///
  /// In zh, this message translates to:
  /// **'购买权益'**
  String get devicePurchaseSectionTitle;

  /// 设备模块:升级 Pro 入口
  ///
  /// In zh, this message translates to:
  /// **'升级 Pro，支持持续维护'**
  String get deviceUpgradeProTitle;

  /// 设备模块:恢复购买入口
  ///
  /// In zh, this message translates to:
  /// **'恢复购买'**
  String get deviceRestorePurchasesAction;

  /// 设备模块:恢复购买说明
  ///
  /// In zh, this message translates to:
  /// **'从 App Store 恢复已购买权益'**
  String get deviceRestorePurchasesSubtitle;

  /// 设备模块:恢复购买结果-Pro 已恢复
  ///
  /// In zh, this message translates to:
  /// **'已恢复 Pro 订阅'**
  String get deviceRestoreResultRestoredPro;

  /// 设备模块:恢复购买结果-Max 已恢复
  ///
  /// In zh, this message translates to:
  /// **'已恢复 Max 订阅'**
  String get deviceRestoreResultRestoredMax;

  /// 设备模块:恢复购买结果-无可恢复购买
  ///
  /// In zh, this message translates to:
  /// **'未发现可恢复的购买'**
  String get deviceRestoreResultNoPurchase;

  /// 设备模块:恢复购买失败结果
  ///
  /// In zh, this message translates to:
  /// **'恢复失败：{reason}'**
  String deviceRestoreResultFailed(String reason);

  /// 设备模块:恢复购买服务不可用结果
  ///
  /// In zh, this message translates to:
  /// **'订阅服务暂不可用：{reason}'**
  String deviceRestoreResultUnavailable(String reason);

  /// 设备模块:数据安全分组
  ///
  /// In zh, this message translates to:
  /// **'数据安全'**
  String get deviceDataSecuritySectionTitle;

  /// 设备模块:云端备份标题
  ///
  /// In zh, this message translates to:
  /// **'云端备份'**
  String get deviceCloudBackupTitle;

  /// 设备模块:已登录云端备份说明
  ///
  /// In zh, this message translates to:
  /// **'上传当前数据或从云端恢复'**
  String get deviceCloudBackupAuthedSubtitle;

  /// 设备模块:未登录云端备份说明
  ///
  /// In zh, this message translates to:
  /// **'登录后可保存与恢复云端备份'**
  String get deviceCloudBackupLoginSubtitle;

  /// 设备模块:免费版云端备份说明
  ///
  /// In zh, this message translates to:
  /// **'Pro 订阅可用，升级后可保存与恢复云端备份'**
  String get deviceCloudBackupProSubtitle;

  /// 设备模块:云端备份升级提示标题
  ///
  /// In zh, this message translates to:
  /// **'需要升级 Pro'**
  String get deviceCloudBackupProTitle;

  /// 设备模块:云端备份升级提示正文
  ///
  /// In zh, this message translates to:
  /// **'云端备份是 Pro 功能，升级后可上传当前数据并从云端恢复。'**
  String get deviceCloudBackupProMessage;

  /// 设备模块:云端备份命中 Pro 门禁时的失败文案(controller 返回 cloud_backup_requires_pro,view 映射)
  ///
  /// In zh, this message translates to:
  /// **'云端备份是 Pro 功能，请升级后再使用。'**
  String get deviceCloudBackupRequiresPro;

  /// 设备模块:云端备份服务未配置时的兜底文案(controller 返回 cloud_backup_not_configured 且无 server 文案,view 映射)
  ///
  /// In zh, this message translates to:
  /// **'云端备份服务暂未配置'**
  String get deviceCloudBackupNotConfigured;

  /// 设备模块:手动本地备份标题
  ///
  /// In zh, this message translates to:
  /// **'手动本地备份'**
  String get deviceManualBackupTitle;

  /// 设备模块:手动本地备份说明
  ///
  /// In zh, this message translates to:
  /// **'导出当前数据，便于保存与迁移'**
  String get deviceManualBackupSubtitle;

  /// 设备模块:本地恢复标题
  ///
  /// In zh, this message translates to:
  /// **'本地恢复'**
  String get deviceLocalRestoreTitle;

  /// 设备模块:本地恢复说明
  ///
  /// In zh, this message translates to:
  /// **'从备份文件恢复本机数据'**
  String get deviceLocalRestoreSubtitle;

  /// 设备模块:多端同步说明标题
  ///
  /// In zh, this message translates to:
  /// **'多端同步说明'**
  String get deviceSyncInfoTitle;

  /// 设备模块:多端同步说明副标题
  ///
  /// In zh, this message translates to:
  /// **'当前版本暂不支持自动多端同步'**
  String get deviceSyncInfoSubtitle;

  /// 设备模块:多端同步说明正文
  ///
  /// In zh, this message translates to:
  /// **'云端备份未来用于保存数据与换机恢复；多端同步是多台设备之间的实时数据同步，当前版本暂不支持自动多端同步。'**
  String get deviceSyncInfoMessage;

  /// 设备模块:云端备份未配置标题
  ///
  /// In zh, this message translates to:
  /// **'云端备份服务暂未配置'**
  String get deviceCloudBackupUnavailableTitle;

  /// 设备模块:需要登录提示标题
  ///
  /// In zh, this message translates to:
  /// **'需要登录'**
  String get deviceLoginRequiredTitle;

  /// 设备模块:云端备份需要登录说明
  ///
  /// In zh, this message translates to:
  /// **'请先完成手机号登录，再使用云端备份。'**
  String get deviceCloudBackupLoginRequiredMessage;

  /// 设备模块:云端备份操作选择说明
  ///
  /// In zh, this message translates to:
  /// **'你可以上传当前本机数据，也可以从云端备份恢复到本机。云端恢复会完整替换当前本机业务数据。'**
  String get deviceCloudBackupChooseMessage;

  /// 设备模块:从云端恢复按钮
  ///
  /// In zh, this message translates to:
  /// **'从云端恢复'**
  String get deviceCloudRestoreAction;

  /// 设备模块:上传当前数据按钮
  ///
  /// In zh, this message translates to:
  /// **'上传当前数据'**
  String get deviceCloudUploadAction;

  /// 设备模块:云端备份失败标题
  ///
  /// In zh, this message translates to:
  /// **'云端备份失败'**
  String get deviceCloudBackupFailureTitle;

  /// 设备模块:云端备份上传失败默认说明
  ///
  /// In zh, this message translates to:
  /// **'云端备份上传失败，请稍后重试。'**
  String get deviceCloudBackupUploadFailureMessage;

  /// 设备模块:云端备份上传成功标题
  ///
  /// In zh, this message translates to:
  /// **'云端备份已上传'**
  String get deviceCloudBackupUploadedTitle;

  /// 设备模块:云端备份上传成功正文
  ///
  /// In zh, this message translates to:
  /// **'当前数据已保存到云端。\n备份 ID：{backupId}\n大小：{size}'**
  String deviceCloudBackupUploadedMessage(String backupId, String size);

  /// 设备模块:读取云端备份失败标题
  ///
  /// In zh, this message translates to:
  /// **'无法读取云端备份'**
  String get deviceCloudBackupReadFailureTitle;

  /// 设备模块:读取云端备份失败默认说明
  ///
  /// In zh, this message translates to:
  /// **'云端备份列表读取失败，请稍后重试。'**
  String get deviceCloudBackupReadFailureMessage;

  /// 设备模块:无云端备份标题
  ///
  /// In zh, this message translates to:
  /// **'暂无云端备份'**
  String get deviceCloudBackupEmptyTitle;

  /// 设备模块:无云端备份说明
  ///
  /// In zh, this message translates to:
  /// **'当前账号下还没有可恢复的云端备份。'**
  String get deviceCloudBackupEmptyMessage;

  /// 设备模块:选择云端备份弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'选择云端备份'**
  String get deviceCloudBackupSelectTitle;

  /// 设备模块:确认从云端恢复标题
  ///
  /// In zh, this message translates to:
  /// **'确认从云端恢复？'**
  String get deviceCloudRestoreConfirmTitle;

  /// 设备模块:确认从云端恢复正文
  ///
  /// In zh, this message translates to:
  /// **'将恢复 {backupTime} 的云端备份。恢复后，当前本机业务数据会被这份云端备份替换；恢复前 App 会先自动导出当前数据备份。'**
  String deviceCloudRestoreConfirmMessage(String backupTime);

  /// 设备模块:确认恢复按钮
  ///
  /// In zh, this message translates to:
  /// **'确认恢复'**
  String get deviceRestoreConfirmAction;

  /// 设备模块:本地备份失败标题
  ///
  /// In zh, this message translates to:
  /// **'本地备份失败'**
  String get deviceLocalBackupFailureTitle;

  /// 设备模块:本地备份失败默认说明
  ///
  /// In zh, this message translates to:
  /// **'备份失败，请稍后重试。'**
  String get deviceLocalBackupFailureMessage;

  /// 设备模块:本地备份生成标题
  ///
  /// In zh, this message translates to:
  /// **'本地备份已生成'**
  String get deviceLocalBackupGeneratedTitle;

  /// 设备模块:本地备份路径异常说明
  ///
  /// In zh, this message translates to:
  /// **'备份文件已生成，但文件路径异常。你仍可稍后从本地备份列表中选择该文件。'**
  String get deviceLocalBackupPathInvalidMessage;

  /// 设备模块:仅本地备份成功说明
  ///
  /// In zh, this message translates to:
  /// **'备份已生成，可在本地恢复时选择这份备份。'**
  String get deviceLocalBackupOnlySuccessMessage;

  /// 设备模块:备份并分享成功说明
  ///
  /// In zh, this message translates to:
  /// **'备份文件已生成，请确认已保存到安全位置。'**
  String get deviceLocalBackupSharedSuccessMessage;

  /// 设备模块:备份分享面板不可用说明
  ///
  /// In zh, this message translates to:
  /// **'备份文件已生成，但无法打开分享面板。你仍可在本地备份列表中找到它。'**
  String get deviceLocalBackupShareUnavailableMessage;

  /// 设备模块:手动本地备份弹窗说明
  ///
  /// In zh, this message translates to:
  /// **'导出一份当前数据备份文件。你可以仅保存在本机，也可以立即分享或保存到其他位置。'**
  String get deviceManualBackupDialogMessage;

  /// 设备模块:仅备份按钮
  ///
  /// In zh, this message translates to:
  /// **'仅备份'**
  String get deviceBackupOnlyAction;

  /// 设备模块:备份并分享按钮
  ///
  /// In zh, this message translates to:
  /// **'备份并分享'**
  String get deviceBackupAndShareAction;

  /// 设备模块:取消选择备份提示
  ///
  /// In zh, this message translates to:
  /// **'已取消选择'**
  String get deviceBackupSelectionCancelled;

  /// 设备模块:无法预览备份标题
  ///
  /// In zh, this message translates to:
  /// **'无法预览备份文件'**
  String get deviceBackupPreviewUnavailableTitle;

  /// 设备模块:无效备份文件默认说明
  ///
  /// In zh, this message translates to:
  /// **'这不是有效的 FleetLedger 备份文件'**
  String get deviceInvalidBackupFileMessage;

  /// 设备模块:备份格式不完整说明
  ///
  /// In zh, this message translates to:
  /// **'备份文件格式不完整'**
  String get deviceBackupIncompleteMessage;

  /// 设备模块:选择备份文件标题
  ///
  /// In zh, this message translates to:
  /// **'选择备份文件'**
  String get deviceBackupSelectFileTitle;

  /// 设备模块:选择备份文件说明
  ///
  /// In zh, this message translates to:
  /// **'请选择由 FleetLedger 导出的备份文件。通常建议选择最近一次手动备份；恢复前备份用于撤回最近几次恢复操作前的数据。'**
  String get deviceBackupSelectFileMessage;

  /// 设备模块:无可识别备份文件提示
  ///
  /// In zh, this message translates to:
  /// **'暂无可识别的本地备份文件，可点击“从文件选择”选择其他位置的 JSON 备份。'**
  String get deviceBackupNoRecognizedFiles;

  /// 设备模块:手动备份分组标题
  ///
  /// In zh, this message translates to:
  /// **'手动备份'**
  String get deviceBackupManualSection;

  /// 设备模块:恢复前备份分组标题
  ///
  /// In zh, this message translates to:
  /// **'恢复前备份（防误操）'**
  String get deviceBackupPreRestoreSection;

  /// 设备模块:旧版备份分组标题
  ///
  /// In zh, this message translates to:
  /// **'旧版备份'**
  String get deviceBackupLegacySection;

  /// 设备模块:从文件选择备份按钮
  ///
  /// In zh, this message translates to:
  /// **'从文件选择'**
  String get deviceBackupFromFileAction;

  /// 设备模块:未知值
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get deviceUnknownValue;

  /// 设备模块:备份预览标题
  ///
  /// In zh, this message translates to:
  /// **'备份文件预览'**
  String get deviceBackupPreviewTitle;

  /// 设备模块:备份预览说明
  ///
  /// In zh, this message translates to:
  /// **'这是一个 FleetLedger 本地备份文件。'**
  String get deviceBackupPreviewIntro;

  /// 设备模块:备份时间标签
  ///
  /// In zh, this message translates to:
  /// **'备份时间'**
  String get deviceBackupTimeLabel;

  /// 设备模块:数据库版本标签
  ///
  /// In zh, this message translates to:
  /// **'数据库版本'**
  String get deviceBackupSchemaVersionLabel;

  /// 设备模块:备份包含数据标题
  ///
  /// In zh, this message translates to:
  /// **'包含数据：'**
  String get deviceBackupIncludedDataLabel;

  /// 设备模块:备份设备数量标签
  ///
  /// In zh, this message translates to:
  /// **'设备'**
  String get deviceBackupDeviceCountLabel;

  /// 设备模块:备份计时记录数量标签
  ///
  /// In zh, this message translates to:
  /// **'计时记录'**
  String get deviceBackupTimingRecordCountLabel;

  /// 设备模块:备份油电记录数量标签
  ///
  /// In zh, this message translates to:
  /// **'油电记录'**
  String get deviceBackupFuelRecordCountLabel;

  /// 设备模块:备份维修记录数量标签
  ///
  /// In zh, this message translates to:
  /// **'维修记录'**
  String get deviceBackupMaintenanceRecordCountLabel;

  /// 设备模块:备份收款记录数量标签
  ///
  /// In zh, this message translates to:
  /// **'收款记录'**
  String get deviceBackupIncomeRecordCountLabel;

  /// 设备模块:备份项目设置数量标签
  ///
  /// In zh, this message translates to:
  /// **'项目相关设置'**
  String get deviceBackupProjectSettingsCountLabel;

  /// 设备模块:通用条数
  ///
  /// In zh, this message translates to:
  /// **'{count} 条'**
  String deviceCountWithUnit(int count);

  /// 设备模块:设备台数
  ///
  /// In zh, this message translates to:
  /// **'{count} 台'**
  String deviceMachineCountWithUnit(int count);

  /// 设备模块:备份恢复警告
  ///
  /// In zh, this message translates to:
  /// **'恢复后，当前本机的业务数据会被这份备份替换。'**
  String get deviceBackupRestoreWarning;

  /// 设备模块:恢复进行中提示
  ///
  /// In zh, this message translates to:
  /// **'正在恢复，请勿关闭 App...'**
  String get deviceRestoringMessage;

  /// 设备模块:确认本地恢复标题
  ///
  /// In zh, this message translates to:
  /// **'确认恢复备份？'**
  String get deviceLocalRestoreConfirmTitle;

  /// 设备模块:确认本地恢复正文
  ///
  /// In zh, this message translates to:
  /// **'恢复后，当前本机的设备、计时、油电、维修、收款和项目相关设置等业务数据将被所选备份替换。恢复前，App 会先自动导出一份当前数据备份，便于必要时找回。当前版本仅支持完整覆盖恢复，不支持合并恢复。'**
  String get deviceLocalRestoreConfirmMessage;

  /// 设备模块:恢复成功标题
  ///
  /// In zh, this message translates to:
  /// **'恢复完成'**
  String get deviceRestoreSuccessTitle;

  /// 设备模块:恢复成功正文
  ///
  /// In zh, this message translates to:
  /// **'已恢复以下业务数据：\n设备：{devices}\n计时记录：{timingRecords}\n油电记录：{fuelRecords}\n维修记录：{maintenanceRecords}\n收款记录：{accountPayments}\n项目相关设置：{projectSettings}\n\n恢复前已自动备份当前数据。'**
  String deviceRestoreSuccessMessage(
    int devices,
    int timingRecords,
    int fuelRecords,
    int maintenanceRecords,
    int accountPayments,
    int projectSettings,
  );

  /// 设备模块:恢复失败标题
  ///
  /// In zh, this message translates to:
  /// **'恢复失败'**
  String get deviceRestoreFailureTitle;

  /// 设备模块:恢复失败时自动备份成功补充说明
  ///
  /// In zh, this message translates to:
  /// **'\n\n恢复前已成功自动备份当前数据。'**
  String get deviceRestoreAutoBackupNote;

  /// 设备模块:手动备份文件类型标题
  ///
  /// In zh, this message translates to:
  /// **'FleetLedger 手动备份'**
  String get deviceBackupManualKindTitle;

  /// 设备模块:恢复前备份文件类型标题
  ///
  /// In zh, this message translates to:
  /// **'恢复前备份'**
  String get deviceBackupPreRestoreKindTitle;

  /// 设备模块:旧版备份文件类型标题
  ///
  /// In zh, this message translates to:
  /// **'旧版备份'**
  String get deviceBackupLegacyKindTitle;

  /// 设备模块:未知备份文件类型标题
  ///
  /// In zh, this message translates to:
  /// **'FleetLedger 备份'**
  String get deviceBackupUnknownKindTitle;

  /// 设备模块:设备经营分组标题
  ///
  /// In zh, this message translates to:
  /// **'设备经营'**
  String get deviceLedgerSectionTitle;

  /// 设备模块:设备停用后替代原编号显示的短标签
  ///
  /// In zh, this message translates to:
  /// **'已停用'**
  String get deviceInactiveIndexLabel;

  /// 设备模块:小时单位
  ///
  /// In zh, this message translates to:
  /// **'小时'**
  String get deviceUnitHour;

  /// 设备模块:台班单位
  ///
  /// In zh, this message translates to:
  /// **'台班'**
  String get deviceUnitShift;

  /// 设备模块:天单位
  ///
  /// In zh, this message translates to:
  /// **'天'**
  String get deviceUnitDay;

  /// 设备模块:租期单位
  ///
  /// In zh, this message translates to:
  /// **'租期'**
  String get deviceUnitRent;

  /// 设备模块:亩单位
  ///
  /// In zh, this message translates to:
  /// **'亩'**
  String get deviceUnitMu;

  /// 设备模块:英亩单位
  ///
  /// In zh, this message translates to:
  /// **'英亩'**
  String get deviceUnitAcre;

  /// 设备模块:公顷单位
  ///
  /// In zh, this message translates to:
  /// **'公顷'**
  String get deviceUnitHectare;

  /// 设备模块:吨单位
  ///
  /// In zh, this message translates to:
  /// **'吨'**
  String get deviceUnitTon;

  /// 设备模块:方单位
  ///
  /// In zh, this message translates to:
  /// **'方'**
  String get deviceUnitCubicMeter;

  /// 设备模块:趟单位
  ///
  /// In zh, this message translates to:
  /// **'趟'**
  String get deviceUnitTrip;

  /// 设备模块:架次单位
  ///
  /// In zh, this message translates to:
  /// **'架次'**
  String get deviceUnitSortie;

  /// 设备模块:任务单位
  ///
  /// In zh, this message translates to:
  /// **'任务'**
  String get deviceUnitTask;

  /// 设备模块:Pro 订阅兜底标题
  ///
  /// In zh, this message translates to:
  /// **'机账通 Pro 年订阅'**
  String get deviceUpgradeProFallbackTitle;

  /// 设备模块:Max 订阅兜底标题
  ///
  /// In zh, this message translates to:
  /// **'机账通 Max 年订阅'**
  String get deviceUpgradeMaxFallbackTitle;

  /// 设备模块:年度订阅周期
  ///
  /// In zh, this message translates to:
  /// **'1 年 / 1 year'**
  String get deviceUpgradePeriodYear;

  /// 设备模块:年度订阅单位
  ///
  /// In zh, this message translates to:
  /// **'年'**
  String get deviceUpgradeUnitYear;

  /// 设备模块:Pro 计划说明
  ///
  /// In zh, this message translates to:
  /// **'解锁基础 Pro 功能，订阅有效期内可用。'**
  String get deviceUpgradeProBody;

  /// 设备模块:Max 计划说明
  ///
  /// In zh, this message translates to:
  /// **'更高等级权益，包含 Pro 能力，并为后续高级能力预留。'**
  String get deviceUpgradeMaxBody;

  /// 设备模块:等待订阅商品信息
  ///
  /// In zh, this message translates to:
  /// **'等待 App Store 商品信息 / Loading from App Store'**
  String get deviceUpgradeLoadingProduct;

  /// 设备模块:单位价格待加载
  ///
  /// In zh, this message translates to:
  /// **'商品信息加载后显示 / Available after product details load'**
  String get deviceUpgradeUnitPricePending;

  /// 设备模块:订阅购买服务不可用
  ///
  /// In zh, this message translates to:
  /// **'订阅购买服务暂不可用，请稍后重试'**
  String get deviceUpgradePurchaseUnavailable;

  /// 设备模块:订阅商品加载中
  ///
  /// In zh, this message translates to:
  /// **'正在加载 App Store 订阅商品...'**
  String get deviceUpgradeLoadingProducts;

  /// 设备模块:订阅商品不可用
  ///
  /// In zh, this message translates to:
  /// **'订阅商品暂不可用，请稍后重试'**
  String get deviceUpgradeProductsUnavailable;

  /// 设备模块:等待交易结果
  ///
  /// In zh, this message translates to:
  /// **'正在等待 App Store 交易结果...'**
  String get deviceUpgradeTransactionPending;

  /// 设备模块:Max 权益已解锁
  ///
  /// In zh, this message translates to:
  /// **'订阅已生效，Max 权益已解锁'**
  String get deviceUpgradeMaxUnlocked;

  /// 设备模块:Pro 权益已解锁
  ///
  /// In zh, this message translates to:
  /// **'订阅已生效，Pro 权益已解锁'**
  String get deviceUpgradeProUnlocked;

  /// 设备模块:升级按钮加载中
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get deviceUpgradeButtonLoading;

  /// 设备模块:升级按钮不可购买
  ///
  /// In zh, this message translates to:
  /// **'暂不可购买'**
  String get deviceUpgradeButtonUnavailable;

  /// 设备模块:升级按钮处理中
  ///
  /// In zh, this message translates to:
  /// **'处理中...'**
  String get deviceUpgradeButtonProcessing;

  /// 设备模块:升级按钮已订阅
  ///
  /// In zh, this message translates to:
  /// **'已订阅'**
  String get deviceUpgradeButtonSubscribed;

  /// 设备模块:升级到 Max 按钮
  ///
  /// In zh, this message translates to:
  /// **'升级到 Max'**
  String get deviceUpgradeButtonUpgradeMax;

  /// 设备模块:继续购买按钮
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get deviceUpgradeButtonContinue;

  /// 设备模块:升级权益文案
  ///
  /// In zh, this message translates to:
  /// **'多留一份清楚的电子账'**
  String get deviceUpgradeBenefitClearLedger;

  /// 设备模块:升级自动续期说明
  ///
  /// In zh, this message translates to:
  /// **'Pro 与 Max 均为年度自动续期订阅'**
  String get deviceUpgradeBenefitAutoRenewal;

  /// 设备模块:Max 计划包含 Pro 标签
  ///
  /// In zh, this message translates to:
  /// **'包含 Pro'**
  String get deviceUpgradeBadgeIncludesPro;

  /// 设备模块:订阅信息标题
  ///
  /// In zh, this message translates to:
  /// **'订阅信息 / Subscription details'**
  String get deviceUpgradeSubscriptionDetailsTitle;

  /// 设备模块:订阅名称标签
  ///
  /// In zh, this message translates to:
  /// **'订阅名称'**
  String get deviceUpgradeSubscriptionNameLabel;

  /// 设备模块:订阅周期标签
  ///
  /// In zh, this message translates to:
  /// **'订阅周期'**
  String get deviceUpgradeSubscriptionPeriodLabel;

  /// 设备模块:订阅价格标签
  ///
  /// In zh, this message translates to:
  /// **'订阅价格'**
  String get deviceUpgradeSubscriptionPriceLabel;

  /// 设备模块:订阅单位价格标签
  ///
  /// In zh, this message translates to:
  /// **'单位价格'**
  String get deviceUpgradeUnitPriceLabel;

  /// 设备模块:订阅商品未加载说明
  ///
  /// In zh, this message translates to:
  /// **'商品信息未完整加载前无法购买，请等待 App Store 返回订阅信息。'**
  String get deviceUpgradeProductNotLoadedMessage;

  /// 设备模块:订阅解锁高级功能说明
  ///
  /// In zh, this message translates to:
  /// **'订阅后可解锁 Pro 功能，并在订阅有效期内持续使用已开放的高级功能。\nSubscription unlocks premium features while your subscription is active.'**
  String get deviceUpgradeUnlocksPremiumMessage;

  /// 设备模块:订阅自动续期说明
  ///
  /// In zh, this message translates to:
  /// **'订阅会自动续期，除非你在当前周期结束前至少 24 小时关闭自动续期。你可以在 Apple ID 的订阅设置中管理或取消订阅。\nSubscriptions renew automatically unless auto-renewal is turned off at least 24 hours before the end of the current period. You can manage or cancel your subscription in your Apple ID subscription settings.'**
  String get deviceUpgradeAutoRenewMessage;

  /// 设备模块:购买前阅读法律条款说明
  ///
  /// In zh, this message translates to:
  /// **'购买前请阅读《隐私政策》和《使用条款》。\nPlease review the Privacy Policy and Terms of Use before purchasing.'**
  String get deviceUpgradeReviewLegalMessage;

  /// 设备模块:升级页隐私政策链接
  ///
  /// In zh, this message translates to:
  /// **'隐私政策 Privacy Policy'**
  String get deviceUpgradePrivacyLinkLabel;

  /// 设备模块:升级页使用条款链接
  ///
  /// In zh, this message translates to:
  /// **'使用条款 Terms of Use'**
  String get deviceUpgradeTermsLinkLabel;

  /// 设备模块:隐私政策生效日期
  ///
  /// In zh, this message translates to:
  /// **'生效日期：2026 年 6 月 9 日'**
  String get devicePrivacyEffectiveDate;

  /// 设备模块:隐私政策第1节标题
  ///
  /// In zh, this message translates to:
  /// **'1. 适用范围'**
  String get devicePrivacySection1Title;

  /// 设备模块:隐私政策第1节正文
  ///
  /// In zh, this message translates to:
  /// **'欢迎使用 FleetLedger。\nFleetLedger 是一款面向工程机械经营场景的记录与管理工具，帮助用户管理设备工时、油电消耗、项目收支、维保明细及设备信息。\n\n本隐私政策用于说明：在当前版本下，FleetLedger 如何处理与你使用本应用相关的信息。\n\n本政策适用于 FleetLedger 当前提供的应用版本及相关支持页面。'**
  String get devicePrivacySection1Body;

  /// 设备模块:隐私政策第2节标题
  ///
  /// In zh, this message translates to:
  /// **'2. 当前版本涉及的本地数据类型'**
  String get devicePrivacySection2Title;

  /// 设备模块:隐私政策第2节正文
  ///
  /// In zh, this message translates to:
  /// **'在当前版本中，应用涉及的数据主要包括：\n• 你主动录入的设备信息、工时记录、油电记录、项目收支、维保明细等业务数据；\n• 你在手机号登录页主动输入的手机号，以及你对隐私政策和使用条款的确认状态；\n• 你主动选择并设置的头像或图片文件；\n• 应用在本机运行过程中，为实现本地存储、页面展示、筛选查询、统计展示与功能判断所需的必要本地信息。\n\n上述业务数据在当前版本中主要存储在你的设备本地。为实现手机号验证码登录，你输入的手机号、验证码校验请求、登录状态及必要的服务端响应信息会发送至开发者配置的账号接口，并由阿里云号码认证服务提供短信验证码发送与校验能力。如你主动使用云端备份，应用会将当前账本备份上传至开发者配置的云端备份服务，用于后续备份列表展示和换机恢复。当前版本未接入广告 SDK、行为分析 SDK、第三方追踪服务或自动多端同步服务。'**
  String get devicePrivacySection2Body;

  /// 设备模块:隐私政策第3节标题
  ///
  /// In zh, this message translates to:
  /// **'3. 数据来源与用途说明'**
  String get devicePrivacySection3Title;

  /// 设备模块:隐私政策第3节正文
  ///
  /// In zh, this message translates to:
  /// **'当前版本中的相关数据主要来源于：\n• 你的主动输入；\n• 你的主动上传或主动选择；\n• 你在使用相关功能时在设备本地形成的数据。\n\n这些数据主要用于在你的设备上实现 FleetLedger 的核心功能，包括但不限于：\n• 保存和展示设备经营记录；\n• 生成统计结果与页面展示内容；\n• 支持筛选、查询、汇总、头像显示等功能；\n• 在必要情况下协助进行本地问题排查与功能判断。\n\n除手机号验证码登录、你主动使用云端备份或恢复、你主动通过系统能力发起评分、邮件联系或打开外部链接等行为外，开发者当前不会通过本应用主动接收你在应用内录入的业务数据。'**
  String get devicePrivacySection3Body;

  /// 设备模块:隐私政策第4节标题
  ///
  /// In zh, this message translates to:
  /// **'4. 权限使用说明'**
  String get devicePrivacySection4Title;

  /// 设备模块:隐私政策第4节正文
  ///
  /// In zh, this message translates to:
  /// **'为实现相关功能，FleetLedger 可能在你主动操作时请求系统权限。'**
  String get devicePrivacySection4Body;

  /// 设备模块:隐私政策第5节标题
  ///
  /// In zh, this message translates to:
  /// **'4.1 图片或相册相关权限'**
  String get devicePrivacySection5Title;

  /// 设备模块:隐私政策第5节正文
  ///
  /// In zh, this message translates to:
  /// **'当你主动为设备设置头像、选择图片或更新相关展示内容时，应用可能请求访问图片或相册的权限。该权限仅用于完成你主动发起的操作，不会在未经你同意的情况下自动读取你的图片内容。'**
  String get devicePrivacySection5Body;

  /// 设备模块:隐私政策第6节标题
  ///
  /// In zh, this message translates to:
  /// **'4.2 外部链接与系统能力'**
  String get devicePrivacySection6Title;

  /// 设备模块:隐私政策第6节正文
  ///
  /// In zh, this message translates to:
  /// **'当你主动点击“给 app 评分”“联系开发者”“隐私政策”“使用条款”“升级/订阅”或“恢复购买”等入口时，应用可能调用系统提供的浏览器、邮件、应用商店或其他系统能力，以完成对应操作。此类行为属于你主动发起的系统跳转。'**
  String get devicePrivacySection6Body;

  /// 设备模块:隐私政策第7节标题
  ///
  /// In zh, this message translates to:
  /// **'5. 信息共享、上传与第三方服务'**
  String get devicePrivacySection7Title;

  /// 设备模块:隐私政策第7节正文
  ///
  /// In zh, this message translates to:
  /// **'当前版本下，你输入的业务记录主要存储在本地设备中；手机号验证码登录所需的手机号、验证码校验请求、登录状态及必要的服务端响应信息会发送至开发者配置的账号接口，并由阿里云号码认证服务处理短信验证码发送与校验。你主动使用云端备份时，应用会将当前账本备份上传至开发者配置的云端备份服务；你主动从云端恢复时，应用会下载你账号下选择的备份。\n\n开发者不会将这些记录出售、出租或主动共享给广告网络、数据经纪商或其他无关第三方。\n\n当前版本未接入以下类型的第三方服务：\n• 广告投放服务；\n• 行为分析服务；\n• 第三方追踪服务；\n• 自动多端同步服务。\n\n当前版本已接入的短信验证码服务仅用于手机号登录验证，不用于广告投放、行为分析或第三方追踪。\n\n如你主动使用应用商店评分、系统邮件联系、升级、订阅或恢复购买等系统能力，相关流程将由 Apple App Store、设备系统或对应平台按照其自身规则处理。若生产版本启用订阅服务端校验，应用可能向开发者配置的校验服务发送确认订阅状态所需的交易校验信息。开发者当前不直接收集你的银行卡号、支付账号密码等支付凭证信息。'**
  String get devicePrivacySection7Body;

  /// 设备模块:隐私政策第8节标题
  ///
  /// In zh, this message translates to:
  /// **'6. 数据存储与安全'**
  String get devicePrivacySection8Title;

  /// 设备模块:隐私政策第8节正文
  ///
  /// In zh, this message translates to:
  /// **'当前版本中的主要业务数据保存在你的设备本地。你主动上传的云端备份会保存在账号对应的云端备份空间，用于备份列表展示和恢复。手机号验证码登录所需的登录凭证会保存在本机，用于维持登录状态。我们会在应用能力范围内采取合理措施，尽量降低数据被意外丢失、误操作或未经授权访问的风险。\n\n但请你理解，任何本地设备、操作系统环境或存储介质都无法保证绝对安全。建议你妥善保管自己的设备，并谨慎处理重要业务数据。'**
  String get devicePrivacySection8Body;

  /// 设备模块:隐私政策第9节标题
  ///
  /// In zh, this message translates to:
  /// **'7. 数据保留与删除'**
  String get devicePrivacySection9Title;

  /// 设备模块:隐私政策第9节正文
  ///
  /// In zh, this message translates to:
  /// **'在当前版本中，相关业务数据通常会保留在你的本地设备中，直至出现以下情况之一：\n• 你主动删除相关记录；\n• 你主动清除应用数据；\n• 你卸载应用；\n• 因设备系统、存储环境或其他异常导致本地数据变化或丢失。\n\n如果你没有主动上传云端备份，开发者通常无法为你恢复仅保存在本地设备中的账本数据。'**
  String get devicePrivacySection9Body;

  /// 设备模块:隐私政策第10节标题
  ///
  /// In zh, this message translates to:
  /// **'8. 儿童与未成年人保护'**
  String get devicePrivacySection10Title;

  /// 设备模块:隐私政策第10节正文
  ///
  /// In zh, this message translates to:
  /// **'FleetLedger 主要面向工程机械经营记录与管理场景，不以儿童为目标用户。如你是未成年人，建议在监护人指导下阅读并使用本应用。'**
  String get devicePrivacySection10Body;

  /// 设备模块:隐私政策第11节标题
  ///
  /// In zh, this message translates to:
  /// **'9. 未来功能更新说明'**
  String get devicePrivacySection11Title;

  /// 设备模块:隐私政策第11节正文
  ///
  /// In zh, this message translates to:
  /// **'当前版本中，手机号验证码登录和用户主动发起的云端备份/恢复会按本政策说明处理相关信息。\n\n如未来版本引入以下能力，包括但不限于：\n• 自动多端同步；\n• 行为分析工具；\n• 第三方服务接入；\n• 错误日志收集；\n• 其他涉及数据上传、处理或共享的新功能，\n\n我们会根据届时的实际功能与数据流程，及时更新本隐私政策，并同步更新 App Store 隐私披露信息。'**
  String get devicePrivacySection11Body;

  /// 设备模块:隐私政策第12节标题
  ///
  /// In zh, this message translates to:
  /// **'10. 隐私政策的更新'**
  String get devicePrivacySection12Title;

  /// 设备模块:隐私政策第12节正文
  ///
  /// In zh, this message translates to:
  /// **'我们可能会根据产品功能迭代、法律法规要求或服务变化，对本政策进行更新。更新后的版本会通过应用内相关页面、支持页面或其他合理方式进行发布。\n\n如无特别说明，更新后的政策自发布之日起生效。'**
  String get devicePrivacySection12Body;

  /// 设备模块:隐私政策第13节标题
  ///
  /// In zh, this message translates to:
  /// **'11. 联系我们'**
  String get devicePrivacySection13Title;

  /// 设备模块:隐私政策第13节正文
  ///
  /// In zh, this message translates to:
  /// **'如果你对本隐私政策有疑问，或希望就隐私相关问题与我们联系，可以通过以下方式联系开发者：\n\n电子邮箱：582748196@qq.com'**
  String get devicePrivacySection13Body;

  /// 设备模块:使用条款生效日期
  ///
  /// In zh, this message translates to:
  /// **'生效日期：2026-03-17'**
  String get deviceTermsEffectiveDate;

  /// 设备模块:使用条款第1节标题
  ///
  /// In zh, this message translates to:
  /// **'1. 适用范围与接受'**
  String get deviceTermsSection1Title;

  /// 设备模块:使用条款第1节正文
  ///
  /// In zh, this message translates to:
  /// **'本使用条款适用于“FleetLedger”在 iOS 与 Android 平台提供的产品与服务。你在下载、安装、访问或继续使用本应用时，即表示你已阅读并同意受本条款约束。'**
  String get deviceTermsSection1Body;

  /// 设备模块:使用条款第2节标题
  ///
  /// In zh, this message translates to:
  /// **'2. 产品功能说明'**
  String get deviceTermsSection2Title;

  /// 设备模块:使用条款第2节正文
  ///
  /// In zh, this message translates to:
  /// **'本应用面向工程机械经营场景，主要用于设备信息、工时、油电、项目收支、维保明细等内容的记录与管理。应用展示结果仅作为经营辅助工具，不构成财务、税务、法律或其他专业意见。'**
  String get deviceTermsSection2Body;

  /// 设备模块:使用条款第3节标题
  ///
  /// In zh, this message translates to:
  /// **'3. 用户责任'**
  String get deviceTermsSection3Title;

  /// 设备模块:使用条款第3节正文
  ///
  /// In zh, this message translates to:
  /// **'你应确保录入、保存、导出或分享的信息真实、准确、完整，并保证你对相关数据拥有合法使用权。你不得利用本应用制作、存储或传播违法、侵权、欺诈、恶意或其他违反适用法律法规的内容。'**
  String get deviceTermsSection3Body;

  /// 设备模块:使用条款第4节标题
  ///
  /// In zh, this message translates to:
  /// **'4. 本地数据与备份'**
  String get deviceTermsSection4Title;

  /// 设备模块:使用条款第4节正文
  ///
  /// In zh, this message translates to:
  /// **'当前版本的设备信息、工时、油电、项目收支、维保明细等主要业务数据主要采用本地存储方式。手机号验证码登录会通过开发者配置的账号接口和短信验证码服务完成校验，用于识别登录状态。\n\n你理解并同意：因设备损坏、系统异常、误删除、权限变更、卸载应用或其他非开发者可控原因导致的本地业务数据丢失风险，应由你自行承担。建议你根据业务重要程度自行做好备份。'**
  String get deviceTermsSection4Body;

  /// 设备模块:使用条款第5节标题
  ///
  /// In zh, this message translates to:
  /// **'5. 权限、平台能力与付费功能'**
  String get deviceTermsSection5Title;

  /// 设备模块:使用条款第5节正文
  ///
  /// In zh, this message translates to:
  /// **'当你主动使用图片选择、评分入口、升级/订阅或恢复购买能力时，应用可能调用系统权限或 Apple App Store、Google Play 提供的平台能力。自动续期订阅的名称、周期、价格与权益以购买页和对应应用商店确认页展示为准；订阅会自动续期，除非你在当前周期结束前至少 24 小时关闭自动续期。你可以在 Apple ID 的订阅设置中管理或取消订阅，退款、取消与续费规则以对应应用商店规则为准，相关支付结算由对应平台处理。'**
  String get deviceTermsSection5Body;

  /// 设备模块:使用条款第6节标题
  ///
  /// In zh, this message translates to:
  /// **'6. 知识产权'**
  String get deviceTermsSection6Title;

  /// 设备模块:使用条款第6节正文
  ///
  /// In zh, this message translates to:
  /// **'本应用的软件代码、界面设计、文案结构与相关标识等内容，除法律另有规定或另有声明外，相关权利归开发者所有。未经许可，你不得对应用进行非法复制、反向工程、传播或商业化利用。'**
  String get deviceTermsSection6Body;

  /// 设备模块:使用条款第7节标题
  ///
  /// In zh, this message translates to:
  /// **'7. 免责声明与责任限制'**
  String get deviceTermsSection7Title;

  /// 设备模块:使用条款第7节正文
  ///
  /// In zh, this message translates to:
  /// **'本应用按“现状”和“现有可用”状态提供。我们会持续改进产品体验，但不保证应用始终无中断、无错误或完全满足你的特定业务需求。对于因你录入错误、未及时备份、设备故障、系统限制、第三方平台异常或不可抗力导致的损失，在适用法律允许范围内，开发者承担的责任以法律强制要求为限。'**
  String get deviceTermsSection7Body;

  /// 设备模块:使用条款第8节标题
  ///
  /// In zh, this message translates to:
  /// **'8. 条款更新与联系'**
  String get deviceTermsSection8Title;

  /// 设备模块:使用条款第8节正文
  ///
  /// In zh, this message translates to:
  /// **'我们可能根据产品迭代、平台政策或法律法规变化对本条款进行更新。更新版本发布后，如你继续使用本应用，视为接受更新后的条款。如有问题，可联系：582748196@qq.com。'**
  String get deviceTermsSection8Body;

  /// 同步冲突复核页标题
  ///
  /// In zh, this message translates to:
  /// **'同步冲突复核'**
  String get syncConflictReviewTitle;

  /// 同步冲突复核页空态
  ///
  /// In zh, this message translates to:
  /// **'暂无待复核冲突'**
  String get syncConflictReviewEmpty;

  /// 同步冲突复核页加载失败提示
  ///
  /// In zh, this message translates to:
  /// **'冲突列表加载失败，请稍后重试'**
  String get syncConflictReviewLoadFailure;

  /// 同步冲突复核页裁决失败提示
  ///
  /// In zh, this message translates to:
  /// **'裁决失败，请稍后重试'**
  String get syncConflictResolveFailure;

  /// 同步冲突复核页手动合并说明
  ///
  /// In zh, this message translates to:
  /// **'需要手动合并时，先保留本地，再到常规编辑页调整。'**
  String get syncConflictReviewManualHint;

  /// 同步冲突复核页单条冲突标题
  ///
  /// In zh, this message translates to:
  /// **'计时记录 {entityId}'**
  String syncConflictReviewEntityTitle(String entityId);

  /// 同步冲突复核页冲突原因
  ///
  /// In zh, this message translates to:
  /// **'原因：{reason}'**
  String syncConflictReviewReason(String reason);

  /// 同步冲突复核页本地摘要标签
  ///
  /// In zh, this message translates to:
  /// **'本地当前'**
  String get syncConflictReviewLocalLabel;

  /// 同步冲突复核页远端摘要标签
  ///
  /// In zh, this message translates to:
  /// **'远端来袭'**
  String get syncConflictReviewRemoteLabel;

  /// 同步冲突复核页使用远端按钮
  ///
  /// In zh, this message translates to:
  /// **'用远端'**
  String get syncConflictReviewUseRemote;

  /// 同步冲突复核页使用本地按钮
  ///
  /// In zh, this message translates to:
  /// **'用本地'**
  String get syncConflictReviewUseLocal;

  /// 同步冲突复核页本地记录缺失摘要
  ///
  /// In zh, this message translates to:
  /// **'本地记录已不存在'**
  String get syncConflictReviewMissingLocal;

  /// 同步冲突复核页远端记录缺失摘要
  ///
  /// In zh, this message translates to:
  /// **'远端记录无法解析'**
  String get syncConflictReviewMissingRemote;

  /// 同步冲突复核页删除墓碑摘要
  ///
  /// In zh, this message translates to:
  /// **'已删除记录'**
  String get syncConflictReviewDeletedSummary;

  /// 同步冲突复核页计时记录摘要
  ///
  /// In zh, this message translates to:
  /// **'设备 {deviceId} · {date} · {hours} h · ¥{amount}'**
  String syncConflictReviewTimingSummary(
    int deviceId,
    String date,
    String hours,
    String amount,
  );

  /// No description provided for @deviceRateEntryOpened.
  ///
  /// In zh, this message translates to:
  /// **'已打开评分入口'**
  String get deviceRateEntryOpened;

  /// No description provided for @deviceRateEntryUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'评分入口暂不可用'**
  String get deviceRateEntryUnavailable;

  /// No description provided for @deviceSupportSiteOpened.
  ///
  /// In zh, this message translates to:
  /// **'已打开技术支持网页'**
  String get deviceSupportSiteOpened;

  /// No description provided for @deviceSupportEmailFallback.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法打开支持页，已切换到邮件联系'**
  String get deviceSupportEmailFallback;

  /// No description provided for @deviceSupportUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法打开支持页，请稍后重试或发送邮件到 {email}'**
  String deviceSupportUnavailable(String email);

  /// No description provided for @deviceRestoreBlockIncompleteFormat.
  ///
  /// In zh, this message translates to:
  /// **'备份文件格式不完整，暂不能恢复。'**
  String get deviceRestoreBlockIncompleteFormat;

  /// No description provided for @deviceRestoreBlockOlderUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前版本暂不支持恢复旧版备份，请使用相同版本导出的备份。'**
  String get deviceRestoreBlockOlderUnsupported;

  /// No description provided for @deviceRestoreBlockNewerVersion.
  ///
  /// In zh, this message translates to:
  /// **'备份文件版本较新，请升级 App 后再试。'**
  String get deviceRestoreBlockNewerVersion;

  /// No description provided for @deviceCustomAvatarNotAllowed.
  ///
  /// In zh, this message translates to:
  /// **'当前方案不支持自定义头像'**
  String get deviceCustomAvatarNotAllowed;

  /// No description provided for @storeActionSaveSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get storeActionSaveSuccess;

  /// No description provided for @storeActionDeleteSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get storeActionDeleteSuccess;

  /// No description provided for @storeActionUpdateSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已更新'**
  String get storeActionUpdateSuccess;

  /// No description provided for @storeActionCreateSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已新增'**
  String get storeActionCreateSuccess;

  /// No description provided for @storeActionDeactivateSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已停用'**
  String get storeActionDeactivateSuccess;

  /// No description provided for @storeActionReadSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已读取'**
  String get storeActionReadSuccess;

  /// No description provided for @storeActionSaveLabel.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get storeActionSaveLabel;

  /// No description provided for @storeActionDeleteLabel.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get storeActionDeleteLabel;

  /// No description provided for @storeActionUpdateLabel.
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get storeActionUpdateLabel;

  /// No description provided for @storeActionCreateLabel.
  ///
  /// In zh, this message translates to:
  /// **'新增'**
  String get storeActionCreateLabel;

  /// No description provided for @storeActionDeactivateLabel.
  ///
  /// In zh, this message translates to:
  /// **'停用'**
  String get storeActionDeactivateLabel;

  /// No description provided for @storeActionReadLabel.
  ///
  /// In zh, this message translates to:
  /// **'读取'**
  String get storeActionReadLabel;

  /// No description provided for @storeActionFailureWithDetail.
  ///
  /// In zh, this message translates to:
  /// **'{action}失败：{detail}'**
  String storeActionFailureWithDetail(String action, String detail);

  /// No description provided for @storeActionFailureDatabase.
  ///
  /// In zh, this message translates to:
  /// **'{action}失败：数据未保存，请稍后重试'**
  String storeActionFailureDatabase(String action);

  /// No description provided for @storeActionFailureFileSystem.
  ///
  /// In zh, this message translates to:
  /// **'{action}失败：请检查文件状态和访问权限'**
  String storeActionFailureFileSystem(String action);
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
