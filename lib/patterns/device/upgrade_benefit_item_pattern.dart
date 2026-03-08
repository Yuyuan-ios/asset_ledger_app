import 'package:flutter/material.dart';

import '../../tokens/mapper/core_tokens.dart';

class UpgradeBenefitItem extends StatelessWidget {
  const UpgradeBenefitItem({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DeviceTokens.upgradeBenefitBottom),
      child: Row(
        children: [
          const CircleAvatar(
            radius: DeviceTokens.upgradeBenefitIconRadius,
            backgroundColor: DeviceTokens.upgradeSurface,
            child: Icon(Icons.check, color: DeviceTokens.upgradeAccent),
          ),
          const SizedBox(width: DeviceTokens.upgradeBenefitIconGap),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: DeviceTokens.upgradeFooterTextColor,
                fontSize: DeviceTokens.upgradeBenefitTextSize,
                fontWeight: DeviceTokens.upgradeBenefitTextWeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
