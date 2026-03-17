import 'package:flutter/material.dart';

import '../../../patterns/device/legal_section_pattern.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  static const List<LegalSectionContent> _sections = [
    LegalSectionContent(
      title: '1. 适用范围',
      body:
          '本隐私政策适用于“机账通”在 iOS 与 Android 平台提供的产品与服务，用于说明我们如何处理你在使用应用过程中主动提供或因功能运行而形成的信息。',
    ),
    LegalSectionContent(
      title: '2. 我们处理的信息类型',
      body:
          '在当前版本中，我们主要处理以下信息：\n'
          '• 你主动录入的业务记录，例如设备信息、工时、燃油、项目收支、维保明细等；\n'
          '• 你主动选择并设置的头像或图片文件；\n'
          '• 为实现页面展示、功能判断与本地存储所必需的应用运行信息。\n'
          '我们当前不提供开发者自建账号系统、云端同步、广告投放或行为分析服务。',
    ),
    LegalSectionContent(
      title: '3. 信息来源与用途',
      body:
          '前述信息主要来源于你的主动输入、主动上传以及你使用相关功能时在本机形成的数据。我们处理这些信息，仅用于实现设备经营记录、统计展示、筛选查询、头像展示、功能状态判断与基础问题排查等与你预期一致的产品功能。',
    ),
    LegalSectionContent(
      title: '4. 权限与系统能力说明',
      body:
          '当你主动使用自定义头像等功能时，应用可能申请相册访问权限，用于读取你选择的图片。我们不会在未经你主动触发的情况下访问相册，也不会将图片用于与当前功能无关的用途。你可随时在 iOS 或 Android 系统设置中撤回相关权限。',
    ),
    LegalSectionContent(
      title: '5. 存储方式、共享与安全',
      body:
          '当前版本以本地存储为主，业务数据主要保存在你的设备中。除实现应用商店评分、未来可能接入的订阅购买或恢复购买等平台能力外，我们不会主动将你的业务记录出售、出租或共享给广告网络、数据经纪商或其他无关第三方。若你使用 Apple App Store 或 Google Play 提供的购买、评分等能力，相关账户与支付流程由对应平台按照其自身政策处理。我们会尽合理努力保护本地数据安全，但你仍应妥善保管设备并定期自行备份重要信息。',
    ),
    LegalSectionContent(
      title: '6. 数据保留、删除与权限撤回',
      body:
          '由于当前版本不建立开发者侧云端账户，业务数据通常会保留在你的本地设备中，直至你自行删除、卸载应用或清除应用数据。若你希望撤回图片访问授权，可直接在系统设置中关闭权限。若你曾通过邮件向我们提供问题截图或说明并希望删除相关沟通记录，可通过 582748196@qq.com 与我们联系。',
    ),
    LegalSectionContent(
      title: '7. 未成年人说明',
      body: '本应用面向工程机械经营与管理场景，不以未成年人为主要目标用户。若你是未成年人，建议在监护人指导下阅读并使用本应用。',
    ),
    LegalSectionContent(
      title: '8. 政策更新与联系我们',
      body:
          '如产品功能、数据处理方式或适用规则发生变化，我们可能更新本隐私政策。更新后的版本会在应用内或公开页面发布，并以最新发布日期为准。如你对本政策有任何问题，可联系：582748196@qq.com。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(
      title: '隐私政策',
      sections: _sections,
      effectiveDateText: '生效日期：2026-03-17',
    );
  }
}
