import 'package:flutter/material.dart';

import '../../../patterns/device/legal_section_pattern.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  static const List<LegalSectionContent> _sections = [
    LegalSectionContent(
      title: '1. 我们收集的信息',
      body: '应用会保存你输入的设备、计时、燃油、收款、维保等业务数据，以及你主动设置的头像文件路径等信息。',
    ),
    LegalSectionContent(
      title: '2. 信息用途',
      body: '这些信息仅用于提供核心功能，例如记录管理、统计展示、筛选查询和功能状态判断。',
    ),
    LegalSectionContent(
      title: '3. 存储与安全',
      body: '当前版本主要以本地存储为主。你应妥善保管设备并定期备份数据，避免因设备故障或误操作造成损失。',
    ),
    LegalSectionContent(
      title: '4. 权限说明',
      body: '当你使用头像更换等能力时，应用会请求必要权限（如相册访问）。你可在系统设置中随时管理这些权限。',
    ),
    LegalSectionContent(
      title: '5. 第三方服务',
      body: '若使用应用商店评分、订阅或恢复购买等能力，相关交易和账户信息由对应平台（Apple/Google）处理。',
    ),
    LegalSectionContent(
      title: '6. 政策更新',
      body: '我们可能根据产品变化更新本政策。更新后继续使用应用，视为你同意更新内容。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(
      title: '隐私政策',
      sections: _sections,
      effectiveDateText: '生效日期：2026-03-07',
    );
  }
}
