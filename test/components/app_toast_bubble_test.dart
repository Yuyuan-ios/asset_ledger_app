import 'package:asset_ledger/components/feedback/app_toast_bubble.dart';
import 'package:asset_ledger/tokens/mapper/core_tokens.dart';
import 'package:asset_ledger/tokens/mapper/toast_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the shared black toast bubble style', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: AppToastBubble('已保存')),
        ),
      ),
    );

    final decoratedBox = tester.widget<DecoratedBox>(
      find.byType(DecoratedBox),
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.color, AppColors.textPrimary);
    expect(decoration.borderRadius, BorderRadius.circular(ToastTokens.radius));

    final text = tester.widget<Text>(find.text('已保存'));
    expect(text.style?.color, Colors.white);
    expect(text.style?.fontSize, ToastTokens.textSize);
  });
}
