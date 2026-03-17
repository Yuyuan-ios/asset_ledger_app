import 'package:url_launcher/url_launcher.dart';

import '../../core/config/support_feedback_config.dart';

enum SupportFeedbackOpenResult { supportSite, email, unavailable }

class SupportFeedbackService {
  const SupportFeedbackService._();

  static Future<SupportFeedbackOpenResult> openSupportEntry() async {
    final openedSupportSite = await _launchExternalUrl(
      SupportFeedbackConfig.supportSiteUrl,
    );
    if (openedSupportSite) {
      return SupportFeedbackOpenResult.supportSite;
    }

    final openedEmail = await _launchEmail();
    if (openedEmail) {
      return SupportFeedbackOpenResult.email;
    }

    return SupportFeedbackOpenResult.unavailable;
  }

  static Future<bool> _launchExternalUrl(String rawUrl) async {
    final url = rawUrl.trim();
    final uri = Uri.tryParse(url);
    if (url.isEmpty || uri == null || !uri.hasScheme) {
      return false;
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _launchEmail() async {
    final email = SupportFeedbackConfig.supportEmail.trim();
    if (email.isEmpty) return false;

    final subject = SupportFeedbackConfig.supportEmailSubject.trim();
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: subject.isEmpty
          ? null
          : <String, String>{'subject': subject},
    );

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
