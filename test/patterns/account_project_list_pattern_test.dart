import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/patterns/account/account_project_list_pattern.dart';
import 'package:asset_ledger/patterns/account/account_project_section_pattern.dart';
import 'package:asset_ledger/tokens/mapper/core_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders total hours in bold on account project cards', (
    tester,
  ) async {
    const project = AccountProjectVM(
      projectKey: 'zhao-shangyi',
      displayName: '赵六 + 尚义',
      minYmd: 20260317,
      deviceIds: [1],
      hoursByDevice: {1: 9},
      rentIncomeTotal: 0,
      minRate: 120,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 1080,
      received: 1000,
      remaining: 80,
      ratio: 0.926,
      payments: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountProjectList(projects: const [project], onTap: (_) {}),
        ),
      ),
    );

    final totalHoursText = tester.widget<Text>(find.text('总共:  9 h'));

    expect(totalHoursText.style?.fontWeight, FontWeight.w700);
  });

  testWidgets(
    'shows included sites after received percent for merged projects',
    (tester) async {
      const project = AccountProjectVM(
        projectKey: 'merge:1',
        displayName: '赵六 + 合并2项目',
        kind: AccountProjectKind.merged,
        mergeGroupId: 1,
        memberProjectKeys: ['赵六||尚义', '赵六||鲜滩'],
        includedSites: ['尚义', '鲜滩'],
        minYmd: 20260317,
        deviceIds: [1],
        hoursByDevice: {1: 9},
        rentIncomeTotal: 0,
        minRate: 120,
        isMultiDevice: false,
        isMultiMode: false,
        receivable: 1080,
        received: 1000,
        remaining: 80,
        ratio: 0.926,
        payments: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountProjectList(projects: const [project], onTap: (_) {}),
          ),
        ),
      );

      expect(find.text('92.6%实收('), findsOneWidget);
      expect(find.text('尚义+鲜滩'), findsOneWidget);
      expect(find.text(')'), findsOneWidget);
    },
  );

  testWidgets('shows rent label and hides zero hours for rent-only project', (
    tester,
  ) async {
    const project = AccountProjectVM(
      projectKey: '周亮||成都',
      displayName: '周亮 + 成都',
      minYmd: 20260516,
      deviceIds: [],
      hoursByDevice: {},
      rentIncomeTotal: 22000,
      minRate: null,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 22000,
      received: 0,
      remaining: 22000,
      ratio: 0,
      payments: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountProjectList(projects: const [project], onTap: (_) {}),
        ),
      ),
    );

    expect(find.text('租金(台班)'), findsOneWidget);
    expect(find.text('单价:—'), findsNothing);
    expect(find.text('总共:  0 h'), findsNothing);
  });

  testWidgets('shows settled card text without pending amount', (tester) async {
    const cashSettled = AccountProjectVM(
      projectKey: 'cash',
      displayName: '甲方 + 现金结清',
      minYmd: 20260501,
      deviceIds: [1],
      hoursByDevice: {1: 12.6},
      rentIncomeTotal: 0,
      minRate: 100,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 1260,
      received: 1260,
      remaining: 0,
      ratio: 1,
      payments: [],
    );
    const writeOffSettled = AccountProjectVM(
      projectKey: 'write-off',
      displayName: '甲方 + 核销结清',
      minYmd: 20260502,
      deviceIds: [1],
      hoursByDevice: {1: 12.6},
      rentIncomeTotal: 0,
      minRate: 100,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 1260,
      received: 1200,
      writeOff: 60,
      remaining: 0,
      ratio: 1200 / 1260,
      settlementRatio: 1,
      payments: [],
    );
    const pending = AccountProjectVM(
      projectKey: 'pending',
      displayName: '甲方 + 未结清',
      minYmd: 20260503,
      deviceIds: [1],
      hoursByDevice: {1: 12},
      rentIncomeTotal: 0,
      minRate: 100,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 1260,
      received: 1200,
      remaining: 60,
      ratio: 1200 / 1260,
      payments: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountProjectList(
            projects: const [cashSettled, writeOffSettled, pending],
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('总额 ¥1260'), findsOneWidget);
    expect(find.text('总额 ¥1260-核销 ¥60'), findsOneWidget);
    expect(find.text('已结清'), findsNWidgets(2));
    expect(find.text('余: ¥60 / ¥1260'), findsOneWidget);
    expect(find.text('余: ¥0 / ¥1260'), findsNothing);
    expect(find.text('实收 ¥1260 / ¥1260'), findsNothing);
    expect(find.text('实收 ¥1200 / ¥1260'), findsNothing);
    expect(find.text('已结清 · 核销 ¥60'), findsNothing);
    expect(_containerWithColor(const Color(0xFFFFFFFF)), findsNWidgets(3));
    expect(_containerWithBorder(const Color(0x4D000000)), findsNWidgets(3));
    expect(_settledCelebrationIcons(), findsNWidgets(2));

    final settledIcons = tester.widgetList<Icon>(_settledCheckIcons()).toList();
    expect(settledIcons, hasLength(2));
    expect(
      settledIcons.every((icon) => icon.color == const Color(0xFF4AAFD8)),
      isTrue,
    );
  });

  testWidgets('settled check keeps long project title and date in one row', (
    tester,
  ) async {
    const project = AccountProjectVM(
      projectKey: 'long-settled',
      displayName: '特别特别长的联系人名称 + 特别特别长的项目地址名称',
      minYmd: 20260501,
      deviceIds: [1],
      hoursByDevice: {1: 12.6},
      rentIncomeTotal: 0,
      minRate: 100,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 1260,
      received: 1260,
      remaining: 0,
      ratio: 1,
      payments: [],
    );

    String? tappedProjectKey;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            child: AccountProjectList(
              projects: const [project],
              onTap: (project) => tappedProjectKey = project.projectKey,
            ),
          ),
        ),
      ),
    );

    expect(_settledCheckIcons(), findsOneWidget);
    expect(_settledCelebrationIcons(), findsOneWidget);
    expect(find.text('2026.05.01'), findsOneWidget);

    await tester.tap(find.text('已结清'));
    await tester.pump();

    expect(tappedProjectKey, 'long-settled');
    expect(tester.takeException(), isNull);
  });

  testWidgets('styles price badges by pricing state', (tester) async {
    const singleProject = AccountProjectVM(
      projectKey: 'single',
      displayName: '李杰 + 五里山',
      minYmd: 20260501,
      deviceIds: [1],
      hoursByDevice: {1: 10},
      rentIncomeTotal: 0,
      minRate: 180,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 1800,
      received: 0,
      remaining: 1800,
      ratio: 0,
      payments: [],
    );
    const multiProject = AccountProjectVM(
      projectKey: 'multi',
      displayName: '周亮 + 成都',
      minYmd: 20260515,
      deviceIds: [1, 2],
      hoursByDevice: {1: 18, 2: 50},
      rentIncomeTotal: 0,
      minRate: 180,
      isMultiDevice: true,
      isMultiMode: false,
      receivable: 12240,
      received: 0,
      remaining: 12240,
      ratio: 0,
      payments: [],
    );
    const rentProject = AccountProjectVM(
      projectKey: 'rent',
      displayName: '李勇 + 重庆',
      minYmd: 20260517,
      deviceIds: [],
      hoursByDevice: {},
      rentIncomeTotal: 22000,
      minRate: null,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 22000,
      received: 0,
      remaining: 22000,
      ratio: 0,
      payments: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountProjectList(
            projects: const [singleProject, multiProject, rentProject],
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('单价:¥180').first).style?.color,
      const Color(0xFF315A78),
    );
    expect(
      tester.widget<Text>(find.text('单价:¥180(多设备)')).style?.color,
      const Color(0xFF5E4AA8),
    );
    expect(
      tester.widget<Text>(find.text('租金(台班)')).style?.color,
      const Color(0xFF7A5418),
    );

    expect(_badgeWithColor(const Color(0xFFEAF2FA)), findsOneWidget);
    expect(_badgeWithColor(const Color(0xFFF1EDFF)), findsOneWidget);
    expect(_badgeWithColor(const Color(0xFFFFF2DF)), findsOneWidget);
  });

  testWidgets('compact project list hides the full price and total-hours row', (
    tester,
  ) async {
    const project = AccountProjectVM(
      projectKey: 'multi',
      displayName: '周亮 + 成都',
      minYmd: 20260515,
      deviceIds: [1, 2],
      hoursByDevice: {1: 18, 2: 50},
      rentIncomeTotal: 0,
      minRate: 180,
      isMultiDevice: true,
      isMultiMode: false,
      receivable: 12240,
      received: 5000,
      remaining: 7240,
      ratio: 0.408,
      payments: [],
    );
    const rentProject = AccountProjectVM(
      projectKey: 'rent',
      displayName: '李勇 + 重庆',
      minYmd: 20260517,
      deviceIds: [],
      hoursByDevice: {},
      rentIncomeTotal: 22000,
      minRate: null,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 22000,
      received: 0,
      remaining: 22000,
      ratio: 0,
      payments: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountProjectList(
            projects: const [project, rentProject],
            isCompact: true,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('单价:¥180(多设备)'), findsNothing);
    expect(find.text('租金(台班)'), findsNothing);
    expect(find.text('总共:  68 h'), findsNothing);
    expect(find.text('40.8%实收'), findsOneWidget);
    expect(find.text('项目总额 ¥12240'), findsOneWidget);
    expect(find.text('项目总额 ¥22000'), findsOneWidget);
    expect(find.text('待收 ¥7240'), findsOneWidget);
    expect(find.text('待收 ¥22000'), findsOneWidget);
    expect(find.text('余: ¥7240 / ¥12240'), findsNothing);
    expect(find.text('余: ¥22000 / ¥22000'), findsNothing);
  });

  testWidgets('compact settled cards show total and write-off text', (
    tester,
  ) async {
    const cashSettled = AccountProjectVM(
      projectKey: 'cash',
      displayName: '甲方 + 现金结清',
      minYmd: 20260501,
      deviceIds: [1],
      hoursByDevice: {1: 12.6},
      rentIncomeTotal: 0,
      minRate: 100,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 1260,
      received: 1260,
      remaining: 0,
      ratio: 1,
      payments: [],
    );
    const writeOffSettled = AccountProjectVM(
      projectKey: 'write-off',
      displayName: '甲方 + 核销结清',
      minYmd: 20260502,
      deviceIds: [1],
      hoursByDevice: {1: 12.6},
      rentIncomeTotal: 0,
      minRate: 100,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 1260,
      received: 1200,
      writeOff: 60,
      remaining: 0,
      ratio: 1200 / 1260,
      settlementRatio: 1,
      payments: [],
    );
    const pending = AccountProjectVM(
      projectKey: 'pending',
      displayName: '甲方 + 未结清',
      minYmd: 20260503,
      deviceIds: [1],
      hoursByDevice: {1: 12},
      rentIncomeTotal: 0,
      minRate: 100,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 1260,
      received: 600,
      remaining: 660,
      ratio: 600 / 1260,
      payments: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountProjectList(
            projects: const [cashSettled, writeOffSettled, pending],
            isCompact: true,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('总额 ¥1260-核销 ¥60'), findsOneWidget);
    expect(find.text('总额 ¥1260'), findsOneWidget);
    expect(find.text('已结清'), findsNWidgets(2));
    expect(find.text('项目总额¥1260'), findsNothing);
    expect(find.text('项目总额 ¥1260 核销(减免) ¥60'), findsNothing);
    expect(find.text('核销(减免) ¥60'), findsNothing);
    expect(find.text('95.2%实收'), findsNothing);
    expect(find.text('47.6%实收'), findsOneWidget);
    expect(find.text('余: ¥660 / ¥1260'), findsNothing);
    expect(find.text('待收 ¥660'), findsOneWidget);
    expect(_containerWithColor(const Color(0xFFFFFFFF)), findsNWidgets(3));
    expect(_settledCheckIcons(), findsNWidgets(2));
    expect(_settledCelebrationIcons(), findsNWidgets(2));
  });

  testWidgets('project header toggles compact mode from title group only', (
    tester,
  ) async {
    var toggleCount = 0;
    var trailingTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountProjectPinnedHeader(
            projectCount: 5,
            isCompactProjectList: true,
            onToggleCompactProjectList: () => toggleCount += 1,
            trailing: TextButton(
              onPressed: () => trailingTapCount += 1,
              child: const Text('筛选'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('项目(5)'), findsOneWidget);
    expect(find.byTooltip('普通显示'), findsOneWidget);
    expect(_containerWithColor(const Color(0xFFECECEC)), findsNothing);
    expect(
      _densityLinesWithColor(TimingColors.textSecondary),
      findsNWidgets(3),
    );

    await tester.tap(find.text('项目(5)'));
    await tester.pump();
    expect(toggleCount, 1);
    expect(trailingTapCount, 0);

    await tester.tap(find.text('筛选'));
    await tester.pump();
    expect(toggleCount, 1);
    expect(trailingTapCount, 1);
  });

  testWidgets('project density icon uses primary color in normal mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AccountProjectPinnedHeader(
            projectCount: 5,
            onToggleCompactProjectList: _noop,
            trailing: SizedBox.shrink(),
          ),
        ),
      ),
    );

    expect(find.text('项目(5)'), findsOneWidget);
    expect(_containerWithColor(const Color(0xFFECECEC)), findsNothing);
    expect(_densityLinesWithColor(AppColors.textPrimary), findsNWidgets(3));
  });
}

