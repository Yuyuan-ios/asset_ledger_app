import 'package:flutter/material.dart';

import '../../core/foundation/spacing.dart';
import '../../data/models/account_payment.dart';
import '../../data/models/device.dart';
import '../../core/utils/format_utils.dart';

/// 项目账户详情内容（仅内容，不含 BottomSheet Shell）
///
/// 职责：
///
/// - 展示项目基础信息
/// - 逐设备单价 + 修改入口
/// - 收款记录列表
/// - 新增 / 编辑 / 删除收款
///
/// 不负责：
///
/// - BottomSheet
/// - Store
/// - 数据计算
///
class ProjectAccountDetailContent extends StatelessWidget {
  final String title; // 项目名
  final int minYmd;

  final List<Device> devices;
  final Map<int, double> deviceRates; // deviceId -> 当前单价

  final double receivable;
  final double remaining;

  final List<AccountPayment> payments;

  /// 回调
  final VoidCallback onBatchEditRate;

  /// ✅ 改为：传 deviceId（int），避免上层/下层签名不一致导致红线
  final void Function(int deviceId) onEditDeviceRate;

  final VoidCallback onAddPayment;
  final void Function(AccountPayment p) onEditPayment;
  final void Function(AccountPayment p) onDeletePayment;

  const ProjectAccountDetailContent({
    super.key,
    required this.title,
    required this.minYmd,
    required this.devices,
    required this.deviceRates,
    required this.receivable,
    required this.remaining,
    required this.payments,
    required this.onBatchEditRate,
    required this.onEditDeviceRate,
    required this.onAddPayment,
    required this.onEditPayment,
    required this.onDeletePayment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ───────────────── 顶部：项目名 + 日期 ─────────────────
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Text(
              FormatUtils.date(minYmd),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),

        const SizedBox(height: AppSpace.lg),

        // ───────────────── 单价区域 ─────────────────
        Row(
          children: [
            const Text(
              '设备单价',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            TextButton(onPressed: onBatchEditRate, child: const Text('批量修改')),
          ],
        ),

        const SizedBox(height: AppSpace.sm),

        ...devices.map((d) {
          final id = d.id;

          final rate = (id == null)
              ? d.defaultUnitPrice
              : (deviceRates[id] ?? d.defaultUnitPrice);

          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpace.sm - AppSpace.xxs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    d.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  FormatUtils.money(rate),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: AppSpace.sm),
                TextButton(
                  onPressed: (id == null) ? null : () => onEditDeviceRate(id),
                  child: const Text('修改'),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: AppSpace.md),

        // ───────────────── 剩余 / 应收 ─────────────────
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${FormatUtils.money(remaining)} / ${FormatUtils.money(receivable)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),

        const SizedBox(height: AppSpace.lg),
        const Divider(height: 1),
        const SizedBox(height: AppSpace.md),

        // ───────────────── 收款记录 ─────────────────
        const Text(
          '收款记录',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),

        const SizedBox(height: AppSpace.sm),

        if (payments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xxl),
            child: Center(
              child: Text(
                '暂无收款记录',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          )
        else
          ...payments.map((p) {
            final subtitle = (p.note == null || p.note!.trim().isEmpty)
                ? null
                : p.note!.trim();

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${FormatUtils.date(p.ymd)} · ${FormatUtils.money(p.amount)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpace.xxs),
                              child: Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => onEditPayment(p),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => onDeletePayment(p),
                    ),
                  ],
                ),
                const Divider(height: 1),
              ],
            );
          }),

        const SizedBox(height: AppSpace.md),

        // ───────────────── 新增收款 ─────────────────
        Center(
          child: TextButton.icon(
            onPressed: onAddPayment,
            icon: const Icon(Icons.add),
            label: const Text('新增收款'),
          ),
        ),

        const SizedBox(height: AppSpace.xxl),
      ],
    );
  }
}
