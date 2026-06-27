# 云端备份 — 生产上线 Runbook（China-first）

> 状态：**代码侧 100% 就绪**（Dart 客户端 + Python 后端 + 部署套件 + CI 接线均已绿）。
> 本文档只覆盖**仅运维能做**的动作：开 ECS/OSS、配密钥、DNS、证书、跑 installer、冒烟。
> 组件级细节不在此重复，按需查：
> - 后端/鉴权/OSS 权限：`server/cloud_backup_backend/README.md`
> - 部署资产用法：`server/cloud_backup_backend/deploy/README.md`
> - 客户端 endpoint 解析口径：`lib/app/cloud_backup_config.dart`

生产域名（已固化进 `dart_defines/production.json`，出包即生效，无需再改代码）：

| 用途 | 值 |
|---|---|
| 云备份服务 | `https://backup-api.yuyuan.net.cn` |
| 账号/IAP 业务后端 | `https://api.yuyuan.net.cn/fleet-ledger` |

---

## 0. 前置硬依赖（不满足则上线必失败）

### 0.1 账号服务必须先在线，且备份服务能验证它签发的 token —— **头号阻断项**
App 把**手机登录的 `authToken`** 作为 `Authorization: Bearer` 发往 `backup-api.yuyuan.net.cn`
（见 `lib/app/providers/device_fleet_providers.dart` 的 `accessTokenProvider`）。备份后端**自己不发 token**，
只验证账号服务（`api.yuyuan.net.cn`）签发的那枚。所以上线前必须确认：

1. 账号服务**已部署并在发 token**（IAP base URL 已配置，说明业务后端在线——需确认它确实签发登录 token）。
2. 备份后端用下面**二选一**方式验证该 token（`env`，详见后端 README「User Auth」节）：
   - **HS256 共享密钥**：`USER_AUTH_HS256_SECRET` 填**与账号服务签 token 完全相同**的 HS256 secret。
     适用：登录 token 是自包含 JWT。token 须含 `sub`/`user_id`/`phone` 之一。
   - **introspection**：`USER_AUTH_INTROSPECTION_URL` 指向账号服务的校验端点。
     适用：登录 token 是不透明串。
   > 决策点：先确认账号服务签的是 JWT 还是 opaque token，再选模式。**两者都没配 = 所有上传返回 401。**

### 0.2 `FLEET_BACKUP_ACCOUNT_KEY_SECRET` —— **最危险的一次性值**
账号绑定客户端加密的主密钥（App 的 AES key 由 `HMAC-SHA256(此值, user_id)` 派生）。
- 必须 **≥32 字符高熵随机**，**与 JWT/SMS/OSS/DB 任何密钥都不复用**。
- 必须**永久稳定**：一旦轮换或丢失，**所有已加密备份永久无法解密**。
- 与 OSS 桶**分开存放**（OSS 泄露 + 无此密钥 ⇒ 仍拿不到明文，这是设计意图）。
- 未配置时 `GET /v1/account/backup-key` 返回 `backup_key_unavailable`，生产 App 会**拒绝上传明文**
  （`requireEncryption=true`，PIPL 合规兜底）——即密钥就绪前云备份对用户不可用。

### 0.3 中国上架特定项
- **ICP 备案**：`backup-api.yuyuan.net.cn` 落在中国大陆 ECS，子域必须在 `yuyuan.net.cn` 的 ICP 备案覆盖内，
  否则运营商**封 80/443**。`api.yuyuan.net.cn` 已对外服务，说明主域大概率已备案——**确认子域已纳入**即可。
- **OSS 区域**：与 ECS **同地域**的私有桶（`env.example` 默认 `oss-cn-hangzhou`），同区免跨区流量费、低延迟。
  桶**必须 private**，严禁 public-read(-write)。
- **数据residency（合规红利）**：密文存大陆 OSS，天然满足中国用户数据本地化；主密钥独立保管，符合 PIPL 最小化口径。

---

## 1. 开通阿里云资源（控制台，你来做）

- [ ] ECS 实例（建议同区，能出公网拉证书/接 OSS 内网）。
- [ ] 私有 OSS 桶（同区）；记 endpoint / bucket。
- [ ] **RAM 用户或 ECS 角色**，最小权限**仅限该桶/前缀**：`oss:PutObject` / `oss:GetObject` / `oss:DeleteObject`。
      AK/SK **永不进 App、不进仓库**——后端服务端签名。
- [ ] DNS：`backup-api.yuyuan.net.cn` A 记录 → ECS 公网 IP。
- [ ] TLS 证书（阿里云免费 DV 即可），放置到 nginx 证书路径。

## 2. 部署后端（ECS 上，root）

```bash
# 1) 上传 server/cloud_backup_backend/ 到 /opt/fleet-ledger-cloud-backup
# 2) 复制 server/common/ 到 /opt/fleet-ledger-cloud-backup/common/ 或 /opt/common/
# 3) 跑 installer（建用户/venv/目录/systemd/0600 env 文件；占位符未替换前不会启动）
cd /opt/fleet-ledger-cloud-backup
sudo bash deploy/install_on_ecs.sh
```

