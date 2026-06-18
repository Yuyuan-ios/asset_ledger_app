# Track B 同步传输 — 设计 / 协议文档 v1.0

> 状态：B1–B7 代码侧已完成并在 dev；live 路径由传输配置驱动，
> 未设置 `FLEET_LEDGER_SYNC_BASE_URL` 时保持 dormant。仅剩运维：部署 ECS、
> smoke、设置 `FLEET_LEDGER_SYNC_BASE_URL` 后开 live 同步。

## 0. 现状地基（已有 / 缺）
- **已有**：`enqueue`（本地写→`sync_outbox`）已接生产；`SyncManager.pushPending`
  逻辑齐全（ordering / folding / 退避 / push-gate / dryRun）；真实
  `HttpCloudApiClient`（POST `/sync/outbox`）；`ConflictResolver`（version/hash
  检测原语）；`entity_sync_meta` / `sync_state`。
- **缺**：同步后端、pull 执行器、设备身份、生产 caller。

## 1. 目标 / 非目标
**目标（本期）**：同一 owner 账号下**多台设备**对**单一实体类型 `timing_record`**
的双向同步（push+pull），冲突走 **owner 复核队列**，全程 **dry-run→live** 灰度，
最终退休 readiness gate 最后一条阻断。
**非目标（本期不做）**：partner/driver 脱敏（留 S5/S6）、其余 4 类实体
（`external_work / project / write_off / payment` 仍只入队标 `deferred`）、任何自动合并。

## 2. 七项已定决策
| 维度 | 决策 |
|---|---|
| 后端形态 | **新建独立同步服务**（照搬 cloud-backup 的 stdlib+systemd+nginx 部署套件 + 复用手机登录 token 鉴权） |
| 冲突策略 | **owner 复核队列**，不自动合并，本地保持权威 |
| 信任模型 | **owner 多设备平等全镜像**（各设备拉全量账号数据） |
| 灰度 | **单实体 `timing_record` 先端到端**，dry-run→live |
| 首次 bootstrap | **复用 backup 整库快照 + 增量** |
| 冲突 UI | **独立 conflict 表/页**（与 S5/S7 审批解耦） |
| 后端存储 | **纯 SQLite，payload 入库** |
| 游标（实现拍板） | **账号内单调 `server_seq`**；push/pull 统一端点 `/sync/changes` |

## 3. 架构
```
App ⇄ HTTPS(nginx) ⇄ 独立 sync 服务(Python stdlib + systemd) ⇄ SQLite(变更日志 + 设备表)
```
鉴权：`Authorization: Bearer <手机登录 token>`，`account_id` 由 token `sub` 派生，
**不信任客户端传入的 account**；账号间硬隔离。

## 4. 数据模型
**服务端（纯 SQLite）**
- `sync_changes(account_id, server_seq INTEGER, entity_type, entity_id, base_version,
  new_version, payload_json, payload_hash, deleted, origin_device_id, server_ts,
  PRIMARY KEY(account_id, server_seq))` —— `server_seq` 账号内单调递增。
- `sync_devices(account_id, device_id, name, last_seen)`。

**客户端**
- 复用 `entity_sync_meta`（version / payload_hash / sync_status / deletedAt）。
- `sync_state` 新增 `pull_cursor = last_applied_server_seq`。

## 5. 协议
**Push** `POST /sync/changes`：body = 一批 outbox 条目
（`entity_type / entity_id / op / base_version / payload / payload_hash /
transaction_group_id / local_sequence`）。
- 服务端逐条校验 `base_version == 该实体当前 new_version`：相等→接受、
  `server_seq++`、`new_version++`、落 `sync_changes`；落后→记入返回 `conflicts`，
  **不写不覆盖**。
- 返回 `{accepted:[{entity, server_seq, new_version}], conflicts:[{entity, server_version}]}`。
  客户端把自己 push 成功的 `server_seq` 一并推进本地 cursor（避免回拉自己的写）。

