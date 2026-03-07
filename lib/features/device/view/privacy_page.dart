import 'package:flutter/material.dart';

import '../../../core/foundation/typography.dart';
import '../../../tokens/mapper/core_tokens.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

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
          '隐私政策',
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
            '1. 我们收集的信息',
            '应用会保存你输入的设备、计时、燃油、收款、维保等业务数据，以及你主动设置的头像文件路径等信息。',
          ),
          _section(
            context,
            '2. 信息用途',
            '这些信息仅用于提供核心功能，例如记录管理、统计展示、筛选查询和功能状态判断。',
          ),
          _section(
            context,
            '3. 存储与安全',
            '当前版本主要以本地存储为主。你应妥善保管设备并定期备份数据，避免因设备故障或误操作造成损失。',
          ),
          _section(
            context,
            '4. 权限说明',
            '当你使用头像更换等能力时，应用会请求必要权限（如相册访问）。你可在系统设置中随时管理这些权限。',
          ),
          _section(
            context,
            '5. 第三方服务',
            '若使用应用商店评分、订阅或恢复购买等能力，相关交易和账户信息由对应平台（Apple/Google）处理。',
          ),
          _section(
            context,
            '6. 政策更新',
            '我们可能根据产品变化更新本政策。更新后继续使用应用，视为你同意更新内容。',
          ),
          const SizedBox(height: 8),
          Text(
            '生效日期：2026-03-07',
            style: AppTypography.bodySecondary(
                  context,
                  fontSize: 13,
                ) ??
                TextStyle(
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