填 `/etc/fleet-ledger-cloud-backup.env`（root:root, 0600），替换全部 `replace-with-*`：

- [ ] `USER_AUTH_HS256_SECRET` **或** introspection 组（见 0.1）
- [ ] `FLEET_BACKUP_ACCOUNT_KEY_SECRET`（见 0.2，**生成后立刻离线备份**）
- [ ] `CLOUD_BACKUP_ENTITLEMENT_URL` + `SERVICE_INTERNAL_TOKEN`
      （服务端 Max 权益校验；生产/预发缺任一项会启动失败）
- [ ] `ALIYUN_OSS_*` / `ALIBABA_CLOUD_ACCESS_KEY_*`（见 1）；`FLEET_BACKUP_STORAGE=oss`
- [ ] 确认**无** `FLEET_BACKUP_DEV_TOKENS_JSON`，且无
      `CLOUD_BACKUP_MAX_ENTITLED_USERS_JSON`
      （生产严禁 dev token 和本地 Max allowlist）
- [ ] 完成 breaking env migration：只保留 `USER_AUTH_*`、
      `SERVICE_INTERNAL_TOKEN` 与 `CLOUD_BACKUP_ENTITLEMENT_URL` 新命名；
      若 env 文件仍含 deprecated block 内任一旧命名，启动会直接
      `ConfigMigrationError`

```bash
systemctl enable --now fleet-ledger-cloud-backup
systemctl status fleet-ledger-cloud-backup --no-pager
```

## 3. nginx + HTTPS

`deploy/nginx.conf.example` → nginx 配置目录，替换 `backup-api.example.com` 为 `backup-api.yuyuan.net.cn` 及证书路径。
关键项已在样例里（勿调小）：`client_max_body_size 70m`、`client_body_timeout 180s`、`/v1/backups` 读写超时 180s
（64MB 信封不能被 nginx 在 app 限流前截断）。反代 `127.0.0.1:8008`，覆盖 `/v1/backups`、`/v1/account/backup-key`、`/healthz`。

```bash
nginx -t && systemctl reload nginx
curl -fsS https://backup-api.yuyuan.net.cn/healthz
# 期望 ok=true, cloud_backup_entitlement_required=true, entitlement_verifier=configured
```

## 4. 冒烟验收（任意能访问该域名的机器）

```bash
# 仅验鉴权拒绝（无需真 token）
python3 deploy/smoke_test.py --base-url https://backup-api.yuyuan.net.cn --auth-only
# 真 token：账号密钥下发稳定性 + 备份往返
python3 deploy/smoke_test.py --base-url https://backup-api.yuyuan.net.cn --token "$TOKEN"
# 跨账号隔离（强烈建议）
python3 deploy/smoke_test.py --base-url https://backup-api.yuyuan.net.cn --token "$TOKEN_A" --other-token "$TOKEN_B"
```
`$TOKEN` = 用真实账号在 App 登录后拿到的 `authToken`（同一枚被发往备份服务的 Bearer）。脚本不打印 token/密钥/payload。

## 5. 出包（已就绪，无需改代码）

```bash
flutter build ipa --release --dart-define-from-file=dart_defines/production.json
```
`production.json` 已含 `FLEET_LEDGER_CLOUD_BACKUP_BASE_URL`。CI 守护 `cloud_backup_config_test.dart` 已断言该值。
> 提醒：`--dart-define-from-file` 仅对 `flutter build ipa` 生效；**勿**在 Xcode 直接 Archive，会漏传 define。

---

## 上线前清单（仅运维项，代码项已全绿）

- [ ] 0.1 账号服务在线 & 备份后端能验证其 token（HS256 共享 / introspection 二选一已配）
- [ ] 0.2 `FLEET_BACKUP_ACCOUNT_KEY_SECRET` 已生成、已离线备份、确认永不轮换
- [ ] 服务端 Max entitlement 已配置：`CLOUD_BACKUP_ENTITLEMENT_URL` + `SERVICE_INTERNAL_TOKEN`
- [ ] 0.3 `backup-api` 子域 ICP 备案已覆盖
- [ ] OSS 私有桶 + 最小权限 RAM、AK/SK 仅在后端 env
- [ ] DNS + TLS 就位，`/healthz` 200
- [ ] env 文件 root:root 0600、无 dev token、日志不含 Authorization/密钥/payload
- [ ] 冒烟三项全过（鉴权拒绝 / 备份往返 / 跨账号隔离）
- [ ] 真机：登录 → 设备页云备份 → 上传 → 重装/换机重登 → 恢复成功（端到端验证账号绑定密钥）

## 失败回退
- 备份后端整体下线/域名解析失败：App 端 `CloudBackupConfig` 仍可用（URL 已配），但请求失败会被 controller 当错误呈现；
  本地备份/导出路径不受影响，用户数据安全无依赖云端。
- 密钥端点未配（503）：生产 App 拒绝上传明文，云备份显示不可用——**符合预期**，非崩溃。
