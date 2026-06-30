# 出包参数（dart-define）配置

发布访问架构分两条轴：

- `FLEET_LEDGER_BUILD_ENV`：构建环境，只能由 build config / flavor 控制。
- `FLEET_LEDGER_ACCESS_MODE`：默认访问模式，可由 build config 控制；production
  build 中的受控审核账号登录后也会解析为 `sandbox` access。

## 构建环境

| 值 | 用途 |
| --- | --- |
| `production` | App Store / 正式用户构建 |
| `staging` | TestFlight / 内测 / 预发布构建 |
| `local` | 本地开发构建 |

未知值按 `production` 处理，保持 fail-closed。

## 访问模式

| 值 | 用途 |
| --- | --- |
| `normal` | 真实用户访问：真实登录、真实 IAP、真实同步/备份/更新 |
| `sandbox` | 审核/测试通道：完整功能访问、本地 mock 同步、无购买要求 |
| `demo` | 离线展示通道：只使用本地演示数据，不依赖网络 |

默认策略：

- `production` build 默认 `normal`
- `staging` build 默认 `sandbox`
- `local` build 默认 `demo`

## 涉及的 define

| Key | 读取处 | 作用 | 默认 |
| --- | --- | --- | --- |
| `FLEET_LEDGER_BUILD_ENV` | `lib/core/config/app_environment.dart` | 构建环境：`production` / `staging` / `local` | `production` |
| `FLEET_LEDGER_ACCESS_MODE` | `lib/core/config/app_environment.dart` | 默认访问模式：`normal` / `sandbox` / `demo` | 由 build env 推导 |
| `REVIEW_ACCESS_MODE_ENABLED` | `lib/core/config/app_environment.dart` | 是否启用受控审核账号访问 | `false` |
| `REVIEW_ACCESS_IDENTIFIERS` | `lib/core/config/app_environment.dart` | 审核账号标识，逗号/空格分隔 | 空 |
| `REVIEW_ACCESS_EMAILS` | `lib/core/config/app_environment.dart` | 审核账号邮箱，逗号/空格分隔 | 空 |
| `REVIEW_ACCESS_PHONE_NUMBERS` | `lib/core/config/app_environment.dart` | 审核账号手机号，逗号/空格分隔 | 空 |
| `REVIEW_ACCESS_PASSWORD` | `lib/core/config/app_environment.dart` | 审核账号密码 | 空 |
| `APPLE_IAP_VERIFICATION_BASE_URL` | `lib/core/config/subscription_config.dart` | 生产服务端票据校验后端 base URL；仅 normal access 使用 | `https://api.yuyuan.net.cn/fleet-ledger` |
| `APPLE_IAP_VERIFY_PURCHASE_PATH` | `lib/core/config/subscription_config.dart` | 覆盖购买校验 path | `/iap/apple/verify-purchase` |
| `APPLE_IAP_CURRENT_ENTITLEMENT_PATH` | `lib/core/config/subscription_config.dart` | 覆盖当前权益同步 path | `/iap/apple/current-entitlement` |
| `APPLE_IAP_REQUEST_TIMEOUT_SECONDS` | `lib/core/config/subscription_config.dart` | 后端校验请求超时 | `10` |
| `FLEET_LEDGER_CLOUD_BACKUP_BASE_URL` | `lib/app/cloud_backup_config.dart` | 生产云端备份后端 base URL | 空 |
| `FLEET_LEDGER_SYNC_BASE_URL` | `lib/app/sync_transport_config.dart` | 生产同步后端 base URL | 空 |

不要把真实审核密码提交到 git。真实账号密码应通过 CI/本机出包命令的安全
`--dart-define` 注入，并只填写到 App Store Connect。

## 配置文件

- `production.json`：正式生产包。默认 `normal` access，真实登录、真实 IAP
  服务端校验、真实云备份配置。
- `staging.json`：预发布/内测包。默认 `sandbox` access。
- `local.json`：本地开发包。默认 `demo` access。

## 出包命令

```bash
flutter build ipa --release --dart-define-from-file=dart_defines/production.json
flutter build ipa --release --dart-define-from-file=dart_defines/staging.json
flutter build ipa --release --dart-define-from-file=dart_defines/local.json
```

production build 若需要审核账号通道，在不提交密码的前提下额外注入：

```bash
--dart-define=REVIEW_ACCESS_MODE_ENABLED=true
--dart-define=REVIEW_ACCESS_EMAILS=<REVIEW_EMAIL>
--dart-define=REVIEW_ACCESS_PASSWORD=<REVIEW_PASSWORD>
```

Android 同理使用对应的 `--dart-define-from-file`。

## 测试命令

```bash
flutter test test/app/app_environment_test.dart --dart-define-from-file=dart_defines/production.json
flutter test test/app/app_environment_test.dart --dart-define-from-file=dart_defines/staging.json
flutter test test/app/app_environment_test.dart --dart-define-from-file=dart_defines/local.json
```

## Xcode Archive 注意

`--dart-define` / `--dart-define-from-file` 只在 `flutter build ipa` 生效。若直接在
Xcode 里 Archive，dart-define 不会自动带上。请坚持用
`flutter build ipa --dart-define-from-file=...` 产物，再用 Transporter / Xcode
Organizer 上传。

CI、Codemagic、fastlane 同理：把对应环境的
`--dart-define-from-file=dart_defines/<env>.json` 加进构建步骤。
