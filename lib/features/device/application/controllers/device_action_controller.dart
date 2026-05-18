import '../../../../core/config/support_feedback_config.dart';
import '../../../../data/services/rate_app_service.dart';
import '../../../../data/services/support_feedback_service.dart';

class DeviceActionController {
  const DeviceActionController();

  Future<String> openRateApp() async {
    final ok = await RateAppService.openSystemRateEntry();
    return ok ? '已打开评分入口' : '评分入口暂不可用';
  }

  Future<String> openSupportEntry() async {
    final result = await SupportFeedbackService.openSupportEntry();
    switch (result) {
      case SupportFeedbackOpenResult.supportSite:
        return '已打开技术支持网页';
      case SupportFeedbackOpenResult.email:
        return '暂时无法打开支持页，已切换到邮件联系';
      case SupportFeedbackOpenResult.unavailable:
        return '暂时无法打开支持页，请稍后重试或发送邮件到 ${SupportFeedbackConfig.supportEmail}';
    }
  }
}