**Pull** `GET /sync/changes?since=<cursor>&limit=N`：返回 `server_seq>cursor` 的变更
（分页、含 tombstone），按 `server_seq` 升序。客户端逐条经 `ConflictResolver`：
- 本地无该实体 / 本地 `synced` 且 version 落后 → 直接应用（含删除墓碑）、推进 cursor。
- 本地 `dirty`（有未推 outbox）且远端更新 → **判冲突 → 写 conflict 表**，本地数据
  **不被覆盖**、outbox 保持 pending、cursor 仍推进（冲突单独追踪）。

**幂等**：`payload_hash` + `(entity, new_version)` 去重；`origin_device_id==self` 的
条目应用为 no-op。

## 6. 冲突 = owner 复核（独立）
新增客户端 `sync_conflicts(entity, local_payload, remote_payload, remote_server_seq,
detected_at, status)`；owner 复核页列出冲突，逐条选「用本地（重推）/ 用远端（覆盖本地）/
手动」，裁决后清 conflict 行并推进。与 S5/S7 的 pending-审批**不复用**，语义独立。

## 7. 首次 bootstrap（复用 backup + 增量）
backup envelope 增加 `sync_cursor_watermark` 字段（备份设备**自己 stamp** 当时的
`pull_cursor`，**不需要两后端互调**，保持解耦）。新设备：
1. 拉最新整库快照恢复 → 2. 采用 envelope 的 watermark 作初始 cursor →
3. `since=watermark` 增量 pull 追平。无 backup 时退化为 `since=0` 全量重放（幂等）。

## 8. 设备身份
首次同步前 App 用 `account token + 本地 device_id`（`app_identity`）注册到
`sync_devices`；同账号多设备平等、各自维护 cursor。表为将来 S6 scoping 预留字段
（本期不用）。

## 9. 实施切片计划（日后交 Codex，同 Track A 纪律：每片跑全门禁、绿了自动推进）
- **B1** 同步后端骨架（独立服务 + 鉴权复用 + `/sync/changes` push/pull + SQLite 变更
  日志 + 设备注册 + smoke_test；照搬 backup 部署套件）。
- **B2** 客户端 pull 执行器（`SyncManager.pullPending`：pull→ConflictResolver→应用/入
  冲突表→推进 cursor；扩展现有 fake-cloud e2e loop 含 pull）。
- **B3** conflict 持久表 + owner 复核页。
- **B4** 设备注册/身份接线。
- **B5** bootstrap（backup watermark + 恢复后增量）。
- **B6** 生产 caller / 后台同步调度；单实体 `timing_record` 门控；dry-run→live；
  配 `FLEET_LEDGER_SYNC_BASE_URL`。
- **B7** 代码侧前置已完成并在 dev；仅剩运维：部署后端到 ECS、smoke、设置
  `FLEET_LEDGER_SYNC_BASE_URL`，由传输配置退休 `real-cloud-transport-not-configured`。

## 10. 安全 / 测试
账号隔离（account 来自 token）；大陆 ECS/SQLite 数据本地化；日志不含 token/payload。
端到端 fake-cloud loop（扩 pull+conflict）+ 后端单测 + 冲突矩阵测试。

## 11. 审计后已定策略（不改后端行为）
- 变更日志 tombstone：**永久保留、不做压缩**。单实体低量下存储成本可忽略；
  日后量级显著增长时再单独复审。
- push 批次事务组（transaction_group）：**保持逐条接受/冲突语义**。整组原子性
  随「多实体同步」延后，本期单实体同步非目标。

以上两项为审计后拍板的保守口径，仅落文档，不改变现有后端行为。

## 12. Backlog
- 云备份服务端硬化延后：
  (1) 备份包络 header 纳入完整性签名；
  (2) 备份/同步 API 服务端 Pro entitlement 校验（需先定校验来源：商店 receipt
  验证或 token entitlement claim）。属云备份线，非 sync 上线必需。
