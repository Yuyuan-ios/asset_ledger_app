import 'package:in_app_review/in_app_review.dart';

class RateAppService {
  static Future<bool> openSystemRateEntry() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
        return true;
      }
      await review.openStoreListing();
      return true;
    } catch (_) {
      return false;
    }
  }
}
