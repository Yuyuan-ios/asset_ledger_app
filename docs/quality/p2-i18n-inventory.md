# Phase 2 i18n hardcoded CJK inventory

Scope: `external_work`, `timing`, `device` user-visible UI strings in
`lib/features/**` and related `lib/patterns/**`.

Rules applied:

- Include text shown in pages, sheets, dialogs, snackbars, toasts, labels,
  hints, section titles, empty states, badges, and operation confirmation
  messages.
- Exclude comments, docs, debug text, SQL, keys, regexes, enum/data identifiers,
  internal reasons, already `AppLocalizations` keyed strings, and catalog data
  that is intentionally product content.
- Chinese display text must remain byte-for-byte unchanged when keyized later.

## External Work

| File | User-visible hardcoded strings to keyize | Notes |
| --- | --- | --- |
| `lib/features/external_work/import_preview/use_cases/pick_external_work_share_file_use_case.dart` | `请选择 FleetLedger .jzt 分享包`; `读取分享包失败，请重新选择文件`; `分享包文件过大，无法导入` | File picker/import errors shown by the preview flow. |
| `lib/features/external_work/import_preview/use_cases/prepare_external_work_import_preview_use_case.dart` | `请先选择或粘贴 .jzt 内容`; `分享包不是有效的 JSON 内容`; `这不是有效的 FleetLedger 分享包`; `分享包版本暂不支持`; `暂不支持这种分享包`; `分享包完整性信息不完整`; `分享包内容校验失败，请重新获取分享包`; `分享包记录内容不完整或格式异常`; `分享包基础信息不完整或格式异常`; `分享包无法解析` | Preview error mapping. |
| `lib/features/external_work/import_preview/use_cases/confirm_external_work_import_use_case.dart` | `这份分享包已导入过，或包含相同来源记录` | Import confirmation error. |
| `lib/features/external_work/import_preview/view/external_work_import_preview_page.dart` | `外协项目记录`; `取消`; `导入中`; `导入`; `预览`; `来自`; `记录`; `地点`; `总工时`; `总金额`; `记录明细`; `已导入过`; `存在相同来源记录 ... 条`; `存在可疑重复记录 ... 条`; `...，可在外协项目记录中查看`; `小时` | Page title, buttons, summary rows, duplicate labels, success suffix, hour unit. |
| `lib/features/external_work/import_preview/view_model/external_work_import_preview_view_model.dart` | `导入预览生成失败，请稍后重试`; `已导入 ... 条外协项目记录`; `导入失败，请稍后重试`; `可导入`; `已导入过`; `存在相同来源记录`; `存在可疑重复记录` | View model messages/status text. |
| `lib/features/timing/view_models/external_work_records_view_model.dart` | `从分享包导入`; `•...条记录`; `设备未填写`; `等...台`; `未知`; `已关联`; `待处理`; `已忽略`; `已归档`; `已作废` | Timing page external-work list VM, belongs to external_work UI surface. |
| `lib/patterns/timing/external_work_records_pattern.dart` | `暂无外协项目记录`; `从他人分享的 .jzt 文件导入后，会显示在这里`; `来源`; `分享人`; `地址`; `设备`; `日期`; `工时 / 数量`; `单价`; `金额`; `已收项目款`; `导入时间`; `当前状态`; `这条记录来自他人分享，当前不可编辑。`; `解除关联`; `关联到本地项目`; `...年`; `协` | External work empty state, detail rows, action button, grouped year header, avatar glyph. |
| `lib/features/timing/view/timing_page.dart` | `外协项目详情`; `删除分享包`; `确定`; `这将删除该分享包导入的全部 ... 条外协记录，删除后不可恢复。`; `删除`; store action labels `删除` / `读取` when used in user feedback | External-work detail/delete dialogs and related feedback. |

Already keyed/excluded in this area:

- `lib/patterns/timing/external_work_link_sheet.dart` uses `AppLocalizations`
  for link-sheet titles, labels, actions, and settled hints.
- Comments and examples such as `合并\d+项目` regex or quoted docs examples are
  not UI copy.

## Timing

