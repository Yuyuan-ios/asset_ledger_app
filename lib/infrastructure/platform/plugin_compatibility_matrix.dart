class PluginCompatibilityRisk {
  const PluginCompatibilityRisk({
    required this.plugin,
    required this.currentUse,
    required this.androidRisk,
    required this.iosRisk,
    required this.harmonyRisk,
    required this.needsAlternative,
    required this.needsAdapter,
    required this.needsDeviceVerification,
  });

  final String plugin;
  final String currentUse;
  final String androidRisk;
  final String iosRisk;
  final String harmonyRisk;
  final bool needsAlternative;
  final bool needsAdapter;
  final bool needsDeviceVerification;
}

const pluginCompatibilityMatrix = <PluginCompatibilityRisk>[
  PluginCompatibilityRisk(
    plugin: 'sqflite',
    currentUse: '本地 SQLite 数据库',
    androidRisk: '低：主流能力稳定，需验证升级迁移和大库性能',
    iosRisk: '低：需验证 iCloud/备份策略不误包含临时文件',
    harmonyRisk: '高：需确认插件实现或替代数据库方案',
    needsAlternative: true,
    needsAdapter: true,
    needsDeviceVerification: true,
  ),
  PluginCompatibilityRisk(
    plugin: 'path_provider',
    currentUse: '备份、头像、数据库相关本地路径',
    androidRisk: '中：分区存储路径和备份导出需实机确认',
    iosRisk: '中：Documents/temporary 目录生命周期需确认',
    harmonyRisk: '高：路径 provider 兼容性需实机确认',
    needsAlternative: true,
    needsAdapter: true,
    needsDeviceVerification: true,
  ),
  PluginCompatibilityRisk(
    plugin: 'file_picker',
    currentUse: '本地备份导入文件选择',
    androidRisk: '中：不同 ROM 文件授权返回路径差异',
    iosRisk: '中：安全作用域文件访问需确认',
    harmonyRisk: '高：需确认插件是否支持',
    needsAlternative: true,
    needsAdapter: true,
    needsDeviceVerification: true,
  ),
  PluginCompatibilityRisk(
    plugin: 'share_plus',
    currentUse: '本地备份和项目分享',
    androidRisk: '中：FileProvider/URI 授权需覆盖测试',
    iosRisk: '中：分享面板与文件 UTI 需测试',
    harmonyRisk: '高：系统分享能力需替代方案预案',
    needsAlternative: true,
    needsAdapter: true,
    needsDeviceVerification: true,
  ),
  PluginCompatibilityRisk(
    plugin: 'image_picker',
    currentUse: '设备头像选择/拍照',
    androidRisk: '中：相册权限和 Android 13+ 媒体权限',
    iosRisk: '中：相册/相机权限文案和取消态',
    harmonyRisk: '高：相机相册能力需实机确认',
    needsAlternative: true,
    needsAdapter: true,
    needsDeviceVerification: true,
  ),
  PluginCompatibilityRisk(
    plugin: 'in_app_purchase',
    currentUse: 'Pro 订阅',
    androidRisk: '中：Play Billing 商品和恢复购买',
    iosRisk: '中：StoreKit 沙盒、恢复和收据校验',
    harmonyRisk: '高：需替换为鸿蒙支付/权益服务',
    needsAlternative: true,
    needsAdapter: true,
    needsDeviceVerification: true,
  ),
  PluginCompatibilityRisk(
    plugin: 'url_launcher',
    currentUse: '客服、外部链接、反馈入口',
    androidRisk: '低：需校验 scheme fallback',
    iosRisk: '低：需配置 LSApplicationQueriesSchemes 时验证',
    harmonyRisk: '中：外部拉起能力需验证',
    needsAlternative: false,
    needsAdapter: true,
    needsDeviceVerification: true,
  ),
];
