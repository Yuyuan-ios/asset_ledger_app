import 'package:flutter/material.dart';

import '../../../patterns/device/legal_section_pattern.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  static const List<LegalSectionContent> _sections = [
    LegalSectionContent(
      title: '1. 适用范围与接受',
      body:
          '本使用条款适用于“机账通”在 iOS 与 Android 平台提供的产品与服务。你在下载、安装、访问或继续使用本应用时，即表示你已阅读并同意受本条款约束。',
    ),
    LegalSectionContent(
      title: '2. 产品功能说明',
      body:
          '本应用面向工程机械经营场景，主要用于设备信息、工时、燃油、项目收支、维保明细等内容的记录与管理。应用展示结果仅作为经营辅助工具，不构成财务、税务、法律或其他专业意见。',
    ),
    LegalSectionContent(
      title: '3. 用户责任',
      body:
          '你应确保录入、保存、导出或分享的信息真实、准确、完整，并保证你对相关数据拥有合法使用权。你不得利用本应用制作、存储或传播违法、侵权、欺诈、恶意或其他违反适用法律法规的内容。',
    ),
    LegalSectionContent(
      title: '4. 本地数据与备份',
      body:
          '当前版本主要采用本地存储方式。你理解并同意：因设备损坏、系统异常、误删除、权限变更、卸载应用或其他非开发者可控原因导致的数据丢失风险，应由你自行承担。建议你根据业务重要程度自行做好备份。',
    ),
    LegalSectionContent(
      title: '5. 权限、平台能力与付费功能',
      body:
          '当你主动使用图片选择、评分入口或未来可能上线的升级/订阅能力时，应用可能调用系统权限或 Apple App Store、Google Play 提供的平台能力。若未来提供订阅、升级或其他付费功能，具体价格、周期、退款、取消与续费规则以应用内展示及对应应用商店规则为准，相关支付结算由对应平台处理。',
    ),
    LegalSectionContent(
      title: '6. 知识产权',
      body:
          '本应用的软件代码、界面设计、文案结构与相关标识等内容，除法律另有规定或另有声明外，相关权利归开发者所有。未经许可，你不得对应用进行非法复制、反向工程、传播或商业化利用。',
    ),
    LegalSectionContent(
      title: '7. 免责声明与责任限制',
      body:
          '本应用按“现状”和“现有可用”状态提供。我们会持续改进产品体验，但不保证应用始终无中断、无错误或完全满足你的特定业务需求。对于因你录入错误、未及时备份、设备故障、系统限制、第三方平台异常或不可抗力导致的损失，在适用法律允许范围内，开发者承担的责任以法律强制要求为限。',
    ),
    LegalSectionContent(
      title: '8. 条款更新与联系',
      body:
          '我们可能根据产品迭代、平台政策或法律法规变化对本条款进行更新。更新版本发布后，如你继续使用本应用，视为接受更新后的条款。如有问题，可联系：582748196@qq.com。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(
      title: '使用条款',
      sections: _sections,
      effectiveDateText: '生效日期：2026-03-17',
    );
  }
}
