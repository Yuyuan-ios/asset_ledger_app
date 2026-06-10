# 出包参数（dart-define）配置

IAP 订阅购买流程由编译期 `dart-define` 控制。若出包时忘了带参数，App 会在
"立即升级"页显示「暂不可购买 / 订阅购买服务暂不可用」并禁用购买按钮。这正是
1.0.1(36) 被 Apple 以 Guideline 2.1(b) 拒审的原因。

把参数固化进本目录的 JSON，统一用 `--dart-define-from-file` 出包，避免再次漏传。

## 涉及的 define

| Key | 读取处 | 作用 | 默认 |
| --- | --- | --- | --- |
| `APPLE_IAP_VERIFICATION_BASE_URL` | `lib/core/config/subscription_config.dart` | 服务端票据校验后端 base URL；非空即开启购买流程并走服务端校验 | 空（购买流程被禁用） |
| `APPLE_IAP_VERIFY_PURCHASE_PATH` | `lib/core/config/subscription_config.dart` | 覆盖购买校验 path | `/iap/apple/verify-purchase` |
| `APPLE_IAP_CURRENT_ENTITLEMENT_PATH` | `lib/core/config/subscription_config.dart` | 覆盖当前权益同步 path | `/iap/apple/current-entitlement` |
| `APPLE_IAP_REQUEST_TIMEOUT_SECONDS` | `lib/core/config/subscription_config.dart` | 后端校验请求超时 | `10` |
| `USE_LOCAL_IAP_VERIFICATION` | `lib/data/services/subscription_verification_repository_factory.dart` | `true` 时用本地校验开启购买流程（仅过审/沙盒冒烟用） | `false` |

判定开关：`canUsePurchaseFlow = isConfigured(URL) || USE_LOCAL_IAP_VERIFICATION`。
两者都为假时购买流程禁用。

可选：`FLEET_LEDGER_API_BASE_URL` 是短信登录后端，已有默认值
`https://api.yuyuan.net.cn/fleet-ledger`，一般无需设置。

## 两份配置

- `app_store_review.json`：立即过审用的 stopgap。`USE_LOCAL_IAP_VERIFICATION=true`，
  购买流程可跑通，本地按 Pro/Max 年订阅商品解锁对应权益。不要用于长期生产构建。
- `production.json`：正式方案。`APPLE_IAP_VERIFICATION_BASE_URL` 指向真实后端。
  当前值为 `https://api.yuyuan.net.cn/fleet-ledger`，使用前必须确认与实际部署一致，并在
  Apple sandbox 中通过 `/iap/apple/verify-purchase` 与
  `/iap/apple/current-entitlement` 联调。

后端请求/响应契约见 `docs/iap_verification_backend_contract.md`。客户端不会硬编码展示价格；
升级页使用 App Store / StoreKit 返回的本地化价格。

## 出包命令

```bash
# 立即过审（本地校验 stopgap）
flutter build ipa --release --dart-define-from-file=dart_defines/app_store_review.json

# 后端就绪后的正式包
flutter build ipa --release --dart-define-from-file=dart_defines/production.json
```

记得每次重交都递增 build 号（CFBundleVersion）。1.0.1(36) 已被拒，用 37+。

## 测试命令

如果本机 iOS 签名不可用，至少用测试确认 define 生效：

```bash
flutter test test/features/upgrade_page_iap_define_test.dart --dart-define-from-file=dart_defines/app_store_review.json
flutter test test/features/upgrade_page_iap_define_test.dart --dart-define-from-file=dart_defines/production.json
```

## Xcode Archive 注意

`--dart-define` / `--dart-define-from-file` 只在 `flutter build ipa` 生效。若直接在
Xcode 里 Archive，dart-define 不会自动带上，会再次漏配。请坚持用
`flutter build ipa --dart-define-from-file=...` 产物，再用 Transporter / Xcode Organizer 上传。

CI、Codemagic、fastlane 同理：把
`--dart-define-from-file=dart_defines/production.json` 加进构建步骤。不要把
`USE_LOCAL_IAP_VERIFICATION` 加进默认或生产构建脚本。
