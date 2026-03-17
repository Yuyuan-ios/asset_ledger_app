# 机账通发布前检查清单

更新时间：2026-03-17

这份清单面向当前仓库状态，目标是帮助你在提交 iOS App Store Connect 与 Google Play 之前，快速核对还剩哪些必须项、建议项和可暂缓项。

## 一、已完成

- App 内用户可见名称已统一为“机账通”
- 设备页已提供“支持与反馈”分组
- “联系开发者”已接入公开支持页
- 公开支持页、隐私政策页、使用条款页已落地
- 商店隐私声明参考清单已落地
- `excavator_ledger` 项目历史命名已基本清理，旧数据库文件名具备兼容迁移

## 二、iOS 提审前必查

- 确认 App Store Connect 的 App 名称、副标题、关键词与“机账通”一致
- 确认 `Support URL` 使用：
  `https://yuyuan-ios.github.io/asset_ledger_app/`
- 确认 `Privacy Policy URL` 使用：
  `https://yuyuan-ios.github.io/asset_ledger_app/privacy.html`
- 按 `docs/store-privacy-declarations.md` 填写 `App Privacy`
- 检查 iOS 主 Bundle Identifier 是否为你自己的正式值
  当前主包名已是：`com.yuyuan.asset-ledger`
- 检查截图、预览视频、应用描述中是否仍出现旧名称
- 如果上架语言以中文为主，确认 App Store 文案里统一使用“机账通”

## 三、Android 提审前必查

- 确认 Google Play 的应用名称为“机账通”
- 确认 `Privacy policy` 使用：
  `https://yuyuan-ios.github.io/asset_ledger_app/privacy.html`
- 按 `docs/store-privacy-declarations.md` 填写 `Data safety`
- Android 包名当前已定稿为：
  `com.example.asset_ledger`
- 首次正式上架前，请再次确认你确实希望长期使用这个包名；一旦在 Google Play 上线后，再改包名会被视为新的应用

## 四、支持页与法务页面

- 访问支持页，确认可匿名打开
- 访问隐私政策页，确认可匿名打开
- 访问使用条款页，确认可匿名打开
- 确认页面都为 HTTPS
- 确认页面里的邮箱、抖音账号、链接都正确

## 五、构建与功能回归

- 运行关键页面手测：
  - 设备页
  - 添加设备
  - 管理设备
  - 评分入口
  - 使用条款
  - 隐私政策
  - 联系开发者
- 验证“联系开发者”优先打开支持页，失败时能回退邮件
- 验证旧数据库升级后数据可正常读取
- 验证应用显示名、桌面名称、Web 标题都为“机账通”

## 六、建议但可后续再做

- 将 Android `com.example.asset_ledger` 换成你自己的正式包名
- 将 Windows / Linux / macOS 的公司标识从 `com.example` 替换为你自己的组织标识
- 如果未来接入登录、云同步、订阅支付、崩溃上报、统计或广告，重新填写隐私声明

## 七、当前最需要你决定的一件事

当前最需要做的是在真实设备或打包产物上再核一遍：

1. 应用桌面名称是否显示为“机账通”
2. “联系开发者”是否能正确打开支持页
3. GitHub Pages 上的支持页、隐私政策、使用条款是否都能正常访问
