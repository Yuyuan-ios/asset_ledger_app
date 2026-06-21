/// 设备类型选定后进入的「新建业务模式」（类型化路由契约）。
///
/// 设计目的：
/// - 替代提示词里建议的字符串 `businessMode: "excavator_create"`，
///   用枚举避免拼写错误与无类型跳转。
/// - 不同设备类型可映射到不同创建流程；当前 Phase 1 仅打通工程机械编辑器，
///   其余类型一律 [comingSoon]，可浏览品牌但不可创建。
enum DeviceCreateFlow {
  /// 现有工程机械设备编辑器（挖掘机 / 装载机：按小时计量 + 单价·分计费）。
  /// Phase 2 接入的压路机/装卸车若仍沿用小时计量，可复用此流程。
  engineeringEditor,

  /// 尚未接入的创建流程（农机 / 无人机 / 机器人 / 自定义等）。
  /// 当前仅可浏览品牌墙，底部主按钮显式置为「敬请期待」，绝不回落旧流程。
  comingSoon,
}

extension DeviceCreateFlowX on DeviceCreateFlow {
  bool get isImplemented => this != DeviceCreateFlow.comingSoon;
}
