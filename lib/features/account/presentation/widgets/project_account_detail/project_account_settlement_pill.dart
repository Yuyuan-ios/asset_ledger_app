import 'package:flutter/material.dart';

import '../../../../../core/foundation/typography.dart';
import '../../../../../tokens/mapper/radius_tokens.dart';

const _settlementPillBackground = Color(0xFFE4F6EF);
const _settlementPillBorder = Color(0xFF77C8A5);
const _settlementPillText = Color(0xFF16714F);
const _settledPillBackground = Color(0xFFF1F5F3);
const _settledPillBorder = Color(0xFFD7E2DC);
const _settledPillText = Color(0xFF6E8277);

class ProjectAccountSettlementPill extends StatelessWidget {
  const ProjectAccountSettlementPill({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = enabled ? _settlementPillText : _settledPillText;
    final backgroundColor = enabled
        ? _settlementPillBackground
        : _settledPillBackground;
    final borderColor = enabled ? _settlementPillBorder : _settledPillBorder;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(RadiusTokens.pill),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(RadiusTokens.pill),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: AppTypography.actionText(
            context,
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}
