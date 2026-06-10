# 出包参数（dart-define）配置

IAP 订阅购买流程由 **编译期 dart-define** 控制。若出包时忘了带参数，App 会在
"立即升级"页显示「暂不可购买 / 订阅购买服务暂不可用」并禁用购买按钮——这正是
1.0.1(36) 被 Apple 以 **Guideline 2.1(b)** 拒审的原因。

把参数固化进本目录的 JSON，统一用 `--dart-define-from-file` 出包，避免再次漏传。

## 涉及的 define（来源：`lib/`，本配置不改业务代码）

| Key | 读取处 | 作用 | 默认 |
|---|---|---|---|
| `APPLE_IAP_VERIFICATION_BASE_URL` | `lib/core/config/subscription_config.dart` | 服务端票据校验后端 base URL；非空即开启购买流程并走服务端校验 | 空（购买流程被禁用） |
| `USE_LOCAL_IAP_VERIFICATION` | `lib/data/services/subscription_verification_repository_factory.dart` | `true` 时用本地校验开启购买流程（仅过审/冒烟用） | `false` |

判定开关：`canUsePurchaseFlow = isConfigured(URL) || USE_LOCAL_IAP_VERIFICATION`
（`lib/features/device/application/controllers/subscription_controller.dart:18`）。
两者都为假 → 购买流程禁用 → 触发拒审。

可选：`FLEET_LEDGER_API_BASE_URL`（短信登录后端，已有默认值
`https://api.yuyuan.net.cn/fleet-ledger`，一般无需设置）。

## 两份配置

- **`app_store_review.json`** — 立即过审用（路径 B，stopgap）。`USE_LOCAL_IAP_VERIFICATION=true`，
  购买流程跑通、Pro 本地解锁，无需后端。
  ⚠️ 本地校验**可被伪造**，代码注释明确写「不要用于生产」。仅用于"后端未就绪、先过审"，
  上线后端后请尽快切到 `production.json`。
- **`production.json`** — 正式方案（路径 A）。`APPLE_IAP_VERIFICATION_BASE_URL` 指向真实后端。
  ⚠️ 使用前必须先部署并在 **沙盒** 验证 `/iap/apple/verify-purchase` 与
  `/iap/apple/current-entitlement`（契约见 `docs/iap_verification_backend_contract.md`），
  否则购买能发起但会卡在服务端校验失败。请确认这里的 base URL 与实际后端一致。

## 出包命令

```bash
# 立即过审（本地校验 stopgap）
flutter build ipa --release --dart-define-from-file=dart_defines/app_store_review.json

# 后端就绪后的正式包
flutter build ipa --release --dart-define-from-file=dart_defines/production.json
```

记得每次重交都 **递增 build 号**（CFBundleVersion），1.0.1(36) 已被拒，用 37+。

## 重要：Xcode Archive 注意
`--dart-define` / `--dart-define-from-file` 只在 `flutter build ipa` 生效。若直接在
Xcode 里 Archive，dart-define **不会** 自动带上，会再次漏配。请坚持用
`flutter build ipa --dart-define-from-file=...` 产物，再用 Transporter / Xcode Organizer 上传。

（CI/codemagic/fastlane 同理：把 `--dart-define-from-file=dart_defines/production.json`
加进构建步骤。）
