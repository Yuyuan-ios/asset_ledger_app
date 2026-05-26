import 'package:asset_ledger/components/layout/name_site_inline_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const monoStyle = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['monospace'],
    fontSize: 14,
  );

  Widget hostedIn({required double width, required Widget child}) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: Row(children: [Expanded(child: child)]),
          ),
        ),
      ),
    );
  }

  testWidgets('renders name, separator, and site as separate Text widgets', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostedIn(
        width: 400,
        child: const NameSiteInlineText(
          name: '李杰',
          site: '尚义',
          nameStyle: monoStyle,
          siteStyle: monoStyle,
          separatorStyle: monoStyle,
        ),
      ),
    );

    expect(find.text('李杰'), findsOneWidget);
    expect(find.text('尚义'), findsOneWidget);
    expect(find.text(' · '), findsOneWidget);
  });

  testWidgets('renders only the name when site is empty', (tester) async {
    await tester.pumpWidget(
      hostedIn(
        width: 400,
        child: const NameSiteInlineText(
          name: '李杰',
          nameStyle: monoStyle,
        ),
      ),
    );

    expect(find.text('李杰'), findsOneWidget);
    expect(find.text(' · '), findsNothing);
  });

  testWidgets(
    'gives both sides ellipsis room when both texts are long',
    (tester) async {
      const longName = 'Christopher Johnson Equipment Services';
      const longSite = 'West Industrial Park Block 12 Section A';

      await tester.pumpWidget(
        hostedIn(
          width: 160,
          child: const NameSiteInlineText(
            name: longName,
            site: longSite,
            nameStyle: monoStyle,
            siteStyle: monoStyle,
            separatorStyle: monoStyle,
          ),
        ),
      );

      final nameTextWidget = tester.widget<Text>(find.text(longName));
      final siteTextWidget = tester.widget<Text>(find.text(longSite));

      // 两侧都拿到独立的省略策略，而不是被合成单个 Text 整体省略。
      expect(nameTextWidget.overflow, TextOverflow.ellipsis);
      expect(siteTextWidget.overflow, TextOverflow.ellipsis);

      final nameRenderBox = tester.renderObject<RenderBox>(find.text(longName));
      final siteRenderBox = tester.renderObject<RenderBox>(find.text(longSite));

      // 两侧都有可见宽度，意味着 site 不会被完全挤掉。
      expect(nameRenderBox.size.width, greaterThan(20));
      expect(siteRenderBox.size.width, greaterThan(20));
    },
  );

  testWidgets('keeps short side at natural width when other side is long', (
    tester,
  ) async {
    const shortName = '李杰';
    const longSite = 'West Industrial Park Block 12 Section A';

    await tester.pumpWidget(
      hostedIn(
        width: 160,
        child: const NameSiteInlineText(
          name: shortName,
          site: longSite,
          nameStyle: monoStyle,
          siteStyle: monoStyle,
          separatorStyle: monoStyle,
        ),
      ),
    );

    expect(find.text(shortName), findsOneWidget);
    final siteRenderBox = tester.renderObject<RenderBox>(find.text(longSite));
    // 长地址在剩余空间内被省略，仍占有可见宽度。
    expect(siteRenderBox.size.width, greaterThan(20));
  });
}
