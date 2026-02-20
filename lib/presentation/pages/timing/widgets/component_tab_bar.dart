import 'package:flutter/material.dart';

/// Figma: Component_TabBar
/// - 固定底部
/// - 5 个 Tab（计时/燃油/账户/维保/设备）
/// - 选中：品牌色 + 文案高亮
/// - 未选中：灰色
class ComponentTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ComponentTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
          border: const Border(top: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _item(index: 0, icon: Icons.timer, label: '计时'),
            _item(index: 1, icon: Icons.local_gas_station, label: '燃油'),
            _item(index: 2, icon: Icons.account_balance_wallet, label: '账户'),
            _item(index: 3, icon: Icons.build, label: '维保'),
            _item(index: 4, icon: Icons.settings, label: '设备'),
          ],
        ),
      ),
    );
  }

  Widget _item({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = index == currentIndex;
    final color = selected ? const Color(0xFFE68E22) : const Color(0xFF999999);

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: index == 3 ? 30 : 26, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  height: 1,
                  color: color,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
