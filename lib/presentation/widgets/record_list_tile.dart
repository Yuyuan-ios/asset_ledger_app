import 'package:flutter/material.dart';

// =====================================================================
// ============================== 通用列表项组件 ==============================
// =====================================================================
//
// 目标：
// - 统一展示“左侧头像”、“中间标题/副标题”、“右侧状态/操作”
// - 供 TimingPage / FuelPage / MaintenancePage 复用
//
// 关键点：
// - ✅ title/subtitle 强制单行省略：避免某些内容过长导致 ListTile 自动换行，行高不一致
//
// =====================================================================

class RecordListTile extends StatelessWidget {
  // 核心内容
  final Widget leading;
  final String title;
  final String subtitle;

  // 右侧区域：可以是金额/工时文本，也可以是操作按钮组合
  final Widget? trailing;

  // 点击回调
  final VoidCallback? onTap;

  // 样式微调
  final bool dense;

  const RecordListTile({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.dense = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: dense,
      leading: leading,

      // ✅ 统一：标题强制单行省略（避免不同记录行高不一致）
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),

      // ✅ 统一：副标题强制单行省略（避免某些 contact/site 太长导致换行）
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ),

      trailing: trailing,
      onTap: onTap,
    );
  }
}