| File | User-visible hardcoded strings to keyize | Notes |
| --- | --- | --- |
| `lib/patterns/timing/section_header_pattern.dart` | `计时`; `+ 新建` | Section header default title/action. |
| `lib/patterns/timing/records_title_pattern.dart` | `最近记录(...)` | Recent-record title fallback. |
| `lib/patterns/timing/exclude_fuel_switch_card_pattern.dart` | `包油/包电`; `开启后：本条工时不参与油耗效率统计。` | Timing entry switch card defaults. |
| `lib/features/timing/domain/services/timing_entry_template.dart` | `包油`; `包电`; `开启后：本条工时不参与油耗效率统计。`; `开启后：本条记录不参与电耗效率统计。`; mode/quantity/unit labels such as `工时`, `租金(台班)`, `台班`, `吨`, `趟次`, `方量`, `亩`, `英亩`, `公顷`, `元/小时`, `元/台班`, `元/吨`, `元/趟`, `元/方`, `元/亩`, `元/英亩`, `元/公顷`; equipment labels `挖掘机`, `装载机`, `压路机`, `吊车`, `运输车`, `泵车`, `植保无人机` | Domain template feeding UI labels. Keep exact wording. |
| `lib/patterns/timing/timing_detail_content_pattern.dart` | Toast/validation text: `结束码表不能小于开始码表，已自动回滚`; `设备`; `该设备`; `请选择设备`; `联系人和工地不能为空`; `结束码表不能小于开始码表`; `工时不能为负数`; `租金模式请填写金额（元）` | Form labels already use l10n; remaining messages are toasts/validation. |
| `lib/features/timing/application/controllers/timing_action_controller.dart` | Month labels `1月` through `12月`; validation strings `结束码表(...) < 下界(...)`; `结束码表(...) > 上界(...)` | Month labels are visible chart labels. Bound messages need confirmation if only debug. |
| `lib/features/timing/calculator/service/work_hour_calculator_service.dart` | `每个数字最多 1 位小数`; `只能输入数字`; `请先输入工时`; `不能连续输入加号`; `请输入工时计算式`; `表达式包含非法字符`; `表达式不能以加号结尾`; `表达式格式不正确`; `工时不能为负数` | Calculator service errors surfaced by calculator UI. |
| `lib/features/timing/operations/save_timing_record_operation_analyzer.dart` | Preview labels/warnings/errors such as `计时记录 ...`; `当前没有可复用的未结清项目，执行时将创建新项目。`; `当前记录指向的项目 ... 不存在，请刷新后再试。`; `保存后将自动解除受影响的合并项目。`; `保存后将自动撤销不再成立的结清状态。`; `预览基于当前本地数据，执行前必须重新分析确认。`; labels `旧项目身份`, `目标项目`, `是否会创建新项目`, `受影响项目集合`, `受影响合并组集合`, `是否解除合并组`, `是否撤销结清`, `风险等级`, `警告集合`; `这条计时记录已不存在，请刷新后再试`; fallback labels `设备 ...`, `未命名项目`, `合并项目 ...` | Operation preview/confirmation copy. |
| `lib/features/timing/operations/save_timing_record_operation_confirm_adapter.dart` | `数据已变化，请重新预览。`; `操作凭据无效，请重新预览。` | Token/confirm user messages. |
| `lib/features/timing/operations/save_timing_record_operation_command.dart` | `修改计时记录`; `保存计时记录`; repeated failure messages; `操作已执行，但审计写入失败，请检查日志。`; `保存计时记录失败，且审计写入失败，请检查日志。`; `操作已取消，但审计写入失败，请检查日志。`; `操作已取消`; confirmation titles/descriptions including `项目归属将变化`, `将自动解除相关合并项目`, `保存后，受影响的合并项目会自动解除，以避免账务口径错误。`, `将自动撤销结清状态`, `保存后，受影响项目如果不再满足结清条件，会自动恢复为进行中。`; summary lines `编辑计时`, `新增计时`, `设备：...`, `项目：...`, `原项目`, `新项目`, `项目归属：... -> ...` | Operation command result/confirmation UI. |
| `lib/features/timing/operations/save_timing_record_preview_redactor.dart` | `预览内容已隐藏`; `资源范围未授权，预览内容已隐藏`; `无委托范围，全部隐藏`; `编辑计时`; `新增计时`; `未命名设备`; `预览基于当前本地数据，执行前必须重新分析确认。`; `可能影响项目结构，需老板确认。`; `可能影响项目结构`; `该操作可能影响项目合并关系，需老板确认。`; `项目 / 联系人 / 工地信息已隐藏`; `财务相关信息已隐藏`; `内部标识已剥离` | Redacted operation preview copy. |
| `lib/features/timing/use_cases/save_timing_record_use_case.dart` | `token-aware save 未就绪：缺少 previewService / confirmAdapter / analyzer / actorContext`; `无法获取确认 token`; `保存失败，请重试`; labels `设备 ...`, `计时记录 ...`, `未命名项目` | User messages/fallback labels, except technical wording may need product review before exposing. |
| `lib/features/timing/use_cases/delete_timing_record_with_impact_use_case.dart` | `该项目已有收款记录。请先处理收款记录后再删除该项目的最后一条计时。` | Delete-blocking message. |
| `lib/features/timing/use_cases/save_timing_record_allocation_cutoff_validator.dart` | `分摊截止日期必须晚于计时日期`; `结束日不能晚于下一条同设备记录日期` | Validator messages, one is remapped in UI. |
| `lib/features/timing/view/timing_page.dart` | Store action labels `保存`, `删除`, `读取`; remapped validator text `结束日不能早于开始日`; external-work dialog strings listed above | Timing page feedback/dialog copy. |
| `lib/features/timing/state/timing_external_work_store.dart` | `外协分享记录` | Store display fallback. |

