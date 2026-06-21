# 合伙人只读同步 — 设计 / 协议文档 v1.0

> 状态：**架构定稿,待实施**(实施在独立 worktree)。建立在 Track B 同步传输
> (B1–B7,已在 dev)之上。司机端**不走 sync**(已澄清),故本设计只服务"合伙人共享"。

## 0. 一句话目标
分享者(老板)把自己账号的**工作类数据只读镜像**给合伙人;合伙人据此**本地派生应收**,
**自己重填收款/核销**(保持灵活、且老板的真实收款对其保密)。合伙方的任何改动**绝不回流**到分享者。

## 1. 角色与范围
- **分享者(owner)**:数据唯一权威写入方。其自己的多设备走 owner 账号正常双向同步(本设计不改)。
- **合伙人(partner)**:**必须手机登录(自有账号)**;可有自己的多设备(走他自己账号正常同步)。
  他收到分享者数据的那台/那些设备 = **只读镜像**。
- **非目标**:合伙方→分享者的任何上行;同步分享者的收款/核销;owner 多设备的"全实体双向"
  (那是另一条线,见 §8)。

## 2. 核心决策
| 维度 | 决策 |
|---|---|
| 方向性 | **单向**:分享者→合伙(只读)。合伙改动永不上行。 |
| 授权(A) | **服务端跨账号只读授权**:分享者按合伙手机号授权 → grant(resource=分享者账号, grantee=合伙, scope=read, 可选 expiresAt)。复用 `ActorScope.grantId/expiresAt`。 |
| 硬边界 | **服务端拒绝合伙 token 向分享者账号 push**(客户端只读是 UX,服务端才是边界)。 |
| 钱 | **不同步**分享者的收款/核销;**应收本地派生**(工时×有效单价);油费/维保费随其设备表自带过来。 |
| 单价 sticky | 合伙在项目详情改的单价 = **覆盖层**,叠在 `buildEffectiveRateFenMap` 上,**永远为准、同步不再覆盖**。 |

## 3. 两层数据模型(合伙设备上)
| 层 | 内容 | 同步行为 |
|---|---|---|
| **共享镜像(只读)** | `projects`、`timing_records`、`fuel_logs`、`maintenance_records`、`project_device_rates`(默认单价) | pull **永远直接覆盖**,逻辑极简(增量/快照皆可,见 §6) |
| **本地覆盖层(合伙自有,绝不同步/绝不被覆盖)** | 收款(`account_payments`)、核销(`project_write_offs`)、**单价覆盖** | sync 根本不碰 |

**为什么分两层**:让 sync 保持"无脑覆盖",无需"判断哪行被本地改过才跳过"的脆弱特判;
sticky 来自覆盖层是 sync 从不触碰的独立存储。也使"快照整库刷新镜像"安全(覆盖层不受影响)。

> 必须同步 `projects`:`timing_records.project_id` NOT NULL,合伙要分组/派生必须有项目行。

## 4. 有效单价 chokepoint(命门,已验证)
- `AccountService.buildEffectiveRateFenMap`(`lib/data/services/account_service.dart`)是单价**唯一派生权威**,
  被 account 汇总 / 工时报表 / 结算共用,且**本就分层**(project-device 单价 > 设备默认价)。
- 合伙单价覆盖 = 在此函数**再叠最高一层**:**覆盖 > 同步默认 > 设备默认**。
- 编辑入口 = **项目详情 sheet → 本地设备 → 单价「修改」**(写 `project_device_rates` via project_rate_repository)。
  合伙在此改 → 写覆盖层 → 有效单价。sheet 显示的单价也要显示**有效**值(覆盖优先)。
- **唯一硬约束**:所有派生/显示单价的路径都必须走 `buildEffectiveRateFenMap`,不得新开第二条读价路径。

### P3 pull payload / entity_id 契约
- pull 侧 applier 统一消费 `payload_json` 中的 `record` 对象;除 `project`
  复用现有 `ProjectSyncEnqueuer` 包装形状外,其余新增实体的 `record` 均为目标表整行列。
- `project`: `entity_type=project`,`entity_id=projects.id`,record 为
  `Project.toMap()` 输出。
- `timing_record`: 既有契约保持不变,`entity_id=timing_records.id`。
- `project_device_rate`:当前 schema 主键为
  `(project_id, device_id, is_breaking)`,故 `entity_id` 采用
  `"<project_id>:<device_id>:<is_breaking>"`;解析时从右侧切出后两段,避免
  `project_id` 自身包含冒号时误切。record 为 `project_device_rates` 整行列:
  `project_id/project_key/device_id/is_breaking/rate_fen`。
- `fuel_log`: `entity_type=fuel_log`,`entity_id=fuel_logs.id`,record 为
  `fuel_logs` 整行列: `id/device_id/date/supplier/liters/cost_fen`。
