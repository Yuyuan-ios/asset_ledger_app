# Phase 1 架构违规清单（Debt-0 后，P1-S0）

> 盘点基线：`dev@a6f271b` 后的 `feature/p1-arch-boundary`。
> 本文件只登记现状，不修复 `lib/` / `test/`。

## features -> DB 直连

| 文件 | 违规形态 | 后续切片 |
| --- | --- | --- |
| `lib/features/sync/sync_conflict_review_controller.dart` | import `../../data/db/database.dart`；`LocalTimingConflictSummaryReader.localSummary` 直接 `await AppDatabase.database` 并裸查 `timing_records`。 | P1-S1 锁行为；P1-S2 先让 controller 依赖 `TimingConflictSummaryReader` 接口；P1-S3 把 DB reader 移出 feature 层。 |
| `lib/features/timing/operations/save_timing_record_operation_analyzer.dart` | import `package:sqflite/sqflite.dart` 与 `../../../data/db/database.dart`；默认 `_executorFactory = (() async => AppDatabase.database)`，feature operation 直接绑定 DB executor。 | P1-S4 先补 characterization，再把读模型收敛到接口和 data adapter。 |

## patterns -> data/models

分类说明：

- A 展示字段：pattern 主要读取 model 字段、渲染 UI 或透传回调参数。
- B 业务判断：pattern 内含选择、分组、校验、默认值、结清/核销/工时聚合等判断。
- C 序列化：pattern 内直接做 JSON / map 持久化序列化。当前 15 个文件未发现纯 C 类；`device_picker_items_builder.dart` 引入 `device_maps.dart` 属于 data-model 映射 helper，但同时含 active/selected 业务分支，先归 B。

| 分类 | 文件 | data/models import | 现状说明 |
| --- | --- | --- | --- |
| B | `lib/patterns/account/account_project_detail_sheet_vm.dart` | `device.dart`, `project_device_rate.dart`, `project_key.dart`, `project_write_off.dart`, `timing_record.dart` | 在 patterns 内折算项目详情 VM，包含合并项目、结清、核销、外协、工时和单价聚合判断。 |
| B | `lib/patterns/account/account_project_detail_sheet_pattern.dart` | `account_payment.dart`, `device.dart`, `project_device_rate.dart`, `project_write_off.dart`, `timing_record.dart` | 在 pattern 中装配 account detail VM，并根据合并/普通项目、撤销核销目标接线不同回调。 |
| A | `lib/patterns/account/project_account_detail_content_pattern.dart` | `account_payment.dart`, `device.dart`, `project_write_off.dart` | 内容组件消费项目明细展示字段、付款/核销列表和回调参数。 |
| A | `lib/patterns/device/device_editor_brand_row_pattern.dart` | `device.dart` | 读取 `EquipmentType` 生成品牌/设备类型展示文案。 |
| B | `lib/patterns/device/device_editor_fields_group_pattern.dart` | `device.dart` | 根据 `EquipmentType.excavator` 决定是否展示破碎单价字段。 |
| A | `lib/patterns/device/device_management_grid_pattern.dart` | `device.dart` | 渲染设备头像、品牌、序号和类型标签，并透传点击回调。 |
| A | `lib/patterns/device/device_management_section_pattern.dart` | `device.dart` | 组合设备管理 section 与 grid，透传 `List<Device>` 和点击回调。 |
| B | `lib/patterns/device/device_picker_items_builder.dart` | `device_maps.dart`, `device.dart` | 把 active/all devices 组装成 picker VM，处理停用已选设备、未知设备 fallback 和码表展示。 |
| B | `lib/patterns/fuel/fuel_detail_content_pattern.dart` | `device.dart`, `fuel_log.dart` | 表单初始化、默认设备/供应人推断、字段校验，并组装 `FuelLog` 提交。 |
| A | `lib/patterns/fuel/fuel_recent_records_pattern.dart` | `fuel_log.dart` | 以 `FuelLog` 生成本地 UI key、按日期展示近期记录、透传删除回调。 |
| A | `lib/patterns/fuel/fuel_sliver_home_pattern.dart` | `fuel_log.dart` | 首页列表消费 `FuelLog`，维护本地 optimistic remove UI 状态。 |
| B | `lib/patterns/maintenance/maintenance_detail_content_pattern.dart` | `device.dart`, `maintenance_record.dart` | 表单初始化、公共支出/设备校验、停用设备限制，并组装 `MaintenanceRecord` 提交。 |
| B | `lib/patterns/timing/recent_records_pattern.dart` | `device.dart`, `timing_record.dart` | 近期计时记录 key、连续分段聚合、日期范围、工时/台班显示规则仍在 pattern。 |
| B | `lib/patterns/timing/timing_detail_content_pattern.dart` | `device.dart`, `project_device_rate.dart`, `timing_record.dart`, `timing_calculation_history.dart` | 计时表单模式、设备默认值、破碎能力、日期/码表/收入校验与 `TimingRecord` / calculation history 组装仍在 pattern。 |
| B | `lib/patterns/timing/timing_home_pattern.dart` | `device.dart`, `timing_record.dart` | 首页近期记录按设备筛选、停用设备 label、聚合展开状态与外协聚合状态仍在 pattern。 |

## 后续边界

- P1-S1 至 P1-S5 只处理 features -> DB 直连和对应 guard。
- `patterns -> data/models` 只登记，不在本批次自动修复；P1-S6 / P1-S7 需人工审计放行后再执行。
