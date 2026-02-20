import 'package:flutter/material.dart';

import '../../models/account_payment.dart';
import '../../models/device.dart';
import '../../presentation/utils/format_utils.dart';

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
            const SizedBox(width: 8),
            Text(
              FormatUtils.date(minYmd),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),

        const SizedBox(height: 16),

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

        const SizedBox(height: 8),

        ...devices.map((d) {
          final id = d.id;

          final rate = (id == null)
              ? d.defaultUnitPrice
              : (deviceRates[id] ?? d.defaultUnitPrice);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
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
                const SizedBox(width: 8),
                TextButton(
                  onPressed: (id == null) ? null : () => onEditDeviceRate(id),
                  child: const Text('修改'),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 12),

        // ───────────────── 剩余 / 应收 ─────────────────
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${FormatUtils.money(remaining)} / ${FormatUtils.money(receivable)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),

        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // ───────────────── 收款记录 ─────────────────
        const Text(
          '收款记录',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),

        const SizedBox(height: 8),

        if (payments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
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
                              padding: const EdgeInsets.only(top: 2),
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

        const SizedBox(height: 12),

        // ───────────────── 新增收款 ─────────────────
        Center(
          child: TextButton.icon(
            onPressed: onAddPayment,
            icon: const Icon(Icons.add),
            label: const Text('新增收款'),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}
