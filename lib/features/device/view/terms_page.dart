import 'package:flutter/material.dart';

import '../../../core/foundation/typography.dart';
import '../../../tokens/mapper/core_tokens.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          '使用条款',
          style: AppTypography.sectionTitle(
            context,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _section(
            context,
            '1. 服务说明',
            '本应用用于设备、计时、燃油、收款与维保等记录管理。你对录入数据的真实性和合法性负责。',
          ),
          _section(
            context,
            '2. 账号与数据',
            '你可在本地保存和管理业务数据。请自行做好备份，因设备丢失、系统故障等导致的数据损失风险由用户承担。',
          ),
          _section(
            context,
            '3. 订阅与付费',
            '部分功能可能需要订阅后使用。订阅价格、周期和试用规则以应用内展示为准。续费与取消按对应应用商店规则执行。',
          ),
          _section(
            context,
            '4. 合规使用',
            '你不得利用本应用从事违法活动，不得上传或传播侵权、违法或有害内容。',
          ),
          _section(
            context,
            '5. 免责声明',
            '本应用按“现状”提供。我们会持续优化，但不保证服务永不间断或绝对无误。请结合业务场景自行核验关键数据。',
          ),
          _section(
            context,
            '6. 条款更新',
            '我们可能根据产品变化更新本条款。更新后继续使用即视为你同意新条款。',
          ),
          const SizedBox(height: 8),
          Text(
            '生效日期：2026-03-07',
            style: AppTypography.bodySecondary(
              context,
              fontSize: 13,
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.body(
              context,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppTypography.body(
              context,
              fontSize: 14,
              height: 1.45,
              color: Colors.black.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
