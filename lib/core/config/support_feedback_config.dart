class SupportFeedbackConfig {
  const SupportFeedbackConfig._();

  // 若使用当前仓库的 GitHub Pages，可保持为该地址。
  static const String supportSiteUrl =
      'https://yuyuan-ios.github.io/asset_ledger_app/';

  static const String supportEmail = '582748196@qq.com';
  static const String supportEmailSubject = '机账通｜支持与反馈';

  // 支持页相关链接占位，部署公开页面后建议同步替换为正式地址。
  static const String privacyPolicyUrl = 'https://example.com/privacy-policy';
  static const String termsOfServiceUrl =
      'https://example.com/terms-of-service';

  static const String douyinHandle = '@开挖机的coder';

  // 留空则在支持页中隐藏。
  static const String wechatLabel = '';
}
