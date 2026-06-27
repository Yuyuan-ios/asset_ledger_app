import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/patterns/account/account_project_list_pattern.dart';
import 'package:asset_ledger/patterns/account/account_project_section_pattern.dart';
import 'package:asset_ledger/tokens/mapper/account_tokens.dart';
import 'package:asset_ledger/tokens/mapper/core_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty hint uses larger account text and lower placement', (
    tester,
  ) async {
    const emptyText = '暂无外协项目（未关联外协包导入后将自动出现）';

    await tester.pumpWidget(
      _localizedMaterialApp(
        home: Scaffold(
          body: AccountProjectList(
            projects: const [],
            onTap: (_) {},
            emptyText: emptyText,
          ),
        ),
      ),
    );

    final emptyHint = tester.widget<Text>(find.text(emptyText));
    expect(emptyHint.style?.fontSize, AccountTokens.projectEmptyStateFontSize);
    expect(
      tester.getCenter(find.text(emptyText)).dy,
      moreOrLessEquals(AccountTokens.projectEmptyStateHeight / 2),
    );
  });

  testWidgets('renders total hours in bold on account project cards', (
    tester,
  ) async {
    const project = AccountProjectVM(
      projectKey: 'zhao-shangyi',
      displayName: '赵六 + 尚义',
      minYmd: 20260317,
      deviceIds: [1],
      hoursByDevice: {1: 9},
      externalWorkHours: 1.5,
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
      _localizedMaterialApp(
        home: Scaffold(
          body: AccountProjectList(projects: const [project], onTap: (_) {}),
        ),
      ),
    );

    expect(find.text('赵六 · 尚义'), findsOneWidget);
    expect(find.text('赵六 + 尚义'), findsNothing);
    final totalHoursText = tester.widget<Text>(find.text('总共:  10.5 h'));

    expect(totalHoursText.style?.fontWeight, FontWeight.w700);
  });

  testWidgets(
    'normal project card shows worklog export icon before total hours',
    (tester) async {
      const project = AccountProjectVM(
        projectKey: 'zhao-shangyi',
        displayName: '赵六 · 尚义',
        minYmd: 20260317,
        deviceIds: [1],
        hoursByDevice: {1: 9},
        externalWorkHours: 1.5,
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
      AccountProjectVM? exported;
      var openedDetail = false;

      await tester.pumpWidget(
        _localizedMaterialApp(
          home: Scaffold(
            body: AccountProjectList(
              projects: const [project],
              onTap: (_) => openedDetail = true,
              onExportWorklog: (project) => exported = project,
              canExportWorklog: (_) => true,
            ),
          ),
        ),
      );

      expect(find.text('总共:  10.5 h'), findsOneWidget);
      expect(find.byTooltip('导出工时表'), findsOneWidget);
      expect(find.byIcon(Icons.file_upload_outlined), findsOneWidget);

      final totalLeft = tester.getTopLeft(find.text('总共:  10.5 h')).dx;
      final exportRight = tester
          .getTopRight(
            find.byKey(const Key('account-project-worklog-export-button')),
          )
          .dx;
      expect((totalLeft - exportRight).abs(), lessThanOrEqualTo(1));

      await tester.tap(
        find.byKey(const Key('account-project-worklog-export-button')),
      );

      expect(exported?.projectKey, 'zhao-shangyi');
      expect(openedDetail, isFalse);
    },
  );

  testWidgets(
    'merged project card shows worklog export icon before total hours',
    (tester) async {
      const project = AccountProjectVM(
        projectKey: 'merge:1',
        displayName: '赵六 · 合并2项目',
        kind: AccountProjectKind.merged,
        mergeGroupId: 1,
        memberProjectIds: ['member-a', 'member-b'],
        memberProjectKeys: ['赵六||尚义', '赵六||鲜滩'],
        includedSites: ['尚义', '鲜滩'],
        minYmd: 20260317,
        deviceIds: [1],
        hoursByDevice: {1: 12},
        rentIncomeTotal: 0,
        minRate: 120,
        isMultiDevice: false,
        isMultiMode: false,
        receivable: 1440,
        received: 1000,
        remaining: 440,
        ratio: 0.694,
        payments: [],
      );
      AccountProjectVM? exported;

      await tester.pumpWidget(
        _localizedMaterialApp(
          home: Scaffold(
            body: AccountProjectList(
              projects: const [project],
              onTap: (_) {},
              onExportWorklog: (project) => exported = project,
              canExportWorklog: (_) => true,
            ),
          ),
        ),
      );

      expect(find.text('总共:  12 h'), findsOneWidget);
      expect(find.byTooltip('导出工时表'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('account-project-worklog-export-button')),
      );

      expect(exported?.kind, AccountProjectKind.merged);
      expect(exported?.memberProjectIds, ['member-a', 'member-b']);
    },
  );

  testWidgets('project card hides export icon when no local worklog exists', (
    tester,
  ) async {
    const project = AccountProjectVM(
      projectKey: 'external-only',
      displayName: '赵六 · 尚义',
      minYmd: 20260317,
      deviceIds: [],
      hoursByDevice: {},
      externalWorkHours: 10,
      rentIncomeTotal: 0,
      minRate: 120,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 1080,
      received: 0,
      remaining: 1080,
      ratio: 0,
      payments: [],
    );

    await tester.pumpWidget(
      _localizedMaterialApp(
        home: Scaffold(
          body: AccountProjectList(
            projects: const [project],
            onTap: (_) {},
            onExportWorklog: (_) {},
            canExportWorklog: (_) => false,
          ),
        ),
      ),
    );

    expect(find.text('总共:  10 h'), findsOneWidget);
    expect(find.byTooltip('导出工时表'), findsNothing);
  });

  testWidgets('settled project card hides worklog export icon', (tester) async {
    const project = AccountProjectVM(
      projectKey: 'settled-with-worklog',
      displayName: '刘锐 · 五里山',
      isSettled: true,
      minYmd: 20260501,
      deviceIds: [1],
      hoursByDevice: {1: 7},
      rentIncomeTotal: 0,
      minRate: 180,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 1260,
      received: 1260,
      remaining: 0,
      ratio: 1,
      payments: [],
    );
    AccountProjectVM? exported;

    await tester.pumpWidget(
      _localizedMaterialApp(
        home: Scaffold(
          body: AccountProjectList(
            projects: const [project],
            onTap: (_) {},
            onExportWorklog: (project) => exported = project,
            canExportWorklog: (_) => true,
          ),
        ),
      ),
    );

    expect(find.text('总共:  7 h'), findsOneWidget);
    expect(_settledCheckIcons(), findsOneWidget);
    expect(find.byTooltip('导出工时表'), findsNothing);
    expect(exported, isNull);
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
        _localizedMaterialApp(
          home: Scaffold(
            body: AccountProjectList(projects: const [project], onTap: (_) {}),
          ),
        ),
      );

      expect(find.text('赵六 · 合并2项目'), findsOneWidget);
      expect(find.text('92.6%实收('), findsOneWidget);
      expect(find.text('尚义、鲜滩'), findsOneWidget);
      expect(find.text(')'), findsOneWidget);
    },
  );

  testWidgets('linked external work uses chain icon instead of title copy', (
    tester,
  ) async {
    const project = AccountProjectVM(
      projectKey: 'linked',
      displayName: '李洋•天眉乐 + 关联',
      hasLinkedExternalWork: true,
      minYmd: 20260521,
      deviceIds: [1],
      hoursByDevice: {1: 8.1},
      rentIncomeTotal: 0,
      minRate: 180,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 1458,
      received: 0,
      remaining: 1458,
      ratio: 0,
      payments: [],
    );

    await tester.pumpWidget(
      _localizedMaterialApp(
        home: Scaffold(
          body: AccountProjectList(projects: const [project], onTap: (_) {}),
        ),
      ),
    );

    expect(find.text('李洋 · 天眉乐'), findsOneWidget);
    expect(find.textContaining('+ 关联'), findsNothing);
    expect(find.textContaining('•'), findsNothing);
    expect(find.byTooltip('已关联外协记录'), findsOneWidget);
    expect(_settledCheckIcons(), findsNothing);
  });

  testWidgets('active fully received project keeps settled display style', (
    tester,
  ) async {
    const project = AccountProjectVM(
      projectKey: 'fully-received',
      displayName: '李洋 · 天眉乐',
      minYmd: 20260521,
      deviceIds: [1],
      hoursByDevice: {1: 8.1},
      rentIncomeTotal: 0,
      minRate: 180,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 1458,
      received: 1458,
      remaining: 0,
      ratio: 1,
      payments: [],
    );

    await tester.pumpWidget(
      _localizedMaterialApp(
        home: Scaffold(
          body: AccountProjectList(projects: const [project], onTap: (_) {}),
        ),
      ),
    );

    expect(_settledCheckIcons(), findsOneWidget);
    expect(find.text('已结清'), findsOneWidget);
    expect(find.text('余: ¥0 / ¥1458'), findsNothing);

    final progressWidthFactors = _progressWidthFactors(tester);
    expect(progressWidthFactors, hasLength(1));
    expect(progressWidthFactors.single, 1.0);
  });

  testWidgets('zero total active project does not show settled display style', (
    tester,
  ) async {
    const project = AccountProjectVM(
      projectKey: 'empty',
      displayName: '李洋 · 天眉乐',
      minYmd: 20260521,
      deviceIds: [1],
      hoursByDevice: {},
      rentIncomeTotal: 0,
      minRate: null,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 0,
      received: 0,
      remaining: 0,
      ratio: null,
      payments: [],
    );

    await tester.pumpWidget(
      _localizedMaterialApp(
        home: Scaffold(
          body: AccountProjectList(projects: const [project], onTap: (_) {}),
        ),
      ),
    );

    expect(_settledCheckIcons(), findsNothing);
    expect(_settledCelebrationIcons(), findsNothing);
    expect(find.text('已结清'), findsNothing);
    expect(find.text('余: ¥0 / ¥0'), findsOneWidget);

    final progressWidthFactors = _progressWidthFactors(tester);
    expect(progressWidthFactors, hasLength(1));
    expect(progressWidthFactors.single, 0);
  });

  testWidgets(
    'linked settled project shows chain and settled status in normal mode',
    (tester) async {
      const project = AccountProjectVM(
        projectKey: 'linked-settled',
        displayName: '李洋 · 天眉乐',
        isSettled: true,
        hasLinkedExternalWork: true,
        minYmd: 20260521,
        deviceIds: [1],
        hoursByDevice: {1: 8.1},
        rentIncomeTotal: 0,
        minRate: 180,
        isMultiDevice: false,
        isMultiMode: false,
        receivable: 2358,
        received: 1458,
        remaining: 900,
        ratio: 1458 / 2358,
        payments: [],
      );
      AccountProjectVM? tapped;

      await tester.pumpWidget(
        _localizedMaterialApp(
          home: Scaffold(
            body: AccountProjectList(
              projects: const [project],
              onTap: (project) => tapped = project,
            ),
          ),
        ),
      );

      expect(find.byTooltip('已关联外协记录'), findsOneWidget);
      expect(_settledCheckIcons(), findsOneWidget);
      expect(_settledCelebrationIcons(), findsOneWidget);
      expect(find.text('已结清'), findsOneWidget);
      expect(find.text('总额 ¥2358'), findsOneWidget);
      expect(find.text('余: ¥900 / ¥2358'), findsNothing);

      final progressWidthFactors = _progressWidthFactors(tester);
      expect(progressWidthFactors, hasLength(1));
      expect(progressWidthFactors.single, 1.0);

      await tester.tap(find.text('李洋 · 天眉乐'));
      await tester.pump();
      expect(tapped?.remaining, 900);
      expect(tapped?.ratio, closeTo(1458 / 2358, 0.0001));
    },
  );

  testWidgets(
    'linked settled project shows chain and settled status in compact mode',
    (tester) async {
      const project = AccountProjectVM(
        projectKey: 'linked-settled',
        displayName: '李洋 · 天眉乐',
        isSettled: true,
        hasLinkedExternalWork: true,
        minYmd: 20260521,
        deviceIds: [1],
        hoursByDevice: {1: 8.1},
        rentIncomeTotal: 0,
        minRate: 180,
        isMultiDevice: false,
        isMultiMode: false,
        receivable: 2358,
        received: 1458,
        remaining: 900,
        ratio: 1458 / 2358,
        payments: [],
      );

      await tester.pumpWidget(
        _localizedMaterialApp(
          home: Scaffold(
            body: AccountProjectList(
              projects: const [project],
              isCompact: true,
              onTap: (_) {},
            ),
          ),
        ),
      );

      expect(find.byTooltip('已关联外协记录'), findsOneWidget);
      expect(_settledCheckIcons(), findsOneWidget);
      expect(_settledCelebrationIcons(), findsOneWidget);
      expect(find.text('已结清'), findsOneWidget);
      expect(find.text('待收 ¥900'), findsNothing);

      final progressWidthFactors = _progressWidthFactors(tester);
      expect(progressWidthFactors, hasLength(1));
      expect(progressWidthFactors.single, 1.0);
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
      _localizedMaterialApp(
        home: Scaffold(
          body: AccountProjectList(projects: const [project], onTap: (_) {}),
        ),
      ),
    );

    expect(find.text('台班(租金)'), findsOneWidget);
    expect(find.text('单价:—'), findsNothing);
    expect(find.text('总共:  0 h'), findsNothing);
  });

  testWidgets('shows settled card text without pending amount', (tester) async {
    const cashSettled = AccountProjectVM(
      projectKey: 'cash',
      displayName: '甲方 + 现金结清',
      isSettled: true,
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
      isSettled: true,
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
      _localizedMaterialApp(
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
    expect(_recordCardContainers(), findsNWidgets(3));
    expect(_containerWithBorder(const Color(0x4D000000)), findsNothing);
    expect(_settledCelebrationIcons(), findsNWidgets(2));

    final settledIcons = tester.widgetList<Icon>(_settledCheckIcons()).toList();
    expect(settledIcons, hasLength(2));
    expect(
      settledIcons.every((icon) => icon.color == const Color(0xFF4AAFD8)),
      isTrue,
    );

    final progressWidthFactors = _progressWidthFactors(tester);
    expect(progressWidthFactors, hasLength(3));
    expect(progressWidthFactors[0], 1.0);
    expect(progressWidthFactors[1], 1.0);
    expect(progressWidthFactors[2], closeTo(1200 / 1260, 0.0001));
  });

  testWidgets('settled check keeps long project title and date in one row', (
    tester,
  ) async {
    const project = AccountProjectVM(
      projectKey: 'long-settled',
      displayName: '特别特别长的联系人名称 + 特别特别长的项目地址名称',
      isSettled: true,
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
      _localizedMaterialApp(
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
      _localizedMaterialApp(
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
      tester.widget<Text>(find.text('台班(租金)')).style?.color,
      SheetColors.actionOn,
    );

    expect(_badgeWithColor(const Color(0xFFEAF2FA)), findsOneWidget);
    expect(_badgeWithColor(const Color(0xFFF1EDFF)), findsOneWidget);
    expect(_badgeWithColor(AppColors.brand), findsOneWidget);
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
      _localizedMaterialApp(
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
    expect(find.text('台班(租金)'), findsNothing);
    expect(find.text('总共:  68 h'), findsNothing);
    expect(find.text('40.8%实收'), findsOneWidget);
    expect(find.text('项目总额 ¥12240'), findsOneWidget);
    expect(find.text('项目总额 ¥22000'), findsOneWidget);
    expect(find.text('待收 ¥7240'), findsOneWidget);
    expect(find.text('待收 ¥22000'), findsOneWidget);
    expect(find.text('余: ¥7240 / ¥12240'), findsNothing);
    expect(find.text('余: ¥22000 / ¥22000'), findsNothing);
  });

  testWidgets('compact project card hides worklog export icon', (tester) async {
    const project = AccountProjectVM(
      projectKey: 'compact-export',
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
    AccountProjectVM? exported;

    await tester.pumpWidget(
      _localizedMaterialApp(
        home: Scaffold(
          body: AccountProjectList(
            projects: const [project],
            isCompact: true,
            onTap: (_) {},
            onExportWorklog: (project) => exported = project,
            canExportWorklog: (_) => true,
          ),
        ),
      ),
    );

    expect(find.text('总共:  68 h'), findsNothing);
    expect(find.byTooltip('导出工时表'), findsNothing);
    expect(find.byIcon(Icons.file_upload_outlined), findsNothing);
    expect(
      find.byKey(const Key('account-project-worklog-export-button')),
      findsNothing,
    );

    expect(exported, isNull);
  });

  testWidgets('compact settled cards show net received text', (tester) async {
    const cashSettled = AccountProjectVM(
      projectKey: 'cash',
      displayName: '甲方 + 现金结清',
      isSettled: true,
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
      isSettled: true,
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
      _localizedMaterialApp(
        home: Scaffold(
          body: AccountProjectList(
            projects: const [cashSettled, writeOffSettled, pending],
            isCompact: true,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('实收 ¥1200'), findsOneWidget);
    expect(find.text('总额 ¥1260-核销 ¥60'), findsNothing);
    expect(find.text('总额 ¥1260'), findsOneWidget);
    expect(find.text('已结清'), findsNWidgets(2));
    expect(find.text('项目总额 ¥1260'), findsNWidgets(3));
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

    final progressWidthFactors = _progressWidthFactors(tester);
    expect(progressWidthFactors, hasLength(3));
    expect(progressWidthFactors[0], 1.0);
    expect(progressWidthFactors[1], 1.0);
    expect(progressWidthFactors[2], closeTo(600 / 1260, 0.0001));
  });

  testWidgets('renders external work cards in green style', (tester) async {
    const externalProject = AccountExternalWorkProjectVM(
      importBatchId: 'external-batch-1',
      displayName: '余远 · 鲜滩、尚义',
      sourceDisplayName: '余远',
      siteSummary: '鲜滩、尚义',
      minYmd: 20260502,
      payableFen: 1261800,
      receivableFen: 1261800,
      profitFen: 0,
      recordCount: 2,
    );

    await tester.pumpWidget(
      _localizedMaterialApp(
        home: Scaffold(
          body: AccountProjectList(
            projects: const [],
            externalWorkProjects: const [externalProject],
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('外协项目'), findsNothing);
    expect(find.text('协'), findsOneWidget);
    expect(find.text('余远 · 鲜滩、尚义'), findsOneWidget);
    expect(find.text('外协应付'), findsOneWidget);
    expect(find.text('¥12618'), findsNWidgets(2));
    expect(find.text('应收项目款'), findsOneWidget);
    expect(find.text('客户应收'), findsNothing);
    expect(find.text('毛利'), findsOneWidget);
    expect(find.text('¥0'), findsOneWidget);
    expect(find.text('待设置'), findsNothing);
    expect(find.text('待计算'), findsNothing);

    expect(_containerWithColor(const Color(0xFFFFFFFF)), findsOneWidget);
    expect(_recordCardContainers(), findsOneWidget);
    expect(_containerWithBorder(const Color(0xFFD9EDE3)), findsNothing);
    expect(_containerWithColor(const Color(0xFFE4F4EA)), findsWidgets);
    expect(_containerWithColor(const Color(0xFF459A63)), findsOneWidget);
    expect(_containerWithColor(const Color(0xFFF06161)), findsOneWidget);

    final progressWidthFactors = _progressWidthFactors(tester);
    expect(progressWidthFactors, hasLength(1));
    expect(progressWidthFactors.single, 1.0);
  });

  testWidgets(
    'external work card shows real gross profit when customer rate set',
    (tester) async {
      const externalProject = AccountExternalWorkProjectVM(
        importBatchId: 'external-markup',
        displayName: '余远 · 五里山',
        sourceDisplayName: '余远',
        siteSummary: '五里山',
        minYmd: 20260617,
        payableFen: 180000,
        receivableFen: 200000,
        profitFen: 20000,
        customerUnitPriceFen: 20000,
        recordCount: 1,
      );

      await tester.pumpWidget(
        _localizedMaterialApp(
          home: Scaffold(
            body: AccountProjectList(
              projects: const [],
              externalWorkProjects: const [externalProject],
              onTap: (_) {},
            ),
          ),
        ),
      );

      // 设了客户单价 → 毛利显真实值 ¥200，不再"待计算"。
      expect(find.text('待计算'), findsNothing);
      expect(find.text('¥200'), findsOneWidget);
    },
  );

  testWidgets('tapping external work card fires onExternalTap', (tester) async {
    const externalProject = AccountExternalWorkProjectVM(
      importBatchId: 'external-tap',
      displayName: '余远 · 五里山',
      sourceDisplayName: '余远',
      siteSummary: '五里山',
      minYmd: 20260617,
      payableFen: 180000,
      receivableFen: 180000,
      recordCount: 1,
    );

    AccountExternalWorkProjectVM? tapped;
    await tester.pumpWidget(
      _localizedMaterialApp(
        home: Scaffold(
          body: AccountProjectList(
            projects: const [],
            externalWorkProjects: const [externalProject],
            onTap: (_) {},
            onExternalTap: (p) => tapped = p,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const Key('account-external-work-card-external-tap')),
    );
    expect(tapped?.importBatchId, 'external-tap');
  });

  testWidgets('external work payable progress shrinks red bar from the right', (
    tester,
  ) async {
    const externalProject = AccountExternalWorkProjectVM(
      importBatchId: 'external-paid-progress',
      displayName: '张俊 · 天眉乐',
      sourceDisplayName: '张俊',
      siteSummary: '天眉乐',
      minYmd: 20260521,
      payableFen: 1261800,
      paidFen: 630900,
      recordCount: 2,
    );

    await tester.pumpWidget(
      _localizedMaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: AccountProjectList(
              projects: const [],
              externalWorkProjects: const [externalProject],
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );

    final unpaidBar = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(unpaidBar.widthFactor, closeTo(0.5, 0.0001));
    expect(unpaidBar.alignment, Alignment.centerLeft);

    final greenRect = tester.getRect(
      _containerWithColor(const Color(0xFF459A63)),
    );
    final redRect = tester.getRect(
      _containerWithColor(const Color(0xFFF06161)),
    );
    expect(redRect.left, greenRect.left);
    expect(redRect.right, lessThan(greenRect.right));
  });

  testWidgets(
    'external work title stays beside avatar and truncates before date',
    (tester) async {
      const longName = '余远 · 尚义、富牛、鲜滩、天眉乐、特别特别长的地址';
      const externalProject = AccountExternalWorkProjectVM(
        importBatchId: 'external-long-title',
        displayName: longName,
        sourceDisplayName: '余远',
        siteSummary: '尚义、富牛、鲜滩、天眉乐、特别特别长的地址',
        minYmd: 20260502,
        payableFen: 1261800,
        receivableFen: 1261800,
        recordCount: 2,
      );

      await tester.pumpWidget(
        _localizedMaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 260,
              child: AccountProjectList(
                projects: const [],
                externalWorkProjects: const [externalProject],
                onTap: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      final title = tester.widget<Text>(find.text(longName));
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(find.text('2026.05.02'), findsOneWidget);
      expect(find.text('外协应付'), findsOneWidget);
      expect(find.text('应收项目款'), findsOneWidget);
      expect(find.text('毛利'), findsOneWidget);

      final avatarRect = tester.getRect(find.text('协'));
      final titleRect = tester.getRect(find.text(longName));
      final dateRect = tester.getRect(find.text('2026.05.02'));

      expect(titleRect.left, greaterThan(avatarRect.right));
      expect(titleRect.right, lessThan(dateRect.left));
      expect((titleRect.center.dy - avatarRect.center.dy).abs(), lessThan(8));
      expect((titleRect.center.dy - dateRect.center.dy).abs(), lessThan(8));
    },
  );

  testWidgets('external work card matches project card height and avatar top', (
    tester,
  ) async {
    const project = AccountProjectVM(
      projectKey: 'owned',
      displayName: '李杰 + 新村',
      minYmd: 20260501,
      deviceIds: [1],
      hoursByDevice: {1: 10},
      rentIncomeTotal: 0,
      minRate: 100,
      isMultiDevice: false,
      isMultiMode: false,
      receivable: 1000,
      received: 0,
      remaining: 1000,
      ratio: 0,
      payments: [],
    );
    const externalProject = AccountExternalWorkProjectVM(
      importBatchId: 'external-batch-height',
      displayName: '余远 · 鲜滩、尚义',
      sourceDisplayName: '余远',
      siteSummary: '鲜滩、尚义',
      minYmd: 20260502,
      payableFen: 1261800,
      recordCount: 2,
    );

    await tester.pumpWidget(
      _localizedMaterialApp(
        home: Scaffold(
          body: AccountProjectList(
            projects: const [project],
            externalWorkProjects: const [externalProject],
            onTap: (_) {},
          ),
        ),
      ),
    );

    final projectCards = _recordCardContainers();
    expect(projectCards, findsNWidgets(2));
    final ownedCardRect = tester.getRect(projectCards.first);
    final externalCardRect = tester.getRect(
      find.byKey(const Key('account-external-work-card-external-batch-height')),
    );
    final avatarRect = tester.getRect(
      find.byKey(const Key('account-external-work-avatar')),
    );

    expect(externalCardRect.height, ownedCardRect.height);
    expect(avatarRect.top - externalCardRect.top, 4);
    expect(
      find.descendant(
        of: find.byKey(
          const Key('account-external-work-card-external-batch-height'),
        ),
        matching: _paddingWithBottom(6),
      ),
      findsOneWidget,
    );
  });

  testWidgets('project header toggles compact mode from title group only', (
    tester,
  ) async {
    var toggleCount = 0;
    var trailingTapCount = 0;

    await tester.pumpWidget(
      _localizedMaterialApp(
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
    expect(_projectHeaderBottomBorder(), findsNothing);
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
      _localizedMaterialApp(
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
    expect(_projectHeaderBottomBorder(), findsNothing);
    expect(_densityLinesWithColor(AppColors.textPrimary), findsNWidgets(3));
  });

  testWidgets('project action buttons keep size and use stronger weight', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedMaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AccountProjectMergeButton(onPressed: _noop),
              AccountProjectFilterButton(
                hasActiveFilter: false,
                onOpenFilter: _noop,
                onClearFilter: _noop,
              ),
            ],
          ),
        ),
      ),
    );

    final mergeText = tester.widget<Text>(find.text('合并'));
    final filterText = tester.widget<Text>(find.text('筛选'));
    final mergeIcon = tester.widget<Icon>(
      find.byIcon(Icons.call_merge_outlined),
    );
    final filterIcon = tester.widget<Icon>(
      find.byIcon(Icons.filter_alt_outlined),
    );

    expect(mergeText.style?.fontSize, 15);
    expect(mergeText.style?.fontWeight, FontWeight.w600);
    expect(filterText.style?.fontSize, 15);
    expect(filterText.style?.fontWeight, FontWeight.w600);
    expect(mergeIcon.size, 16);
    expect(mergeIcon.weight, 700);
    expect(filterIcon.size, 16);
    expect(filterIcon.weight, 700);
  });
}

Widget _localizedMaterialApp({required Widget home}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
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

Finder _recordCardContainers() {
  return find.byWidgetPredicate((widget) {
    final decoration = widget is Container ? widget.decoration : null;
    return decoration is BoxDecoration &&
        decoration.color == SheetColors.background &&
        decoration.border == null &&
        decoration.borderRadius ==
            BorderRadius.circular(RadiusTokens.recordCard) &&
        decoration.boxShadow == null;
  });
}

Finder _paddingWithBottom(double bottom) {
  return find.byWidgetPredicate((widget) {
    return widget is Padding &&
        widget.padding.resolve(TextDirection.ltr).bottom == bottom;
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

Finder _projectHeaderBottomBorder() {
  return find.byWidgetPredicate((widget) {
    final decoration = widget is Container ? widget.decoration : null;
    if (decoration is! BoxDecoration || decoration.border is! Border) {
      return false;
    }

    final border = decoration.border! as Border;
    return border.bottom.color == AppColors.divider &&
        border.bottom.width == 0.5;
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

List<double> _progressWidthFactors(WidgetTester tester) {
  return tester
      .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
      .map((widget) => widget.widthFactor ?? 0)
      .toList(growable: false);
}
