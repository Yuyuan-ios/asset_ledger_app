# 机账通商店隐私申报清单

更新时间：2026-03-17

这份清单基于当前仓库代码实现整理，用于辅助填写：

- Apple App Store Connect 的 `App Privacy`
- Apple App Store Connect 的 `Privacy Policy URL` / `Support URL`
- Google Play Console 的 `Data safety`
- Google Play Console 的 `Privacy policy`

## 1. 当前实现结论

根据当前代码检查，机账通目前的实现特征如下：

- 业务数据主要保存在本地 SQLite 中：
  `pubspec.yaml`
- 图片头像保存在应用私有目录中，不上传开发者服务器：
  `lib/data/services/avatar_storage_service.dart`
- 自定义头像通过系统相册选择，仅在本地使用：
  `lib/features/device/view/device_editor_dialog.dart`
- 当前未发现开发者自建登录、云同步、广告、分析、崩溃上报或自建后端通信依赖：
  `pubspec.yaml`
- 当前用到的系统/平台能力主要是：
  - `image_picker`
  - `in_app_review`
  - `url_launcher`
  - `sqflite`
  - `path_provider`
- iOS `Info.plist` 中当前未声明额外网络或追踪相关能力：
  `ios/Runner/Info.plist`
- Android `AndroidManifest.xml` 中当前未声明额外危险权限：
  `android/app/src/main/AndroidManifest.xml`

基于以上实现，当前版本最稳妥的申报口径是：

- Apple App Privacy：`No Data Collected`
- Google Play Data safety：`No data collected` / `No data shared`

原因不是“应用里没有用户数据”，而是“当前版本未将这些数据传输到开发者或第三方服务器，主要在设备本地处理和存储”。

## 2. Apple App Store Connect

### 2.1 Privacy Policy URL

填写：

```text
https://yuyuan-ios.github.io/asset_ledger_app/privacy.html
```

### 2.2 Support URL

填写：

```text
https://yuyuan-ios.github.io/asset_ledger_app/
```

### 2.3 App Privacy 建议填写

当前建议选择：

- `No, we do not collect data from this app`

### 2.4 这样填写的依据

Apple 官方说明里，“data collected”核心是应用或第三方伙伴从应用中收集并传输到开发者或第三方系统的数据；如果数据仅在设备本地处理且不离开设备，可不视为“collected”。

参考官方：

- App privacy details
  [Apple 官方文档](https://developer.apple.com/app-store/app-privacy-details/)
- App Review Guidelines 5.1.1 Data Collection and Storage
  [Apple 官方文档](https://developer.apple.com/app-store/review/guidelines/)

### 2.5 需要注意

- 当前相册选择仅用于本地头像，不代表一定要在 App Privacy 中申报“Photos”，前提是图片没有传出设备。
- `in_app_review` 打开的是系统评分能力，不等于开发者自己收集评分数据。
- 如果后续接入真实订阅、登录、云同步、错误上报、分析 SDK、广告 SDK 或任何远程 API，需要重新评估是否仍能填 `No Data Collected`。

## 3. Google Play Console

### 3.1 Privacy policy

填写：

```text
https://yuyuan-ios.github.io/asset_ledger_app/privacy.html
```

### 3.2 Data safety 建议填写

当前建议选择：

- `No`，应用当前不收集或共享任何必填用户数据类型

### 3.3 这样填写的依据

Google 官方文档说明，如果数据仅在设备本地处理且不会离开用户设备，一般不属于 Data safety 中需要申报的“collected”。

参考官方：

- User Data policy
  [Google Play 官方文档](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en)
- Declare your app's data use
  [Android Developers 官方文档](https://developer.android.com/privacy-and-security/declare-data-use)

### 3.4 需要注意

- 本地 SQLite、应用私有目录中的头像文件，不等于 Google Play 所说的“collected”，前提是这些数据没有传给开发者或第三方。
- 如果未来接入：
  - Google Play Billing
  - Firebase / Crashlytics / Analytics
  - 广告 SDK
  - 云同步 / 登录 / 远程接口
  - 推送服务
  就必须重新填写 Data safety。

## 4. 已准备好的公开页面

- 支持页：
  `support-site/index.html`
- 隐私政策：
  `support-site/privacy.html`
- 使用条款：
  `support-site/terms.html`
- GitHub Pages 发布工作流：
  `.github/workflows/deploy-support-site.yml`

## 5. 提审前自检

- 公开页面必须可匿名访问，不能要求登录。
- 公开页面必须使用 HTTPS。
- 支持页、隐私政策页、使用条款页内容要与应用内文案一致。
- 如果 App Store / Google Play 的上架名称是“机账通”，建议同步检查 iOS 和 Android 的显示名是否也已经改为该名称。
- 一旦代码里新增远程数据传输或第三方数据 SDK，先改这份清单，再改控制台声明。

## 6. 结论

以当前代码实现来看，最稳妥的商店申报口径是：

- Apple App Privacy：`No Data Collected`
- Apple Privacy Policy URL：`https://yuyuan-ios.github.io/asset_ledger_app/privacy.html`
- Apple Support URL：`https://yuyuan-ios.github.io/asset_ledger_app/`
- Google Play Privacy policy：`https://yuyuan-ios.github.io/asset_ledger_app/privacy.html`
- Google Play Data safety：`No data collected` / `No data shared`

如果后续产品形态发生变化，这份结论需要重新评估。本文档用于提审准备与产品自查，不构成正式法律意见。