void _noop() {}

Finder _badgeWithColor(Color color) {
  return find.byWidgetPredicate((widget) {
    final decoration = widget is Container ? widget.decoration : null;
    return decoration is BoxDecoration && decoration.color == color;
  });
}

Finder _containerWithColor(Color color) {
  return find.byWidgetPredicate((widget) {
    final decoration = widget is Container ? widget.decoration : null;
    return decoration is BoxDecoration && decoration.color == color;
  });
}

Finder _containerWithBorder(Color color) {
  return find.byWidgetPredicate((widget) {
    final decoration = widget is Container ? widget.decoration : null;
    return decoration is BoxDecoration &&
        decoration.border is Border &&
        (decoration.border as Border).top.color == color;
  });
}

Finder _densityLinesWithColor(Color color) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Container) return false;
    final decoration = widget.decoration;
    return widget.constraints ==
            const BoxConstraints.tightFor(width: 14, height: 3) &&
        decoration is BoxDecoration &&
        decoration.color == color &&
        decoration.borderRadius == BorderRadius.circular(1.2);
  });
}

Finder _settledCheckIcons() {
  return find.byWidgetPredicate((widget) {
    return widget is Icon &&
        widget.icon == Icons.verified_rounded &&
        widget.size == 18;
  });
}

Finder _settledCelebrationIcons() {
  return find.byWidgetPredicate((widget) {
    if (widget is! Image || widget.semanticLabel != '结清图标') {
      return false;
    }
    final image = widget.image;
    return image is AssetImage &&
        image.assetName == 'assets/icons/account/settled_celebration.png' &&
        widget.width == 18 &&
        widget.height == 18;
  });
}