- `maintenance_record`: `entity_type=maintenance_record`,
  `entity_id=maintenance_records.id`,record 为 `maintenance_records` 整行列:
  `id/device_id/ymd/item/amount_fen/note`,其中 `device_id` 可为 `null`。
- tombstone(`deleted=true`)按同一 `entity_id` 删除本地行,并写入
  `entity_sync_meta.deleted_at/payload_hash/version/synced`。

## 5. 钱:为什么不复杂
- **应收**:派生(工时 × 有效单价),合伙本地重算重现。
- **油费/维保费**:`fuel_logs`/`maintenance_records` 自带金额列、按 device_id 单表 → 同步这两张表即带过去,不用派生。
- **收款/核销**:分享者侧是手填事实(`+ 新增收款`),**不同步**;合伙**自己重填**(本地覆盖层)。
  → 合伙看不到分享者真实已收(隐私边界),且**无任何钱表合并、无钱冲突**。
- account_payments/write_offs 是 **project-keyed** 且项目可跨设备 —— 不同步它们,正好回避"按设备切不干净"的问题。

## 6. 镜像传输机制(**已定:增量,扩 Track B**)
镜像层 {projects, timing, fuel, maintenance, 默认单价} 从分享者账号送到合伙设备,**走增量**(覆盖层与此正交):
- **扩 Track B**:复用已部署的 `/sync/changes` + server_seq 游标 + 跨账号只读授权;为这 4 类输入表
  (projects / fuel_logs / maintenance_records / project_device_rates)补 **remote-change applier**
  (目前只有 timing_record 有),并确保分享者侧这些表**写入即入队**(push 侧 enqueuer 齐全)。
  "有新计时即拉"天然映射;这些输入表无结算/钱不变量,applier 比钱表简单。
- 后端实体无关(payload 入库),已支持任意 entity_type;客户端 **pull-apply + push-enqueue** 是工作量所在。
- (放弃)快照:需解跨账号备份解密/密钥 + 合伙端分库存,比增量绕。

## 7. 边界 / 边角
- **孤儿覆盖**:分享者删了某 project/device,镜像里没了 → 对应单价覆盖**忽略**。
- **计算口径一致**:合伙端派生依赖与分享者一致的 `calculation_policy_version`;由版本/强更线保证。
- **合伙自有 vs 共享**:合伙设备同时持有"他自己账号数据"+"分享者只读镜像",两者分开;镜像刷新不动他自有数据。

## 8. 与 owner 多设备同步的关系(非本设计)
- owner 自己多设备 = **双向、要合并** → 若要"全实体"需扩多实体增量(重)。**非主线,本设计不含。**
- 本设计是**合伙只读**:省掉双向合并 + 省掉钱表 → 比 owner 全量双向**省力得多**。

## 9. 实施切片计划(交 worktree;每片全门禁、绿了推进)
- **P1** 服务端跨账号只读授权:grant 表 + 分享者建/撤授权端点(按合伙手机号)+ pull 鉴权放行 + **push 拒绝**;单测含跨账号。
- **P2** 客户端"输入手机号分享"入口 → 调授权端点;合伙端识别"只读镜像会话"。
- **P3** 镜像传输:按 §6 决定(增量则补 projects/fuel/maintenance/rates 的 applier;镜像层只读、pull 覆盖)。
- **P4** 覆盖层:单价覆盖存储 + 接入 `buildEffectiveRateFenMap`(覆盖>默认>设备默认)+ 项目详情「修改」写覆盖 + sheet 显示有效价。
- **P5** 合伙端账户页:本地重填收款/核销(本地覆盖层,绝不上行);应收用有效单价派生。
- **P6** i18n + 端到端联调(分享→镜像→改价 sticky→重填收款→应收正确)。

## 10. 留待实施时敲定
- **P1 身份映射(关键依赖)**:授权按"合伙手机号"建,但 token 派生的是 account_id;**phone↔account 映射在外部账号服务**(签 token 的那个),本仓 `cloud_sync_backend` 只验 token 拿 account_id。需定:grant 按 grantee_account_id 存(分享者侧先把手机号换成 account_id),还是按 grantee_phone 存(需服务端能从 partner token 反解手机号)。P1 落地前必须先敲死。
- **P3a 已敲定**:`project_device_rate` 的后续 enqueuer 必须按当前
  `project_device_rates(project_id, device_id, is_breaking)` 三列主键产出
  `entity_id="<project_id>:<device_id>:<is_breaking>"`,不能降级为
  `project_id/device_id` 二元组,否则普通/破碎两类单价会在
  `entity_sync_meta.local_id` 上碰撞。
- 授权撤销的 UI 与即时性(删 grant → 合伙下次 pull 即断)。
- 合伙端"只读镜像"在 UI 上如何与"他自有数据"区隔呈现。
- 单价覆盖的存储形态:独立覆盖表(推荐) vs `project_device_rates` 加 `partner_overridden` 标志(更轻但 sync 要特判)。
