part of '../../../../../patterns/account/project_account_detail_content_pattern.dart';

extension ProjectAccountDetailPaymentSections on ProjectAccountDetailContent {
  Widget _buildPaymentCard({
    required AccountProjectPaymentDisplayVM item,
    required TextStyle? dateStyle,
    required TextStyle? remarkStyle,
    required TextStyle? amountStyle,
    required TextStyle? tagStyle,
  }) {
    final dateText = FormatUtils.date(item.ymd);
    final amountText = FormatUtils.money(item.amount);
    final sourceLabel = item.sourceLabel.trim();
    final remarkText = item.note?.trim() ?? '';
    final rawPayment =
        item.type == AccountProjectPaymentDisplayType.normalMemberPayment
        ? _paymentByDisplayItem(item)
        : null;
    final canEditRawPayment =
        showPaymentActions && showRawPaymentActions && rawPayment != null;
    final canEditDisplayItem =
        showPaymentActions &&
        rawPayment == null &&
        item.type == AccountProjectPaymentDisplayType.mergeBatchPayment &&
        onEditPaymentDisplayItem != null;
    final canDeleteDisplayItem =
        showPaymentActions &&
        rawPayment == null &&
        item.type == AccountProjectPaymentDisplayType.mergeBatchPayment &&
        onDeletePaymentDisplayItem != null;
    final showEditButton = canEditRawPayment || canEditDisplayItem;
    final showDeleteButton = canEditRawPayment || canDeleteDisplayItem;

    return Padding(
      padding: const EdgeInsets.only(
        left: AccountTokens.projectDetailSectionHorizontalPadding,
        right: AccountTokens.projectDetailSectionHorizontalPadding,
        bottom: AccountTokens.projectCardBottomMargin,
      ),
      child: Container(
        height: 66,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AccountTokens.projectCardPaddingHorizontal,
                  7,
                  AppSpace.sm,
                  7,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 92),
                          child: Text(
                            dateText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: dateStyle,
                          ),
                        ),
                        if (sourceLabel.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Flexible(
                            child: _buildPaymentSourceBadge(
                              sourceLabel: sourceLabel,
                              tagStyle: tagStyle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            amountText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: amountStyle,
                          ),
                        ),
                        if (remarkText.isNotEmpty) ...[
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: Text(
                              '备注：$remarkText',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: remarkStyle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (showEditButton)
              _buildPaymentAction(
                icon: Icons.edit_outlined,
                backgroundColor: const Color(0xFFFFF7F0),
                onPressed: rawPayment != null
                    ? () => onEditPayment(rawPayment)
                    : () => onEditPaymentDisplayItem?.call(item),
              ),
            if (showDeleteButton)
              _buildPaymentAction(
                icon: Icons.delete_outline,
                backgroundColor: const Color(0xFFFFF0E6),
                onPressed: rawPayment != null
                    ? () => onDeletePayment(rawPayment)
                    : () => onDeletePaymentDisplayItem?.call(item),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentAction({
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 52,
      height: double.infinity,
      child: ColoredBox(
        color: backgroundColor,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            icon,
            size: 21,
            color: AccountTokens.projectDetailActionColor,
          ),
        ),
      ),
    );
  }
}
