import 'package:asset_ledger/tokens/mapper/account_tokens.dart';
import 'package:asset_ledger/tokens/mapper/bottom_sheet_tokens.dart';
import 'package:asset_ledger/tokens/mapper/device_tokens.dart';
import 'package:asset_ledger/tokens/mapper/dialog_tokens.dart';
import 'package:asset_ledger/tokens/mapper/radius_tokens.dart';
import 'package:asset_ledger/tokens/mapper/sheet_tokens.dart';
import 'package:asset_ledger/tokens/mapper/summary_card_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feature radius tokens alias semantic radius tokens', () {
    expect(SheetTokens.fieldRadius, RadiusTokens.input);
    expect(DeviceActionCardTokens.radius, RadiusTokens.rowCard);
    expect(AccountTokens.projectCardRadius, RadiusTokens.recordCard);
    expect(AccountTokens.projectCardProgressRadius, RadiusTokens.decoration);
    expect(AccountTokens.projectDetailProgressRadius, RadiusTokens.decoration);
    expect(SummaryCardTokens.cardRadius, RadiusTokens.card);
    expect(DialogTokens.radius, RadiusTokens.sheet);
    expect(BottomSheetTokens.radius, RadiusTokens.sheet);
  });
}
