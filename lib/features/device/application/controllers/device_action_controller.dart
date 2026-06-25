import '../../../../data/services/rate_app_service.dart';
import '../../../../data/services/support_feedback_service.dart';

/// 联系技术支持的结果 code（application 层枚举，避免 view 直依赖 data 层的
/// [SupportFeedbackOpenResult]）；用户可见文案由 view 层映射 AppLocalizations。
enum SupportEntryOutcome { siteOpened, emailFallback, unavailable }

/// application 层只返回结果 code；用户可见文案由 view 层映射 AppLocalizations
/// （见 device_page_actions），controller 不含展示中文。
class DeviceActionController {
  const DeviceActionController();

  /// true=已打开系统评分入口，false=评分入口暂不可用。
  Future<bool> openRateApp() {
    return RateAppService.openSystemRateEntry();
  }

  Future<SupportEntryOutcome> openSupportEntry() async {
    final result = await SupportFeedbackService.openSupportEntry();
    switch (result) {
      case SupportFeedbackOpenResult.supportSite:
        return SupportEntryOutcome.siteOpened;
      case SupportFeedbackOpenResult.email:
        return SupportEntryOutcome.emailFallback;
      case SupportFeedbackOpenResult.unavailable:
        return SupportEntryOutcome.unavailable;
    }
  }
}