Already keyed/excluded in this area:

- `tab_bar_pattern.dart`, `card_main_chart_pattern.dart`, calculator views,
  timing home filter/import/link actions, recent-record aggregate labels, and
  most timing detail form labels already use `AppLocalizations`.
- `timing_operation_read_query_service.dart` and
  `save_timing_record_preview_disambiguation_service.dart` reason strings look
  operation-internal; do not keyize unless the UI confirms they are displayed.
- Comments and architecture notes are excluded.

## Device

| File | User-visible hardcoded strings to keyize | Notes |
| --- | --- | --- |
| `lib/patterns/device/device_picker_items_builder.dart` | `...（码表 ... h）`; `未知设备`; `...（已停用 · 码表 ... h）`; `未知设备（已停用）` | Picker item labels. |
| `lib/features/device/domain/services/device_avatar_policy.dart` | `当前方案不支持自定义头像` | Exception may surface as user error. Confirm before keyizing if strictly internal. |
| `lib/features/device/domain/services/lifecycle_payback_calculator.dart` | `未设置成本`; `设置后可查看回本进度与预计盈余`; `已回本 ...x`; `已回本 100%`; `已回本 ...%`; `回本 ...%`; `预计盈余 ...`; `已回本，暂无盈余`; `还差 ... 回本` | Lifecycle status/result text. |
| `lib/features/device/application/controllers/cloud_backup_controller.dart` | `云端备份与恢复是 Max 功能。请升级 Max 后再使用。`; `云端备份服务暂未配置` | Cloud backup availability messages. |
| `lib/features/device/application/controllers/local_backup_controller.dart` | `备份文件格式不完整，暂不能恢复。`; `当前版本暂不支持恢复旧版备份，请使用相同版本导出的备份。`; `备份文件版本较新，请升级 App 后再试。` | Local backup validation messages. |
| `lib/features/device/application/controllers/device_action_controller.dart` | `已打开评分入口`; `评分入口暂不可用`; `已打开技术支持网页`; `暂时无法打开支持页，已切换到邮件联系`; `暂时无法打开支持页，请稍后重试或发送邮件到 ...` | Action feedback/toasts. |
| `lib/features/device/view/lifecycle_payback_card.dart` | `点击设置成本与残值`; `生命周期净收益 = 已实收 + 预计残值 - 初始成本`; `初始投入...`; `已实收净额...`; `预计售出残值...`; `待收...`; `已运营：...小时 / ...项`; `未设置初始投入`; `盈余`; `未回本缺口`; row labels `已实收净额`, `预计售出残值`; `待收 ...` | Lifecycle payback card UI. |
| `lib/features/device/view/lifecycle_amount_sheet.dart` | `设置设备生命周期金额`; `取消`; `更新`; `初始投入成本`; `预计售出残值`; `预计盈余`; `还差回本`; `已实收净额`; `+ 预计售出残值`; `- 初始投入成本`; `= 生命周期净收益` | Lifecycle amount sheet. |
| `lib/features/device/view/device_page.dart` | `保存失败：数据未保存，请稍后重试`; store action labels `保存`, `读取` where used in user feedback | Most page dialogs/backup text already keyed. |
| `lib/features/device/view/device_page_actions.dart` | Store action labels `保存`, `停用`; success messages `已新增设备`, `已更新设备`, `已停用（历史记录不受影响）` | Device save/deactivate feedback. |

Already keyed/excluded in this area:

- Device editor, picker shell, management grid/section, account status, backup
  dialogs, avatar select page, legal pages, upgrade page/patterns, brand picker
  UI, and business ledger section mostly use `AppLocalizations`.
- `lib/features/device/model/brand_catalog.dart` brand/country names are catalog
  product data, not generic UI chrome. Do not keyize in this pass unless product
  explicitly requests localized brand/catalog data.
- `DeviceStore.insert: brand 不能为空`, `设备不存在`, comments, and internal
  exceptions are not UI copy unless a caller surfaces them directly.

## Follow-up Order

1. P2-S3 external_work: import preview page/view model/use cases plus
   external-work record list/detail surfaces.
2. P2-S4 timing: timing entry/detail/calculator/operation user messages,
   keeping already-keyed form labels unchanged.
3. P2-S5 device: lifecycle/payback, picker item labels, backup/action fallback
   messages, leaving catalog data and already-keyed pages alone.

## 待确认

- Whether operation preview/read-query reason strings are user-visible enough to
  keyize in Phase 2, or should remain internal operation metadata.
- Whether brand/catalog names should ever be localized; current inventory treats
  them as product data and excludes them.
