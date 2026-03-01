// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import 'package:flutter/material.dart';
import '../../core/foundation/radius.dart';
import '../../core/foundation/spacing.dart';

// =====================================================================
// ============================== 二、ProGate（订阅能力门控组件） ==============================
// =====================================================================
//
// 设计目标：
// - Page/UI 不写任何 “if (isPro)” 分支
// - 需要 Pro 的 UI，统一用 ProGate 包起来
// - 未来接 IAP，只改 SubscriptionService.refresh 与缓存逻辑
//
// 层级：Presentation Widget（UI 可复用组件）
// =====================================================================

class ProGate extends StatelessWidget {
  // -------------------------------------------------------------------
  // 2.1 child：允许 Pro 访问时展示的内容
  // -------------------------------------------------------------------
  final Widget child;

  // -------------------------------------------------------------------
  // 2.2 fallback：非 Pro 时展示（必填）
  // -------------------------------------------------------------------
  final Widget fallback;

  // -------------------------------------------------------------------
  // 2.3 onTapUpgrade：点击“升级”回调（可选）
  // -------------------------------------------------------------------
  final VoidCallback? onTapUpgrade;

  const ProGate({
    super.key,
    required this.child,
    required this.fallback,
    this.onTapUpgrade,
    required this.isPro,
  });

  // 2.4 Pro 状态（由页面/Store 注入）
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    if (isPro) return child;

    // -----------------------------------------------------------------
    // 2.5 默认 fallback：提示升级（你后面可以替换成订阅页入口）
    // -----------------------------------------------------------------
    return InkWell(
      onTap: onTapUpgrade,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.orange.shade300),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          color: Colors.orange.shade50,
        ),
        child: fallback,
      ),
    );
  }
}
