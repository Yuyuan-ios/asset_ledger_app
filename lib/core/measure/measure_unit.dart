/// 计量单位枚举（《机账通商业与实现纲要》§3 / §10.3）。
///
/// 枚举值是数据,永不翻译;UI 显示 label 走本地化。一条记录只允许一个 unit,
/// 混合计费用多条记录表达。MU / ACRE / HECTARE 为三个独立枚举,按地区选择,
/// 互不自动换算(方案 B),保证跨语言对账一致。
enum MeasureUnit {
  /// 工时（挖机、装载机等按小时;有码表辅助）。
  hour,

  /// 台班。
  shift,

  /// 天 / 包天。
  day,

  /// 租期（周租/月租/包段）。
  rent,

  /// 亩（华语区面积,植保等）。
  mu,

  /// 英亩（英美区面积）。
  acre,

  /// 公顷（公制区面积）。
  hectare,

  /// 吨（吊装按重量）。
  ton,

  /// 方（渣土/运输按方量）。
  cubicMeter,

  /// 趟次（运输、吊装按趟）。
  trip,

  /// 架次（无人机）。
  sortie,

  /// 任务包（巡检/机器人）。
  task,
}

extension MeasureUnitX on MeasureUnit {
  /// 持久化/分享包中的稳定标识,跨语言不变。
  String get dbValue {
    switch (this) {
      case MeasureUnit.hour:
        return 'HOUR';
      case MeasureUnit.shift:
        return 'SHIFT';
      case MeasureUnit.day:
        return 'DAY';
      case MeasureUnit.rent:
        return 'RENT';
      case MeasureUnit.mu:
        return 'MU';
      case MeasureUnit.acre:
        return 'ACRE';
      case MeasureUnit.hectare:
        return 'HECTARE';
      case MeasureUnit.ton:
        return 'TON';
      case MeasureUnit.cubicMeter:
        return 'CUBIC_METER';
      case MeasureUnit.trip:
        return 'TRIP';
      case MeasureUnit.sortie:
        return 'SORTIE';
      case MeasureUnit.task:
        return 'TASK';
    }
  }
}

class MeasureUnitCodec {
  const MeasureUnitCodec._();

  /// 防御式解析:未知值返回 null,由调用方决定拒绝或回退,不抛异常。
  static MeasureUnit? tryFromDbValue(String? value) {
    switch (value) {
      case 'HOUR':
        return MeasureUnit.hour;
      case 'SHIFT':
        return MeasureUnit.shift;
      case 'DAY':
        return MeasureUnit.day;
      case 'RENT':
        return MeasureUnit.rent;
      case 'MU':
        return MeasureUnit.mu;
      case 'ACRE':
        return MeasureUnit.acre;
      case 'HECTARE':
        return MeasureUnit.hectare;
      case 'TON':
        return MeasureUnit.ton;
      case 'CUBIC_METER':
        return MeasureUnit.cubicMeter;
      case 'TRIP':
        return MeasureUnit.trip;
      case 'SORTIE':
        return MeasureUnit.sortie;
      case 'TASK':
        return MeasureUnit.task;
      default:
        return null;
    }
  }
}
