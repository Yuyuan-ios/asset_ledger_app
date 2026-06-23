# Phase 4 生产闭环 — IAP 线记录（dev）

> 配套:`docs/quality/execution-roadmap-dev-36d42f0.md`、契约 `docs/iap_verification_backend_contract.md`、
> 盘点元结论见本文 §1。**代码侧 IAP 已完成(S1/S1b/S2 均在 dev),剩部署/密钥/nginx/sandbox smoke = 用户闭环步骤。**

## 0. 本质提醒

Phase 4 = 生产闭环,不是"再写代码"。**Codex 能写代码,写不了闭环**(真机/真云/商店验证)。
**代码绿 ≠ 能变现/能同步。** 凡"已实现"必须用 file:line/命令独立验证,fake/mock/有 fallback 都不算真实能力。

## 1. Phase 4 缺口盘点(只读,已人工元审证实)

代码主体(客户端 + 仓库 sync 后端 + IAP 客户端)已就绪、**不重写**。缺口三类:

| 缺口 | 谁能做 | 状态 |
| --- | --- | --- |
| sync 2 个 deferred:delete-meta(tombstone)生命周期、terminal-failed admin reset | Codex 写代码,但**需用户先做产品决策**(tombstone 保留/清理期、复位入口/权限) | ⏳ 未做 |
| sync 公网 nginx 路由(服务在 8009 但公网 502)+ 生产 `FLEET_LEDGER_SYNC_BASE_URL` + smoke | **用户 ops** | ⏳ 未做 |
| IAP 真后端(远程原为占位 server.js,返回 verificationUnavailable;nginx 路由 404/502) | **Codex 写,用户给 Apple 密钥 + 部署** | ✅ 代码已写(见 §2) |

证据(盘点时):production.json 无 sync base url(且 `sync_transport_config_test.dart:8` 刻意断言不填);
`sync_repositories.dart` delete ack 是 no-op(注释 deferred);远程 sync service 本机 8009 health 200 但公网 502;
远程 IAP 原为占位、nginx /fleet-ledger/iap/* 404。

## 2. IAP 代码线(已完成,均在 dev)

| 切片 | commit | 内容 | 审计裁定 |
| --- | --- | --- | --- |
| IAP-S1 | `b4c1d3c` | 新建 `server/iap_verification_backend/`(config/auth/storage/handlers/app + smoke + tests);两 endpoint;契约 11 用例;Apple 校验用**可注入 fake**占位 | ⚠️ 见 S1b |
| IAP-S1b | `24d9920` | **安全修复**:S1 的 `from_env()`(生产入口)误硬编码 `FakeAppleVerifier()`,可被魔法串 `fake:pro-active` 白嫖 Pro;改为 `build_verifier_from_config` → 无凭据一律 `AppleServerApiVerifierPlaceholder` fail-closed;app.py 撤 fake 导出;加"生产无凭据+fake token→verificationUnavailable+不入库"回归测试 | ✅ 通过(洞已堵+回归) |
| IAP-S2 | `38bb83d` | 真实校验:官方 `app-store-server-library==3.1.2`;`OfficialSignedDataVerifier.verify_and_decode_signed_transaction`(签名+证书链,**无裸 decode 回退**);`get_all_subscription_statuses`;Apple 状态→契约 outcome/tier;Sandbox+Production;凭据 env/path 注入;`build_verifier_from_config` 凭据完整→真 verifier,否则 placeholder | ✅ 通过(安全核心) |

**安全铁律(IAP 命门,后续改动必守)**:
- `build_verifier_from_config` 选 verifier 的那几行是命门——**无凭据/未接真校验前一律 fail-closed**,生产路径**绝不**引用 `FakeAppleVerifier`。
- fail-closed 三类:可重试/网络/库异常→`verificationUnavailable`(不完成交易、不入库);签名失败/未知产品/确定性无效→`verificationFailed`(完成但不解锁);无凭据→placeholder→unavailable。
- 验签**必须**走官方 library 的 verify(签名+证书链),严禁裸 base64 decode 当可信(可伪造)。
- 验签后仍复核 bundle_id / product_id(仅 pro.yearly/max.yearly allowlist)/ appAccountToken。
- 仓库零真实密钥(`.p8`/key id/issuer 全 env/path)。

审计局限:`app-store-server-library` 未在审计机安装(PEP-668),`test_apple_verifier.py` 9 个验签测试**未亲跑**(以代码+断言+Codex 29 OK 三方佐证);`test_app.py` 20 个(含 S1b 生产 fail-closed 回归)**已亲跑 OK**。

## 3. 用户闭环步骤(代码做不了,部署时照此走)

1. **App Store Connect**:Pro yearly(`com.yuyuan.assetledger.pro.yearly`)+ Max yearly
   (`com.yuyuan.assetledger.max.yearly`)同订阅组,Max 更高级别;取 key id / issuer id / `.p8` /
   bundle id(`com.yuyuan.assetledger`)/ appAppleId。
2. **部署 iap backend**:`pip install -r server/iap_verification_backend/requirements.txt` +
   Apple root certs;按 `FLEET_IAP_APPLE_KEY_ID/ISSUER_ID/PRIVATE_KEY_PATH/BUNDLE_ID`(及 root cert/appAppleId)
   注入 env/path,**绝不进仓库**。凭据不全时服务仍起但 fail-closed(不解锁)。
3. **修 nginx**:让 `https://api.yuyuan.net.cn/fleet-ledger/iap/apple/verify-purchase` 与
   `.../current-entitlement` 真打到该服务(盘点时 404/502)。客户端生产 base 已配
   `production.json: APPLE_IAP_VERIFICATION_BASE_URL`。
4. **sandbox smoke(契约 §230)**:Pro 购买解 Pro、Max 购买解 Max(含 Pro)、后端故障时客户端不完成交易、
   确定性无效时完成但不解锁;确认 purchase 与 current-entitlement 用同一 appAccountToken。

## 4. Phase 4 其余流(未动)

- **sync delete-meta / terminal-failed reset**:需用户产品决策后再让 Codex 监督写(涉同步语义,高度小心)。
- **sync 公网路由 + 生产 define + smoke**:用户 ops;runbook 见 `docs/operations/cloud-sync-launch-runbook.md`。

> 仍不可宣称"实时云同步生产可用 / 变现已开"——直到上述闭环步骤有真证据(线上 smoke / sandbox 票据)。
