import '../../core/utils/format_utils.dart';
import '../../features/account/model/account_view_model.dart';
import '../../features/account/model/project_title_formatter.dart';

/// 阶段 C Step 12：普通项目卡片的展示派生从 [AccountProjectList] pattern
/// 上移到此处，让 pattern 只剩布局 + token 配色 + widget 组装。
///
/// builder 是纯只读映射：不读写数据库、不调用 repository / use case、
/// 不改 [AccountProjectVM]、不碰金额权威口径，只把已算好的项目 VM 折算成
/// 一张普通项目卡片需要展示的字符串 / 状态字段。
///
/// 仅服务普通项目卡片；外协项目卡片（[AccountExternalWorkProjectVM]）不在此
/// 范围内。
enum AccountProjectPriceBadgeKind { single, multi, rent }

class AccountProjectCardVm {
  const AccountProjectCardVm({
    required this.project,
    required this.titleText,
    required this.priceText,
    required this.priceBadgeKind,
    required this.totalHoursText,
    required this.receivedBaseText,
    required this.mergedSitesSuffix,
    required this.settlementStatusText,
    required this.displayProgress,
    required this.topRightText,
    required this.isSettled,
    required this.hasLinkedExternalWork,
  });

  /// 命中的项目，供 onTap 透传 / 边框等 UI 直接读取。
  final AccountProjectVM project;
  final String titleText;
  final String priceText;
  final AccountProjectPriceBadgeKind priceBadgeKind;

  /// 总工时文案；无工时（合计 <= 0）时为 null（不渲染该行）。
  final String? totalHoursText;

  /// 左下角实收 / 总额 / 核销 / 实收占比文案。
  final String receivedBaseText;

  /// 合并项目未结清时展示的地址后缀（如“尚义、鲜滩”）；不适用时为 null。
  final String? mergedSitesSuffix;

  /// 右下角结清状态文案（已结清 / 待收 / 余）。
  final String settlementStatusText;

  /// 进度条填充比例（已结清恒为 1）。
  final double displayProgress;

  /// 右上角文案：compact 显示“项目总额 ¥…”，否则显示最早计时日期。
  final String topRightText;

  final bool isSettled;
  final bool hasLinkedExternalWork;
}

class AccountProjectCardVmBuilder {
  const AccountProjectCardVmBuilder._();

  static const double _moneyEpsilon = 0.000001;

  static AccountProjectCardVm build({
    required AccountProjectVM project,
    required bool isCompact,
  }) {
    final isSettled = project.isSettledForDisplay;
    return AccountProjectCardVm(
      project: project,
      titleText: ProjectTitleFormatter.normalize(project.displayName),
      priceText: _priceText(project),
      priceBadgeKind: _priceBadgeKind(project),
      totalHoursText: _totalHoursText(project),
      receivedBaseText: _receivedBaseText(project, compact: isCompact),
      mergedSitesSuffix: _mergedSitesSuffix(project, isSettled: isSettled),
      settlementStatusText: _settlementStatusText(project, compact: isCompact),
      displayProgress: isSettled
          ? 1.0
          : (project.ratio ?? 0).clamp(0.0, 1.0).toDouble(),
      topRightText: isCompact
          ? '项目总额 ${FormatUtils.money(project.receivable)}'
          : FormatUtils.date(project.minYmd),
      isSettled: isSettled,
      hasLinkedExternalWork: project.hasLinkedExternalWork,
    );
  }

  static String _priceText(AccountProjectVM p) {
    final rate = p.minRate;
    if (rate == null) {
      if (p.rentIncomeTotal > 0) return '台班(租金)';
      return '单价:—';
    }
    if (p.isMultiDevice) {
      return '单价:${FormatUtils.money(rate)}(多设备)';
    }
    if (p.isMultiMode) {
      return '单价:${FormatUtils.money(rate)}起(多模式)';
    }
    return '单价:${FormatUtils.money(rate)}';
  }

  /// 徽章类型直接从 [AccountProjectVM] 字段判定，行为与原 pattern 的
  /// `priceText.contains(...)` 反解析等价（rent 优先于 multi 优先于 single），
  /// 但不再依赖文案字符串。
  static AccountProjectPriceBadgeKind _priceBadgeKind(AccountProjectVM p) {
    if (p.rentIncomeTotal > 0) {
      return AccountProjectPriceBadgeKind.rent;
    }
    if (p.isMultiDevice || p.isMultiMode) {
      return AccountProjectPriceBadgeKind.multi;
    }
    return AccountProjectPriceBadgeKind.single;
  }

  static String? _totalHoursText(AccountProjectVM p) {
    final total =
        p.hoursByDevice.values.fold<double>(0, (sum, h) => sum + h) +
        p.externalWorkHours;
    if (total <= 0) return null;
    final one = total.toStringAsFixed(1);
    final normalized = one.endsWith('.0')
        ? one.substring(0, one.length - 2)
        : one;
    return '总共:  $normalized h';
  }

  static String _receivedBaseText(AccountProjectVM p, {required bool compact}) {
    if (p.isSettledForDisplay) {
      if (p.writeOff > _moneyEpsilon) {
        if (compact) {
          final netReceived = (p.receivable - p.writeOff).clamp(
            0.0,
            p.receivable,
          );
          return '实收 ${FormatUtils.money(netReceived)}';
        }
        return '总额 ${FormatUtils.money(p.receivable)}-核销 ${FormatUtils.money(p.writeOff)}';
      }
      return '总额 ${FormatUtils.money(p.receivable)}';
    }
    return '${FormatUtils.percent1(p.ratio)}实收';
  }

  /// 合并项目未结清时的地址后缀；不适用或为空时返回 null（pattern 不渲染括号）。
  static String? _mergedSitesSuffix(
    AccountProjectVM p, {
    required bool isSettled,
  }) {
    if (isSettled || p.kind != AccountProjectKind.merged) return null;
    final joined = p.includedSites
        .map((site) => site.trim())
        .where((site) => site.isNotEmpty)
        .join('、');
    return joined.isEmpty ? null : joined;
  }

  static String _settlementStatusText(
    AccountProjectVM p, {
    required bool compact,
  }) {
    if (p.isSettledForDisplay) {
      return '已结清';
    }
    return compact
        ? '待收 ${FormatUtils.money(p.remaining)}'
        : '余: ${FormatUtils.money(p.remaining)} / ${FormatUtils.money(p.receivable)}';
  }
}
