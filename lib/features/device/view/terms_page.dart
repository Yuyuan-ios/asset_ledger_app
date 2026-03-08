import 'package:flutter/material.dart';

import '../../../patterns/device/legal_section_pattern.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  static const List<LegalSectionContent> _sections = [
    LegalSectionContent(
      title: '1. 服务说明',
      body: '本应用用于设备、计时、燃油、收款与维保等记录管理。你对录入数据的真实性和合法性负责。',
    ),
    LegalSectionContent(
      title: '2. 账号与数据',
      body: '你可在本地保存和管理业务数据。请自行做好备份，因设备丢失、系统故障等导致的数据损失风险由用户承担。',
    ),
    LegalSectionContent(
      title: '3. 订阅与付费',
      body: '部分功能可能需要订阅后使用。订阅价格、周期和试用规则以应用内展示为准。续费与取消按对应应用商店规则执行。',
    ),
    LegalSectionContent(
      title: '4. 合规使用',
      body: '你不得利用本应用从事违法活动，不得上传或传播侵权、违法或有害内容。',
    ),
    LegalSectionContent(
      title: '5. 免责声明',
      body: '本应用按“现状”提供。我们会持续优化，但不保证服务永不间断或绝对无误。请结合业务场景自行核验关键数据。',
    ),
    LegalSectionContent(
      title: '6. 条款更新',
      body: '我们可能根据产品变化更新本条款。更新后继续使用即视为你同意新条款。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(
      title: '使用条款',
      sections: _sections,
      effectiveDateText: '生效日期：2026-03-07',
    );
  }
}
