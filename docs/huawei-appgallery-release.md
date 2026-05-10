# 华为应用市场上架清单

更新时间：2026-04-20

## 当前项目发布信息

- 应用名称：机账通
- Android 包名：`com.yuyuan.assetledger`
- 当前版本：`1.0.0+1`
- 支持页：`https://yuyuan-ios.github.io/asset_ledger_app/`
- 隐私政策：`https://yuyuan-ios.github.io/asset_ledger_app/privacy.html`
- 使用条款：`https://yuyuan-ios.github.io/asset_ledger_app/terms.html`

## 本地构建命令

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

生成产物：

- APK：`build/app/outputs/flutter-apk/app-release.apk`
- App Bundle：`build/app/outputs/bundle/release/app-release.aab`

## 正式签名配置

正式上架前需要在 `android/key.properties` 放入 release keystore 配置。该文件已被 `android/.gitignore` 忽略，不要提交到 Git。

```properties
storePassword=你的store密码
keyPassword=你的key密码
keyAlias=upload
storeFile=app/upload-keystore.jks
```

对应 keystore 文件建议放在：

```text
android/app/upload-keystore.jks
```

`android/app/build.gradle.kts` 已配置为：检测到 `android/key.properties` 时使用正式 release 签名；没有该文件时回退 debug 签名，方便本地构建验证。

## 华为后台填写项

1. 注册并登录华为开发者联盟，完成实名认证。
2. 在 AppGallery Connect 创建应用，平台选择 Android，包名填写 `com.yuyuan.assetledger`。
3. 上传 APK 或 App Bundle。
4. 完善基础信息：应用名称、介绍、截图、应用分类、语言。
5. 完善分发信息：免费/付费、国家及地区、隐私政策链接。
6. 提交上架审核前核对包名、版本号、签名证书、截图、隐私链接。

## 提交前检查

- `android/key.properties` 存在且内容正确。
- APK/AAB 使用正式签名，而不是 debug 签名。
- `versionCode` 比华为后台已有版本更高。
- 隐私政策和支持页可匿名 HTTPS 访问。
- 应用内“联系开发者”“隐私政策”“使用条款”入口可正常打开。
- 截图中应用名称统一为“机账通”。
