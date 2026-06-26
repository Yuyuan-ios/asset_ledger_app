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
   bundle id(`com.yuyuan.asset-ledger`)/ appAppleId。
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

## 5. IAP 上线收尾清单（①②③ + 验收标准）

> 部署进度(2026-06-23,用户 ops)：iap backend 已部署(systemd `fleet-ledger-iap.service` active,
> `127.0.0.1:8010`)、nginx 路由 `/fleet-ledger/iap/*` 通、公网 healthz 200;Apple key `Z23R53S8M9`
> 已配(`/etc/fleet-ledger/iap.env` 600,`.p8` root:fleetiap 640,未进 git)。
> **invalid 假票据 smoke 已过(verificationFailed/none,fail-closed 不误解锁)。**
> **未验**:valid 合法购买是否正确解锁(=③ sandbox)、outage fail-closed(=①)。

### ① outage fail-closed 验收（5 分钟,与 invalid 一起补全 fail-closed 矩阵）
- 操作：临时停 `fleet-ledger-iap.service` → curl 公网 verify/current-entitlement → 期望 **502/非 2xx** → 重启 → healthz 200。
- 验收：非 2xx；客户端按契约"非 2xx 不完成 StoreKit 交易"(客户端侧已由代码/测试覆盖)。

### ② App Store Connect 收尾（解锁 sandbox 购买的前置）
> **⚠️ 不要删除重建 Pro/Max 订阅**：Apple 不允许复用已删除的产品 ID,删除会永久作废
> `com.yuyuan.assetledger.pro.yearly` / `...max.yearly`,逼你换新 ID 并改客户端/后端/契约/`production.json`。
> 下列问题**全部原地修复即可**。
- **level 反了** → 在订阅组内**重排**:`Max = Level 1`(更高)、`Pro = Level 2`(契约 §232:Max 更高级别)。pre-launch 重排无副作用;后端按 productId 映射 tier、不读 level,**不改代码**。
- **Missing Metadata / Developer Action Needed** → 每商品补齐:Display Name + Description、时长 1 年、价格层级、≥1 本地化(zh-Hans)、Review 截图 + 备注。
- **订阅组 localization Rejected** → 按 Apple 拒绝原因改组显示名/本地化文案,**重新提交过审**。
- 验收：两商品转 "Ready to Submit" / "Waiting for Review";level 为 Max=1/Pro=2。

### ③ sandbox 真机购买 smoke（真正的闭环验证,仅用户能做）
- 用 `dart_defines/production.json` 出包(已指向 base URL);sandbox 账号买 Pro/Max。
- 验收：Pro 购买解 Pro;Max 购买解 Max **且含 Pro 能力**;purchase 与 current-entitlement 用**同一 appAccountToken**;后端日志无密钥泄漏。
- ③ 过 = "会正确解锁合法购买"得到验证,IAP 线真闭环。

> App Store Server Notifications 暂不配:S2 的 current-entitlement 每次走 `get_all_subscription_statuses`
> 重新问 Apple,续费/过期/退款会在下次查 entitlement 时捕获;notifications 是日后主动推送的硬化项,非 go-live 必需。

## 6. FINAL_CODEX_PROMPT — IAP 上线收尾（原地修复 · computer-use 协同）

