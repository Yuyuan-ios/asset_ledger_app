import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/patterns/account/account_project_card_vm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 普通项目 fixture：未结清、单设备、单价 180、应收 1800。
  AccountProjectVM project({
    String displayName = '李杰 + 五里山',
    AccountProjectKind kind = AccountProjectKind.normal,
    List<String> includedSites = const [],
    Map<int, double> hoursByDevice = const {1: 10},
    double externalWorkHours = 0,
    double? minRate = 180,
    bool isMultiDevice = false,
    bool isMultiMode = false,
    double rentIncomeTotal = 0,
    double receivable = 1800,
    double received = 0,
    double writeOff = 0,
    double remaining = 1800,
    double? ratio = 0,
    bool? isSettledForDisplay,
    bool isSettled = false,
    bool hasLinkedExternalWork = false,
  }) {
    return AccountProjectVM(
      projectKey: 'k',
      displayName: displayName,
      kind: kind,
      includedSites: includedSites,
      isSettled: isSettled,
      isSettledForDisplay: isSettledForDisplay,
      hasLinkedExternalWork: hasLinkedExternalWork,
      minYmd: 20260501,
      deviceIds: hoursByDevice.keys.toList(),
      hoursByDevice: hoursByDevice,
      externalWorkHours: externalWorkHours,
      rentIncomeTotal: rentIncomeTotal,
      minRate: minRate,
      isMultiDevice: isMultiDevice,
      isMultiMode: isMultiMode,
      receivable: receivable,
      received: received,
      writeOff: writeOff,
      remaining: remaining,
      ratio: ratio,
      payments: const [],
    );
  }

  AccountProjectCardVm build(
    AccountProjectVM p, {
    bool isCompact = false,
  }) {
    return AccountProjectCardVmBuilder.build(project: p, isCompact: isCompact);
  }

  group('title', () {
    test('normalizes display name (plus → separator)', () {
      expect(build(project(displayName: '李杰 + 五里山')).titleText, '李杰 · 五里山');
    });
  });

  group('settled', () {
    test('settled project shows 已结清 and full progress', () {
      final vm = build(
        project(received: 1800, remaining: 0, ratio: 1, isSettled: true),
      );
      expect(vm.isSettled, isTrue);
      expect(vm.settlementStatusText, '已结清');
      expect(vm.displayProgress, 1.0);
    });

    test('display-settled derives from finance even when not status-settled', () {
      // receivable - received - writeOff <= eps → isSettledForDisplay true。
      final vm = build(project(received: 1800, remaining: 0, ratio: 1));
      expect(vm.isSettled, isTrue);
      expect(vm.settlementStatusText, '已结清');
    });
  });

  group('unsettled settlement status', () {
    test('normal mode shows 余: remaining / receivable', () {
      final vm = build(project(remaining: 1800, ratio: 0));
      expect(vm.settlementStatusText, '余: ¥1800 / ¥1800');
      expect(vm.displayProgress, 0.0);
    });

    test('compact mode shows 待收 remaining', () {
      final vm = build(
        project(receivable: 12240, remaining: 7240, ratio: 0.408),
        isCompact: true,
      );
      expect(vm.settlementStatusText, '待收 ¥7240');
    });
  });

  group('receivedBaseText', () {
    test('unsettled shows percent received', () {
      expect(build(project(ratio: 0.408)).receivedBaseText, '40.8%实收');
    });

    test('settled without write-off shows 总额', () {
      final vm = build(project(received: 1800, remaining: 0, ratio: 1));
      expect(vm.receivedBaseText, '总额 ¥1800');
    });

    test('settled with write-off (normal) shows 总额-核销', () {
      final vm = build(
        project(
          receivable: 1260,
          received: 1200,
          writeOff: 60,
          remaining: 0,
          ratio: 1200 / 1260,
        ),
      );
      expect(vm.receivedBaseText, '总额 ¥1260-核销 ¥60');
    });

    test('settled with write-off (compact) shows net 实收', () {
      final vm = build(
        project(
          receivable: 1260,
          received: 1200,
          writeOff: 60,
          remaining: 0,
          ratio: 1200 / 1260,
        ),
        isCompact: true,
      );
      expect(vm.receivedBaseText, '实收 ¥1200');
    });
  });

  group('mergedSitesSuffix', () {
    test('merged unsettled joins included sites', () {
      final vm = build(
        project(
          kind: AccountProjectKind.merged,
          includedSites: const ['尚义', '鲜滩'],
          remaining: 1800,
          ratio: 0,
        ),
      );
      expect(vm.mergedSitesSuffix, '尚义、鲜滩');
    });

    test('normal project has no sites suffix', () {
      expect(build(project()).mergedSitesSuffix, isNull);
    });

    test('merged but settled suppresses suffix', () {
      final vm = build(
        project(
          kind: AccountProjectKind.merged,
          includedSites: const ['尚义', '鲜滩'],
          received: 1800,
          remaining: 0,
          ratio: 1,
          isSettled: true,
        ),
      );
      expect(vm.mergedSitesSuffix, isNull);
    });
  });

  group('priceText / priceBadgeKind', () {
    test('single device', () {
      final vm = build(project(minRate: 180));
      expect(vm.priceText, '单价:¥180');
      expect(vm.priceBadgeKind, AccountProjectPriceBadgeKind.single);
    });

    test('multi device', () {
      final vm = build(project(minRate: 180, isMultiDevice: true));
      expect(vm.priceText, '单价:¥180(多设备)');
      expect(vm.priceBadgeKind, AccountProjectPriceBadgeKind.multi);
    });

    test('multi mode (起)', () {
      final vm = build(project(minRate: 180, isMultiMode: true));
      expect(vm.priceText, '单价:¥180起(多模式)');
      expect(vm.priceBadgeKind, AccountProjectPriceBadgeKind.multi);
    });

    test('rent (no rate, rent income)', () {
      final vm = build(
        project(minRate: null, rentIncomeTotal: 22000, hoursByDevice: const {}),
      );
      expect(vm.priceText, '租金(台班)');
      expect(vm.priceBadgeKind, AccountProjectPriceBadgeKind.rent);
    });

    test('rent kind wins even with a concrete rate (no string re-parse)', () {
      // 关键回归：原逻辑 rentIncomeTotal>0 优先于文案。这里 rate 非空，
      // priceText 不含“租金”，但仍应判定为 rent。
      final vm = build(project(minRate: 180, rentIncomeTotal: 5000));
      expect(vm.priceText, '单价:¥180');
      expect(vm.priceBadgeKind, AccountProjectPriceBadgeKind.rent);
    });

    test('no rate, no rent shows 单价:—, single badge', () {
      final vm = build(
        project(minRate: null, rentIncomeTotal: 0, hoursByDevice: const {}),
      );
      expect(vm.priceText, '单价:—');
      expect(vm.priceBadgeKind, AccountProjectPriceBadgeKind.single);
    });
  });

  group('totalHoursText', () {
    test('sums device hours and external work hours, trims .0', () {
      final vm = build(
        project(hoursByDevice: const {1: 18, 2: 50}, externalWorkHours: 0),
      );
      expect(vm.totalHoursText, '总共:  68 h');
    });

    test('keeps one decimal when fractional', () {
      final vm = build(project(hoursByDevice: const {1: 64.9}));
      expect(vm.totalHoursText, '总共:  64.9 h');
    });

    test('null when total hours is zero', () {
      final vm = build(
        project(hoursByDevice: const {}, externalWorkHours: 0),
      );
      expect(vm.totalHoursText, isNull);
    });
  });

  group('passthrough', () {
    test('hasLinkedExternalWork is forwarded', () {
      expect(build(project(hasLinkedExternalWork: true)).hasLinkedExternalWork,
          isTrue);
      expect(build(project()).hasLinkedExternalWork, isFalse);
    });

    test('topRightText: normal shows date, compact shows 项目总额', () {
      expect(build(project()).topRightText, '2026.05.01');
      expect(
        build(project(receivable: 12240), isCompact: true).topRightText,
        '项目总额 ¥12240',
      );
    });
  });
}
