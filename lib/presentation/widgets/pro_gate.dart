// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import 'package:flutter/material.dart';

// 1.1 项目内：订阅服务（同步读缓存）
import '../../services/subscription_service.dart';

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
  // 2.2 fallback：非 Pro 时展示（可选）
  // -------------------------------------------------------------------
  final Widget? fallback;

  // -------------------------------------------------------------------
  // 2.3 onTapUpgrade：点击“升级”回调（可选）
  // -------------------------------------------------------------------
  final VoidCallback? onTapUpgrade;

  const ProGate({
    super.key,
    required this.child,
    this.fallback,
    this.onTapUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    // -----------------------------------------------------------------
    // 2.4 同步读取缓存：UI/Store 不等待 async
    // -----------------------------------------------------------------
    final isPro = SubscriptionService.proCached;

    if (isPro) return child;

    // -----------------------------------------------------------------
    // 2.5 默认 fallback：提示升级（你后面可以替换成订阅页入口）
    // -----------------------------------------------------------------
    return fallback ??
        InkWell(
          onTap: onTapUpgrade,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orange.shade300),
              borderRadius: BorderRadius.circular(10),
              color: Colors.orange.shade50,
            ),
            child: const Text(
              '订阅版功能：自定义头像（点击了解/升级）',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        );
  }
}
