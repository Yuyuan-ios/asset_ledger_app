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

  /// 油电模块:燃油页标题
  ///
  /// In zh, this message translates to:
  /// **'燃油'**
  String get fuelPageTitle;

  /// 油电模块:新增燃油记录底部录入 sheet 标题
  ///
  /// In zh, this message translates to:
  /// **'新增燃油'**
  String get fuelCreateSheetTitle;

  /// 油电模块:编辑燃油记录底部录入 sheet 标题
  ///
  /// In zh, this message translates to:
  /// **'编辑燃油'**
  String get fuelEditSheetTitle;

  /// 油电模块:燃油记录弹窗取消按钮
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get fuelCancelAction;

  /// 油电模块:燃油记录录入 sheet 确认按钮
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get fuelConfirmAction;

  /// 油电模块:删除燃油记录二次确认弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'确认删除？'**
  String get fuelDeleteConfirmTitle;

  /// 油电模块:删除燃油记录二次确认弹窗正文
  ///
  /// In zh, this message translates to:
  /// **'删除后不可恢复。'**
  String get fuelDeleteConfirmContent;

  /// 油电模块:删除燃油记录二次确认弹窗确认按钮
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get fuelDeleteConfirmAction;

  /// 油电模块:燃油效率卡片中设备已停用或不存在时的兜底设备名
  ///
  /// In zh, this message translates to:
  /// **'设备{id}（已停用/不存在）'**
  String fuelInactiveDeviceFallbackName(int id);

  /// 油电模块:燃油录入表单设备下拉字段标签
  ///
  /// In zh, this message translates to:
  /// **'设备编号'**
  String get fuelDeviceLabel;

  /// 油电模块:燃油录入表单设备下拉字段占位
  ///
  /// In zh, this message translates to:
  /// **'请选择设备'**
  String get fuelDeviceHint;

  /// 油电模块:燃油录入表单无在用设备时的设备下拉占位
  ///
  /// In zh, this message translates to:
  /// **'暂无在用设备，请先去“设备”页新增'**
  String get fuelNoActiveDeviceHint;

  /// 油电模块:燃油录入表单供应人字段标签
  ///
  /// In zh, this message translates to:
  /// **'供应人（必填）'**
  String get fuelSupplierRequiredLabel;

  /// 油电模块:燃油录入表单供应人字段占位
  ///
  /// In zh, this message translates to:
  /// **'例如：中石化 / 老王油品'**
  String get fuelSupplierHint;

  /// 油电模块:燃油录入表单加油量字段标签
  ///
  /// In zh, this message translates to:
  /// **'加油量（升）'**
  String get fuelLitersLabel;

  /// 油电模块:燃油录入表单加油量字段占位
  ///
  /// In zh, this message translates to:
  /// **'例如：120.0'**
  String get fuelLitersHint;

  /// 油电模块:燃油录入表单金额字段标签
  ///
  /// In zh, this message translates to:
  /// **'金额（元）'**
  String get fuelAmountYuanLabel;

  /// 油电模块:燃油录入表单金额字段占位
  ///
  /// In zh, this message translates to:
  /// **'例如：980.0'**
  String get fuelAmountHint;

  /// 油电模块:燃油效率统计卡片标题
  ///
  /// In zh, this message translates to:
  /// **'设备燃油效率'**
  String get fuelEfficiencyTitle;

  /// 油电模块:燃油效率统计卡片为空时的提示
  ///
  /// In zh, this message translates to:
  /// **'暂无数据（先录入燃油记录与工时记录）'**
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

  /// 账户模块:总览卡剩余标签
  ///
  /// In zh, this message translates to:
  /// **'剩余'**
  String get accountRemainingLabel;

  /// 账户模块:总览卡回款比例标签
  ///
  /// In zh, this message translates to:
  /// **'回款'**
  String get accountReceiptRatioLabel;

  /// 账户模块:总览卡净收款 tooltip
  ///
  /// In zh, this message translates to:
  /// **'已收款扣除燃油、维保和已支付外协项目款后的金额。'**
  String get accountNetReceivedTooltip;

  /// 账户模块:总览卡净收款标签
  ///
  /// In zh, this message translates to:
  /// **'已收(净)'**
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
  /// **'保存后：该项目下所有设备会分别按“挖斗/破碎”模式更新单价（仅影响本项目）。\n若等于设备默认对应模式单价，将自动清理覆盖记录（减少冗余）。'**
  String get accountBatchRateHelper;

  /// 账户模块:单台改单价输入框标签
  ///
  /// In zh, this message translates to:
  /// **'单价'**
  String get accountSingleRateLabel;

  /// 账户模块:单台改单价弹窗说明
  ///
  /// In zh, this message translates to:
  /// **'提示：若把单价改回设备默认单价，将自动清理覆盖记录（减少冗余）。'**
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
