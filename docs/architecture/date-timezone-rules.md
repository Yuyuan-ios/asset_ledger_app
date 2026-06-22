# 日期与时区处理规范

> 起因：2026-06-22 复核发现 `TimingMonthlyIncomeService` 把"日历日"物化成本地
> `DateTime`，跨夏令时（DST）做 `.difference().inDays` 少算一天，导致月度收入分摊
> 算错（详见 `docs/operations/tech-debt.md` 的 DST 条目 + memory `dst-monthly-income-allocation-bug`）。
> 本规范固化正确模型，并把日数差**升级为 `YmdDate` 整数序日算法**。

## 1. 根本区分：日历日 ≠ 时间点

| 类型 | 例子 | 时区 | 存储 | 算术 |
| --- | --- | --- | --- | --- |
| **日历日（civil date）** | 作业日 `startDate`、油耗/保养日期、账单月份 | **无时区** | `yyyymmdd` 整数 / `YmdDate` | 在日历上算（整数序日），**绝不**物化成本地 `DateTime` |
| **时间点（instant）** | 记录创建时刻、同步时刻、提交/审批时刻 | **有时区** | UTC 时间戳（epoch ms） | 按 UTC 算，**显示时**转观看者本地 |

核心：日历日天生与时区无关（3 月在任何时区都是 31 天）。把日历日当成本地墙钟瞬间，
就会让 DST 这种墙钟现象污染日历事实——这正是上次 bug 的根因。

## 2. 铁律

1. **日历日的日数差用 `YmdDate` 整数序日（epoch-day），不经任何 `DateTime`。**
   `daysBetween(a, b) = b.toEpochDay() - a.toEpochDay()`。整数运算，免疫时区/DST，
   也免疫"某些时区午夜不存在导致 `DateTime(y,m,d)` 落到 01:00 甚至抛错"的坑。
2. **如必须用 `DateTime` 承载日历日**（过渡期或与既有 DateTime 接口交互），一律用
   `DateTime.utc(y, m, d)`，且同一计算上下文内**所有**日期都在 UTC date-only 空间，
   严禁 UTC 与本地混比（否则 `isAfter`/`isBefore` 在边界翻转）。
   `YmdDate.toDateTime()` 当前返回本地 `DateTime`，是已知 footgun，**不要**直接用于日算术。
3. **时间点存 UTC，渲染转本地。** 不要把 instant 和 date 混进同一套日期工具。
4. **时区只在两个边界出现，其它地方都不该碰：**
   - **"今天/当前月"的解析**（`asOfDate ?? DateTime.now()` → ymd）：从本地 `DateTime`
     取 `.year/.month/.day` 回答"此地今天几号"是合法的；违法的是拿这个本地 `DateTime`
     去当**日数操作数**。
   - **时间点的显示**：UTC instant 渲染为观看者本地时区 + locale 格式。
5. **i18n 显示格式 ≠ 时区。** 日期格式（`2026/03/01` vs `2026年3月1日`）、月名、周起始、
   数字本地化由 `intl`/locale 处理，与时区正交，别混为一谈。

## 3. 多端共享 / 国际化的业务时区

当数据跨时区共享（合伙人同步、司机异地填报），"今天/本月归属"必须有**唯一口径**，
否则不同时区的查看者会对"深夜记录算几号、算哪个月"产生分歧：

- **work date 走 ymd**（无时区），随 `yyyymmdd` 原样传输，**永不被任何人的时区重新解释**。
- **submitted_at / approved_at / created_at 走 UTC instant**。
- 当前 solo/老板中心场景：用**设备本地时区**解析"今天"即可，但需把此假设显式写入文档。
- 真要跨时区协作时：在账户/账本设置里钉一个**业务时区**，所有"今天/月度归属"按它算。

## 4. 标准原语（`YmdDate`）

升级目标：给 `YmdDate` 加纯整数序日 API（proleptic Gregorian，Howard Hinnant
`days_from_civil` 算法），日数差全部走它。

```dart
/// 1970-01-01 = 0 的序日（proleptic Gregorian，无时区/无 DST）。
int toEpochDay() {
  final y = month <= 2 ? year - 1 : year;
  final era = (y >= 0 ? y : y - 399) ~/ 400;
  final yoe = y - era * 400;                                   // [0, 399]
  final doy = (153 * (month > 2 ? month - 3 : month + 9) + 2) ~/ 5 + day - 1; // [0, 365]
  final doe = yoe * 365 + yoe ~/ 4 - yoe ~/ 100 + doy;         // [0, 146096]
  return era * 146097 + doe - 719468;
}

/// 含两端则 +1，按业务语义在调用处决定。
int daysBetween(YmdDate other) => other.toEpochDay() - toEpochDay();
```

- 日数差、区间天数、cutoff 比较优先用 `toEpochDay()` 整数比较。
- 月/年归属用 `year`/`month` 直接取，不经 `DateTime`。
- 验证类（`_fromParts` 判合法日期）可保留，但建议改 `DateTime.utc` 规避午夜陷阱。

## 5. 现状与演进

- **已修（`dc0dbf4`，过渡形态）**：`timing_monthly_income_service` /
  `timing_monthly_expense_service` 的所有 date-only 值统一为 `DateTime.utc`（铁律 2），
  双时区（UTC + America/Los_Angeles）全量测试绿。**功能正确**。
- **待升级（FIX-DST-B，见 `docs/quality/codex-prompts-p0.md`）**：把这两个服务的
  `.difference().inDays` 日数差迁移到 `YmdDate.toEpochDay()` 整数序日（铁律 1），
  彻底脱离 `DateTime` 做日历算术。行为不变，由既有 + 双时区测试护航。
- **后续排查**：审计其它 `FormatUtils.dateFromYmd(...).difference()` / 本地 `DateTime(y,m,d)`
  做日算术的位置（`dateFromYmd` 共 9 处调用方），按本规范逐一收敛。
