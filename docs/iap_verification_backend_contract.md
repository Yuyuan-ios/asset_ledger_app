# IAP 订阅服务端校验接口契约（Apple）

本文件描述 App 端 `HttpAppleSubscriptionVerificationRepository`
（`lib/data/services/http_apple_subscription_verification_repository.dart`）
所依赖的两个后端接口。后端按此实现并部署后，用
`dart_defines/production.json` 出包（路径 A）。

- **Base URL**：来自 `APPLE_IAP_VERIFICATION_BASE_URL`（dart-define）。
- 当前期望域名：`https://api.yuyuan.net.cn/fleet-ledger`（请与实际后端核对）。
- 完整地址 = `base` + 下列 path（path 可由 `APPLE_IAP_VERIFY_PURCHASE_PATH` /
  `APPLE_IAP_CURRENT_ENTITLEMENT_PATH` 覆盖，默认如下）。
- 请求/响应均为 `application/json; charset=utf-8`，客户端超时默认 10s
  （`APPLE_IAP_REQUEST_TIMEOUT_SECONDS`）。
- 必须 **公网 HTTPS 可达**，且 **同时支持 Apple sandbox 与 production**
  （App 审核走 sandbox）。

---

## 1) 校验购买：`POST {base}/iap/apple/verify-purchase`

购买/恢复成功后，App 用每笔交易调用一次。

### 请求体（字段来自 `AppleVerifyPurchaseRequest.toJson`）

```json
{
  "platform": "ios",
  "productId": "com.yuyuan.assetledger.pro.monthly",
  "purchaseId": "2000000xxxxxxx",
  "transactionDate": "1717900380000",
  "serverVerificationData": "<StoreKit2 JWS 或 base64 receipt>",
  "localVerificationData": "<本地校验数据>",
  "source": "app_store",
  "status": "purchased",
  "bundleId": "com.yuyuan.assetledger"
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| `platform` | string | 固定 `"ios"` |
| `productId` | string | `com.yuyuan.assetledger.pro.monthly` 或 `...pro.yearly` |
| `purchaseId` | string \| null | StoreKit 的 `purchaseID`，可能为 null |
| `transactionDate` | string \| null | 客户端给的交易时间戳（字符串），可能为 null；**勿作权威**，以 Apple 校验结果为准 |
| `serverVerificationData` | string | **校验主依据**。iOS 上通常是 StoreKit2 的 JWS 签名交易；用它做验签 / 调 App Store Server API |
| `localVerificationData` | string | 本地校验数据，一般忽略 |
| `source` | string | `purchase.verificationData.source`（如 `app_store`） |
| `status` | string | `purchased` / `restored` 等（`PurchaseStatus.name`） |
| `bundleId` | string | 仅在非空时出现；建议后端校验是否等于自己的 `com.yuyuan.assetledger` |

### 后端处理建议
1. 用 `serverVerificationData`（JWS）验签（Apple 根证书）或调 **App Store Server API**
   （`Get Transaction Info` / `Get All Subscription Statuses`），拿到 `originalTransactionId`、
   `productId`、`expiresDate`、`environment`(Sandbox/Production)、是否在宽限期/账单重试/已退款。
2. 接受 **Sandbox**（审核期）与 **Production** 两种 environment。
3. 建议把 `originalTransactionId` 与用户/设备绑定持久化，供接口 2 使用。

### 响应（HTTP 2xx + JSON，见 `AppleEntitlementResponse.fromJson`）

```json
{
  "outcome": "verifiedActiveMonthly",
  "productId": "com.yuyuan.assetledger.pro.monthly",
  "expiryDate": "2026-07-09T10:13:00Z"
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| `outcome` | string（必填） | 见下表；缺失/空 → 客户端按 `verificationFailed` |
| `productId` | string（可选） | 缺省时客户端回退用请求里的 productId |
| `expiryDate` | string（可选） | ISO-8601，须能被 `DateTime.parse` 解析；**存在但无法解析 → 客户端按 `verificationFailed`** |

#### `outcome` 取值（仅这些被识别，其它一律按 `verificationFailed`）
| 值 | 含义 | 是否解锁 Pro |
|---|---|---|
| `verifiedActiveMonthly` | 月订阅有效 | ✅ |
| `verifiedActiveYearly` | 年订阅有效 | ✅ |
| `verifiedGracePeriod` | 宽限期（仍可用） | ✅ |
| `verifiedBillingRetry` | 账单重试期 | ❌（已校验但不解锁） |
| `verifiedInactive`（或 `inactive`） | 无有效订阅 | ❌ |
| `verifiedExpired`（或 `expired`） | 已过期 | ❌ |
| `verifiedRevoked`（或 `revoked`） | 已撤销/退款 | ❌ |
| `verificationUnavailable` | 服务端暂不可用（见下方语义） | ❌ |
| `verificationFailed` | 校验失败 | ❌ |

> 解锁 Pro 的充要条件（`SubscriptionSnapshot.allowsProFeatures`）：`outcome` ∈
> {`verifiedActiveMonthly`,`verifiedActiveYearly`,`verifiedGracePeriod`}。

### 状态码与交易完成（重要）
- **非 2xx** → 客户端按 `verificationUnavailable`。
- `verificationUnavailable` 时客户端 **不会** completePurchase（`_shouldCompletePurchase`），
  交易保持 pending，StoreKit 后续会重发——**所以后端临时故障不会丢交易**。
- 其它 outcome（含 `verificationFailed`）→ 客户端会 completePurchase。
- 即：**真失败返回 `verificationFailed`（让交易关闭）；后端自身故障返回非 2xx 或
  `verificationUnavailable`（让交易稍后重试）**，不要混用。

---

## 2) 同步当前权益：`{base}/iap/apple/current-entitlement`

App 启动 / 进订阅页时调用，用于刷新权益。

- **方法：`GET`**，无请求体。
- 响应格式与接口 1 **完全相同**（同一个 `AppleEntitlementResponse`）。
- 错误处理同上：非 2xx → `verificationUnavailable`，客户端回退本地缓存。

### ⚠️ 已知限制（需注意）
当前客户端 `getJson` **不发送任何身份/凭证**（无 Authorization、无 receipt、无 user id）。
因此后端无法仅凭此请求识别"是谁的权益"。可选处理：
1. 暂时让该接口返回 `{"outcome":"verifiedInactive"}`（与本地 stopgap 行为一致），
   权益主要靠接口 1（verify-purchase）+ 客户端缓存维持；或
2. 后续做一次 **客户端改造**（本契约外）：让 GET 带上用户标识或
   `originalTransactionId`，后端据此查 App Store Server API 返回最新状态。

---

## 3) 联调清单（提交前在沙盒验证）
- [ ] 用沙盒账号购买月/年订阅 → 接口 1 返回 `verifiedActiveMonthly/Yearly` + 正确 `expiryDate` → App 解锁 Pro。
- [ ] 后端宕机模拟 → 客户端不丢交易（pending，稍后重试）。
- [ ] 退款/撤销 → 接口返回 `verifiedRevoked` → App 收回 Pro。
- [ ] iPhone + iPad 各验一遍（Apple 用 iPhone 17 Pro Max + iPad Air M3）。
- [ ] base URL 与 `dart_defines/production.json` 一致。
