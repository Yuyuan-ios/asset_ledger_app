# App Store 自动续期订阅审核修复说明

## 1. 拒审原因摘要

审核版本 1.0.1 (33) 被 Apple 以 Guideline 3.1.2(c) 拒审。Apple 指出，包含自动续期订阅的 App 需要在购买前清楚展示订阅名称、订阅周期、订阅价格、必要时的单位价格，以及可用的隐私政策和 Terms of Use / EULA 链接。

## 2. App 内已修复项

订阅入口路径：

- 设备页
- 立即升级

本次修复在 `lib/features/device/view/upgrade_page.dart` 的购买按钮上方新增订阅合规信息区块，展示以下内容：

- 订阅名称：优先使用 StoreKit / App Store 返回的 `ProductDetails.title`，缺失时使用当前产品类型的保守兜底名称。
- 订阅周期：根据当前订阅商品 ID 映射展示 `每月 / 1 month` 或 `每年 / 1 year`。
- 订阅价格：仅使用 StoreKit / App Store 返回的 `ProductDetails.price`。
- 单位价格：在商品信息已加载时展示 StoreKit 价格加 `/月` 或 `/年`；商品信息缺失时不显示伪价格。
- 权益说明：说明订阅有效期内可使用已开放 Pro 功能。
- 自动续期说明：说明自动续期、提前 24 小时关闭自动续期、可在 Apple ID 订阅设置中管理或取消。
- 隐私政策链接：展示并可点击打开 `https://yuyuan-ios.github.io/asset_ledger_app/privacy.html`。
- 使用条款链接：展示并可点击打开 `https://yuyuan-ios.github.io/asset_ledger_app/terms.html`。
- 恢复购买：购买页底部保留可见的“恢复购买”入口。

商品信息加载失败或 App Store 未返回订阅商品时，购买按钮保持不可用，并展示“商品信息未完整加载前无法购买，请等待 App Store 返回订阅信息。”，避免在信息缺失时诱导订阅。

## 3. App Store Connect 人工检查清单

提交新构建前需要在 App Store Connect 人工核对：

- Privacy Policy URL field：填写真实可访问链接 `https://yuyuan-ios.github.io/asset_ledger_app/privacy.html`。
- App Description 或 EULA field：若继续使用当前自定义使用条款，请在 EULA field 或 App Description 中提供 `https://yuyuan-ios.github.io/asset_ledger_app/terms.html`。
- 如果改用 Apple 标准 EULA，需要在 App Description 中加入 Apple 标准 EULA 链接：`https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`。
- 订阅产品 metadata：检查月订阅和年订阅的 display name、description、duration、price、localization 是否完整，且与 App 内展示一致。
- App Privacy：如果生产构建启用了服务端购买校验，需复核是否涉及订阅交易校验数据传输，并据实更新 App Privacy。
- GitHub Pages：本地 `support-site/privacy.html` 与 `support-site/terms.html` 已更新订阅相关表述；提交审核前需确认这些文案已部署到线上页面。

## 4. Apple Review Notes 建议

建议在 Review Notes 中说明：

- 订阅信息显示位置：设备页 > 立即升级。
- 购买按钮上方已展示自动续期订阅名称、周期、价格、单位价格、权益说明和自动续期规则。
- 同一区块内已展示并可点击打开 Privacy Policy 和 Terms of Use 链接。
- 页面底部保留“恢复购买”入口。
- 建议随提交附一段屏幕录制，路径为“设备页 > 立即升级 > 查看购买按钮上方订阅信息区块”。

## 5. 后续 Pro / Max 扩展边界

- 本次审核只提交当前 Pro 月订阅和 Pro 年订阅的 3.1.2(c) 合规修复，不把 Max 作为当前已上线功能提交审核。
- 代码层可以保留 `SubscriptionTier.max` 这类未激活的模型预留，但当前 UI 只展示 StoreKit 返回且当前已支持的 Pro 产品。
- 后续如新增 Max，应在同一 subscription group 中新增更高 tier 的 subscription product，并在独立发布轮次中同步更新：
  - App Store Connect 产品与本地 StoreKit 配置
  - product id 显式映射
  - App 内权益展示与订阅说明
  - entitlement 校验与 Restore purchases 逻辑
  - Review Notes 与审核截图 / 屏幕录制
- 本次提交给 Apple Review 的说明和回复文案不写入 Max，避免扩大当前审核面。

## 6. 给 Apple Review 的回复文案

Hello App Review Team,

Thank you for your review. We have updated the app to clearly display the required auto-renewable subscription information before purchase, including the subscription title, subscription length, localized price, price per unit, subscription benefits, auto-renewal information, and functional links to the Privacy Policy and Terms of Use.

The subscription information can be found in the app by navigating to:
Device page > Upgrade Now.

The Privacy Policy and Terms of Use links are displayed near the purchase button on the subscription screen, and the Restore Purchases entry remains visible on the same screen.

We have also reviewed the App Store Connect metadata and will ensure the Privacy Policy URL and Terms of Use/EULA information are provided in the appropriate metadata fields.

Thank you.

## 7. 未验证项

以下项目需要提交前继续人工或沙盒验证：

- App Store Connect 中 Privacy Policy URL、EULA / App Description、订阅产品 metadata 的最终填写状态。
- iOS 真机或 TestFlight / StoreKit 沙盒中的实际商品 title、localized price 和购买确认页展示。
- 本地更新后的 `support-site/privacy.html` 与 `support-site/terms.html` 是否已发布到 GitHub Pages 线上页面。