```
# 任务：FleetLedger IAP 上线收尾（① outage 验收 → ② App Store Connect 原地修复 → ③ sandbox 前置）
# 路径已定：ASC 原地修复，绝不删除任何产品/订阅/产品 ID。与 computer use 紧密配合，需用户确认处必停。

## 角色与协同
- 你（Codex）用 computer use 操作两处：(a) 远程服务器（用户已登录的 SSH/终端会话）；
  (b) App Store Connect 浏览器（用户已登录，App「机账通」，App Apple ID 6760682393）。
- 用户在旁：确认每个破坏性/外部可见动作；③ 的真机 Apple 支付由用户亲自点，你不代点。
- 本任务不改仓库代码、不 git 提交。

## 环境事实（非密钥，供你定位，勿外泄）
- 仓库：/Users/yu/Flutter_Projects/fleet_ledger_app，dev@8dcadb5（只读）。
- 后端：systemd fleet-ledger-iap.service（active），127.0.0.1:8010，部署 /opt/fleet-ledger-iap，
  数据 /var/lib/fleet-ledger-iap，env /etc/fleet-ledger/iap.env(600)，运行用户 fleetiap。
- nginx：/fleet-ledger/iap/healthz 与 /fleet-ledger/iap/apple/ → 8010；公网 base https://api.yuyuan.net.cn/fleet-ledger。
- Apple：key id Z23R53S8M9（.p8 在 /etc/fleet-ledger，root:fleetiap 640，禁读禁输出），issuer 已配。
- 产品：Pro=com.yuyuan.assetledger.pro.yearly，Max=com.yuyuan.assetledger.max.yearly；订阅组「机账通 Pro」。
- 已验：invalid 假票据 → verificationFailed/none（fail-closed 不误解锁）。未验：outage（①）、valid 解锁（③）。

## 硬限制（全程）
1. 任何破坏性/外部可见动作——停服务、改 nginx、改/提交 ASC、出包——先一句话说清影响 → 停下等用户明确
   「确认/继续」→ 才执行。
2. 绝不删除/下架 ASC 产品、订阅或产品 ID；绝不点 ASC 的 Delete / Remove from Sale。若用户中途要求删除，
   必须先让其书面确认「知晓产品 ID 永久作废且需改客户端/后端/契约/production.json」，否则停。
3. 不读取/打印/复制/提交任何密钥、.p8、issuer、token、env 内容；远程仅在用户已登录会话内操作。
4. 不改仓库代码、不 git 提交、不替用户点 Apple 支付；不自动 Submit for Review（每次过审单独确认）。
5. 每步留证（命令输出 / ASC 截图），但截图与日志不得含密钥。任一步未达验收即停下报告，不强行推进。

## ① outage fail-closed（终端，先确认再停服务，约 30s）
- 先告知将临时停服务做 outage 测试 → 停下等确认。确认后执行：
  sudo systemctl stop fleet-ledger-iap.service
  curl -s -o /dev/null -w 'verify=%{http_code}\n' -X POST \
    https://api.yuyuan.net.cn/fleet-ledger/iap/apple/verify-purchase \
    -H 'Content-Type: application/json' -d '{}'
  curl -s -o /dev/null -w 'current=%{http_code}\n' \
    'https://api.yuyuan.net.cn/fleet-ledger/iap/apple/current-entitlement?appAccountToken=00000000-0000-4000-8000-000000000001'
  sudo systemctl start fleet-ledger-iap.service
  curl -s -w ' health=%{http_code}\n' https://api.yuyuan.net.cn/fleet-ledger/iap/healthz
- 验收：停服务期间两个 IAP 接口返回非 2xx（502/504）；重启后 healthz=200。
  含义：非 2xx → 客户端按契约不完成 StoreKit 交易、可重投。报告各 http_code。

## ② App Store Connect 原地修复（浏览器 computer-use，先只读诊断 → 逐项确认 → 修）
A. 只读诊断（不改任何东西）：进 ASC →「机账通」→ 订阅 → 订阅组「机账通 Pro」。逐一截图并记录：
   - 订阅组内 level 排序（谁在上 = Level 1）。
   - Pro、Max 各自状态（Developer Action Needed / Missing Metadata）与具体缺项
     （Localization / Subscription Prices / Review 截图 / Duration 等）。
   - 打开 Resolution Center，读 localization「Rejected」的具体拒绝原文。
   停下，把诊断结果 + 计划改动逐条列给用户确认。
B. 逐项原地修改（每项改前确认，绝不删除）：
   - level 重排：将 Max 排到 Pro 之上（Max=Level 1 / Pro=Level 2）。
   - 补 metadata：按诊断缺什么补什么——Display Name、Description、时长 1 年、价格层级、
     zh-Hans 本地化、Review 截图 + 备注。
   - 改 localization：按 Resolution Center 拒绝原因改订阅组显示名/本地化文案。
   - 每次 Save 后截图；每个 Submit for Review 单独停下确认。
C. 验收：Pro、Max 状态转 Ready to Submit / Waiting for Review；level 显示 Max=1/Pro=2；贴改前/改后截图。

## ③ sandbox 真机购买（你指导，不代点支付）
- ASC 清干净后，指导用户：用 dart_defines/production.json 出包，sandbox 账号分别购买 Pro、Max。
- 购买后（终端只读）核对：
  - Pro 购买 → outcome=verifiedActivePro / tier=pro；Max → verifiedActiveMax / tier=max（含 Pro 能力）。
  - purchase 与 current-entitlement 用同一 appAccountToken。
  - 后端日志无密钥泄漏。
- 验收：Pro 解 Pro、Max 解 Max、token 一致 → IAP 线真闭环。

## 报告（每步 §E 风格）
操作 / 命令或页面 / 结果（http_code、ASC 状态、截图引用）/ 是否需用户确认及是否已确认 / 偏差与遗留。
不 push 仓库、不擅自删除或过审；①②③ 任一未达验收即停下报告。
```
